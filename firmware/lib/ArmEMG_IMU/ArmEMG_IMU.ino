/*
  ArmEMG_IMU.ino

  ESP32-S3 firmware for a 2-IMU + 3-channel EMG arm-motion / muscle
  activation logger.

  Hardware:
    - 2x MPU6500 on one shared I2C bus, addresses 0x68 (AD0->GND, upper arm)
      and 0x69 (AD0->3V3, forearm)
    - 3x analog EMG channels on ADC1 pins (see PIN_EMG1..3 below)

  Calibration commands, sent as a single byte - over USB Serial Monitor
  (115200 baud) OR by writing to the BLE command characteristic:
    g  - recalibrate gyro bias (hold both sensors perfectly still)
    z  - set the CURRENT arm pose as the zero-angle reference
         (do this with the arm fully extended, hanging relaxed)
    m  - start a 5 s max-voluntary-contraction (MVC) window on all 3 EMG
         channels; contract the target muscle(s) as hard as you can during
         this window so activation can be reported as %MVC afterwards

  Outputs (same values, two transports):
    - Serial CSV, ~50 Hz (for debugging over USB):
        time_ms,elbow_deg,emg1_raw,emg1_pct,emg2_raw,emg2_pct,emg3_raw,emg3_pct
    - BLE notify, ~31 Hz: 16-byte packed payload of 4 little-endian floats
        (elbow_deg, emg1_pct, emg2_pct, emg3_pct) - see BLEStreamer.cpp for
        the service/characteristic UUIDs the phone app needs to match.

  See the accompanying guide for wiring, calibration procedure, the math
  behind the joint-angle calculation, and the BLE GATT profile.
*/

#include <Wire.h>
#include <math.h>
#include "MPU6500.h"
#include "MadgwickAHRS.h"
#include "EMGProcessor.h"
#include "BLEStreamer.h"

// Explicit forward declarations. Arduino's IDE normally auto-generates
// these from the .ino file, but that auto-prototyper can get confused by
// "static" functions depending on which ctags version is installed -
// declaring them ourselves avoids depending on that step altogether.
static void quatMultiply(float w1, float x1, float y1, float z1, float w2, float x2, float y2, float z2, float &w, float &x, float &y, float &z);
static void quatConjugate(float w, float x, float y, float z, float &cw, float &cx, float &cy, float &cz);
static float quatAngleDeg(float w, float x, float y, float z);
static void getRelativeQuat(float &w, float &x, float &y, float &z);
static void calibrateGyros();
static void setZeroPose();
static void handleCommand(char c);
static void pollCommandSources();

// ---------- Pin & bus configuration ----------
static const int PIN_I2C_SDA = 8;
static const int PIN_I2C_SCL = 9;

static const uint8_t ADDR_UPPER_ARM = 0x68; // AD0 -> GND
static const uint8_t ADDR_FOREARM   = 0x69; // AD0 -> 3V3

static const int PIN_EMG1 = 2; // ADC1_CH1
static const int PIN_EMG2 = 5; // ADC1_CH4
static const int PIN_EMG3 = 6; // ADC1_CH5

// ---------- Timing ----------
// NOTE: LOOP_PERIOD_US must stay consistent with the SMPLRT_DIV value
// written in MPU6500::begin() (currently 500 Hz / SMPLRT_DIV=1). If you
// change one, change the other, or you'll be polling faster or slower
// than the sensor is actually producing new samples.
static const uint32_t LOOP_PERIOD_US = 2000;  // 500 Hz fusion/EMG update
static const uint8_t  PRINT_DECIMATE = 10;    // Serial CSV every 10th loop -> 50 Hz
static const uint8_t  BLE_DECIMATE   = 16;    // BLE notify every 16th loop -> ~31 Hz
                                               // (kept lower than the serial rate on
                                               // purpose - real phones, especially iOS,
                                               // won't reliably grant BLE connection
                                               // intervals fast enough to sustain 50 Hz)

static const char *BLE_DEVICE_NAME = "ArmEMG-IMU";

// ---------- Objects ----------
MPU6500 imuUpper(ADDR_UPPER_ARM);
MPU6500 imuForearm(ADDR_FOREARM);
MadgwickAHRS fusionUpper(0.1f);
MadgwickAHRS fusionForearm(0.1f);
EMGProcessor emg1(PIN_EMG1);
EMGProcessor emg2(PIN_EMG2);
EMGProcessor emg3(PIN_EMG3);

float qZeroW = 1, qZeroX = 0, qZeroY = 0, qZeroZ = 0;

uint32_t lastLoopMicros = 0;
uint8_t printCounter = 0;
uint8_t bleCounter = 0;

// ---------- Quaternion helpers ----------
/*The quaternion functions (quatMultiply, quatConjugate, quatAngleDeg, getRelativeQuat)

What: Four functions implementing the actual rotation math: combine two rotations, invert a rotation, extract a single angle from one, and 
— using the first three — compute the forearm's orientation relative to the upper arm's.
Why: This is the mathematical core of the whole project —
 the reason two IMUs produce one elbow angle instead of two independent, not-very-useful numbers.
How: quatMultiply is the fixed formula for combining rotations 
(order matters — it's not the same as regular multiplication).
 quatConjugate flips the sign of the x/y/z components, which mathematically means "undo this rotation." 
 quatAngleDeg pulls a plain angle back out using atan2f, with a sign-flip guard at the top handling a real mathematical quirk 
 (a quaternion and its negative represent the identical rotation).
getRelativeQuat chains these together: grab both sensors' current orientation, undo the upper-arm's, 
combine what's left with the forearm's — leaving only the difference between them.*/

static void quatMultiply(float w1, float x1, float y1, float z1, float w2, float x2, float y2, float z2, float &w, float &x, float &y, float &z) {
  w = w1*w2 - x1*x2 - y1*y2 - z1*z2;
  x = w1*x2 + x1*w2 + y1*z2 - z1*y2;
  y = w1*y2 - x1*z2 + y1*w2 + z1*x2;
  z = w1*z2 + x1*y2 - y1*x2 + z1*w2;
}

static void quatConjugate(float w, float x, float y, float z, float &cw, float &cx, float &cy, float &cz) {
  cw = w; cx = -x; cy = -y; cz = -z;
}

// Total rotation angle represented by a unit quaternion, in degrees,
// folded into [0, 180] by always taking the shortest-path representation.
static float quatAngleDeg(float w, float x, float y, float z) {
  if (w < 0) { w = -w; x = -x; y = -y; z = -z; }
  float angle = 2.0f * atan2f(sqrtf(x*x + y*y + z*z), w);
  return angle * RAD_TO_DEG;
}

// Orientation of the forearm sensor as seen from the upper-arm sensor's frame.
static void getRelativeQuat(float &w, float &x, float &y, float &z) {
  float uw, ux, uy, uz, fw, fx, fy, fz;
  fusionUpper.getQuaternion(uw, ux, uy, uz);
  fusionForearm.getQuaternion(fw, fx, fy, fz);

  float cw, cx, cy, cz;
  quatConjugate(uw, ux, uy, uz, cw, cx, cy, cz);
  quatMultiply(cw, cx, cy, cz, fw, fx, fy, fz, w, x, y, z);
}

/*What: Two small named actions — recalibrate both sensors' rest bias, and capture the current pose as the new "zero."
Why: Giving these their own names (rather than inlining the code wherever needed) means handleCommand and setup() can 
both just say "do the gyro calibration" without duplicating what that actually involves.
How: setZeroPose calls the same getRelativeQuat from above, but writes the result into the global qZero variables 
instead of temporary local ones — that's the one line that makes the calibration "stick" for every future loop iteration.*/
static void calibrateGyros() {
  Serial.println(F("Calibrating gyro bias - keep both sensors perfectly still..."));
  imuUpper.calibrateGyroBias(300);
  imuForearm.calibrateGyroBias(300);
  Serial.println(F("Gyro calibration done."));
}

static void setZeroPose() {
  getRelativeQuat(qZeroW, qZeroX, qZeroY, qZeroZ);
  Serial.println(F("Zero pose captured."));
}

// Single place that acts on a calibration command, regardless of whether it
// arrived over USB serial or a BLE write - keeps the two transports from
// needing their own copies of this logic.
static void handleCommand(char c) {
  switch (c) {
    case 'g': calibrateGyros(); break;
    case 'z': setZeroPose(); break;
    case 'm':
      Serial.println(F("MVC calibration: contract muscles hard for 5s..."));
      emg1.startMVCCalibration(5000);
      emg2.startMVCCalibration(5000);
      emg3.startMVCCalibration(5000);
      break;
    default: break; // ignore newlines / unrecognised characters
  }
}

/*What: Checks both possible places a command could come from — USB serial and BLE 
— and if either has something waiting, hands it to handleCommand.
Why: This is the concrete answer to "how do Serial and BLE share one command handler" 
— rather than writing the switch statement twice (once per transport), both transports funnel into this one shared function.
How: Serial.available() and bleStreamer.hasCommand() are both non-blocking checks 
— "is something waiting?" — so this function never pauses the loop waiting for input; it just glances at both,
 acts if there's something, and moves on.*/
static void pollCommandSources() {
  if (Serial.available()) {
    handleCommand(Serial.read());
  }
  if (bleStreamer.hasCommand()) {
    handleCommand(bleStreamer.readCommand());
  }
}

void setup() {
  Serial.begin(115200);
  delay(300);

  Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL);
  Wire.setClock(400000);

  analogReadResolution(12);

  bool ok1 = imuUpper.begin(Wire);
  bool ok2 = imuForearm.begin(Wire);
  if (!ok1) Serial.println(F("WARNING: upper-arm MPU6500 (0x68) not detected or failed to configure - check wiring/AD0."));
  if (!ok2) Serial.println(F("WARNING: forearm MPU6500 (0x69) not detected or failed to configure - check wiring/AD0."));

  emg1.begin();
  emg2.begin();
  emg3.begin();

  bleStreamer.begin(BLE_DEVICE_NAME);

  calibrateGyros();

  Serial.println(F("Ready. Hold arm at reference pose (fully extended) and send 'z'."));
  Serial.print(F("Advertising over BLE as: "));
  Serial.println(BLE_DEVICE_NAME);
  Serial.println(F("time_ms,elbow_deg,emg1_raw,emg1_pct,emg2_raw,emg2_pct,emg3_raw,emg3_pct"));

  lastLoopMicros = micros();
}

void loop() {
  uint32_t now = micros();
  if ((uint32_t)(now - lastLoopMicros) < LOOP_PERIOD_US) return;
  float dt = (now - lastLoopMicros) / 1000000.0f;
  lastLoopMicros = now;

  pollCommandSources();

  float ax, ay, az, gx, gy, gz;
  if (imuUpper.read(ax, ay, az, gx, gy, gz)) {
    fusionUpper.updateIMU(gx, gy, gz, ax, ay, az, dt);
  }
  if (imuForearm.read(ax, ay, az, gx, gy, gz)) {
    fusionForearm.updateIMU(gx, gy, gz, ax, ay, az, dt);
  }

  emg1.update();
  emg2.update();
  emg3.update();

  printCounter++;
  bleCounter++;
  if (printCounter >= PRINT_DECIMATE || bleCounter >= BLE_DECIMATE) {
    // Computed once and shared by whichever output(s) are due this pass -
    // no point doing the quaternion math twice for the same instant.
    float relW, relX, relY, relZ, zw, zx, zy, zz;
    getRelativeQuat(relW, relX, relY, relZ);
    quatConjugate(qZeroW, qZeroX, qZeroY, qZeroZ, zw, zx, zy, zz);

    float ow, ox, oy, oz;
    quatMultiply(zw, zx, zy, zz, relW, relX, relY, relZ, ow, ox, oy, oz);
    float elbowDeg = quatAngleDeg(ow, ox, oy, oz);

    float emg1Pct = emg1.getPercentMVC();
    float emg2Pct = emg2.getPercentMVC();
    float emg3Pct = emg3.getPercentMVC();

    if (printCounter >= PRINT_DECIMATE) {
      printCounter = 0;
      Serial.print(millis());
      Serial.print(',');
      Serial.print(elbowDeg, 2);
      Serial.print(',');
      Serial.print(emg1.getRaw());
      Serial.print(',');
      Serial.print(emg1Pct, 1);
      Serial.print(',');
      Serial.print(emg2.getRaw());
      Serial.print(',');
      Serial.print(emg2Pct, 1);
      Serial.print(',');
      Serial.print(emg3.getRaw());
      Serial.print(',');
      Serial.println(emg3Pct, 1);
    }

    if (bleCounter >= BLE_DECIMATE) {
      bleCounter = 0;
      bleStreamer.sendData(elbowDeg, emg1Pct, emg2Pct, emg3Pct);
    }
  }
}
