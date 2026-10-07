
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
static void statusLedSet(bool on);
static void updateStatusLed();
static void waitForSerial(uint32_t maxMs);
static void scanI2cBus();
static void printStatusLine();
static void reportImu(const char *name, uint8_t addr, const MPU6500 &imu, bool ok);
static void reportImuReadFailures();
static void calibrateGyros();
static void setZeroPose();
static void handleCommand(char c);
static void pollCommandSources();
static void retryMissingImus();

// ---------- Pin & bus configuration ----------
static const int PIN_I2C_SDA = 8;
static const int PIN_I2C_SCL = 9;

static const uint8_t ADDR_UPPER_ARM = 0x68; // AD0 -> GND
static const uint8_t ADDR_FOREARM   = 0x69; // AD0 -> 3V3

static const int PIN_EMG1 = 2; // ADC1_CH1

// ---------- Status LED ----------
// Most ESP32-S3 dev boards (e.g. DevKitC-1) have an addressable RGB LED
// rather than a plain one; the Arduino core exposes it as RGB_BUILTIN.
// Boards with a simple single-colour LED expose LED_BUILTIN instead.
// If your board defines neither, set PIN_STATUS_LED to the GPIO manually.
#if defined(RGB_BUILTIN)
static const int PIN_STATUS_LED = RGB_BUILTIN;
#elif defined(LED_BUILTIN)
static const int PIN_STATUS_LED = LED_BUILTIN;
#else
static const int PIN_STATUS_LED = 48;   // DevKitC-1 v1.0 RGB LED; v1.1 uses 38
#endif

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

/*What: Drives the board's built-in LED on or off.
Why: The LED is a connection indicator - off while the band is only advertising, on once the phone
 has an established BLE link - so a patient can tell at a glance whether the band is connected.
How: On RGB_BUILTIN boards the ESP32 Arduino core intercepts digitalWrite and drives the RGB LED white;
 on a plain LED it simply sets the pin high/low. (For a specific colour on an RGB LED, use
 rgbLedWrite(PIN_STATUS_LED, r, g, b) on core 3.x, or neopixelWrite on core 2.x.)*/
static void statusLedSet(bool on) {
  digitalWrite(PIN_STATUS_LED, on ? HIGH : LOW);
}

/*What: Makes the LED follow the BLE connection state.
Why: Called every loop pass, but only touches the pin when the state actually changes, so a
 connect or an unexpected drop (out of range, phone app closed) is reflected within one loop period
 without rewriting the LED hundreds of times a second.
How: bleStreamer.isConnected() is true from the BLE stack's onConnect callback until onDisconnect.*/
static void updateStatusLed() {
  static bool lit = false;
  bool connected = bleStreamer.isConnected();
  if (connected != lit) {
    lit = connected;
    statusLedSet(lit);
  }
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
    case 'i': scanI2cBus(); printStatusLine(); break; // diagnostics on demand
    case 'm':
      Serial.println(F("MVC calibration: contract muscle hard for 3s..."));
      emg1.startMVCCalibration(3000); // keep in step with the app (calibration_step.dart _mvcSeconds)
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

/*What: Waits (briefly) for the USB serial connection to be open before anything is printed.
Why: With "USB CDC On Boot" enabled, Serial is a virtual USB port that only exists once the PC has
 opened it. Anything printed before that is silently dropped, so the boot messages (and the IMU
 status lines that explain a wiring problem) would never be seen. On a plain UART, or with no PC
 attached, this just times out and boot carries on - it never blocks the band from starting.*/
static void waitForSerial(uint32_t maxMs) {
  uint32_t start = millis();
  while (!Serial && (millis() - start) < maxMs) {
    delay(10);
  }
  delay(100); // let the host finish attaching
}

/*What: Lists every I2C address that answers on the bus.
Why: This separates "the wiring is wrong" from "the code is wrong". Two MPU6500s correctly wired show
 up as 0x68 and 0x69. Nothing listed means the bus is dead (SDA/SCL pins, power, ground, pull-ups);
 only one address means a sensor is missing or both are strapped to the same address; a different
 address means a different part or a miswired AD0 pin.
How: Probes each address with an empty write; a device that ACKs is present.*/
static uint8_t i2cFound[16];
static uint8_t i2cFoundCount = 0;
static bool imuUpperOk = false, imuForearmOk = false;

static void scanI2cBus() {
  i2cFoundCount = 0;
  Serial.print(F("I2C scan (SDA="));
  Serial.print(PIN_I2C_SDA);
  Serial.print(F(", SCL="));
  Serial.print(PIN_I2C_SCL);
  Serial.println(F("):"));
  int found = 0;
  for (uint8_t addr = 0x08; addr < 0x78; addr++) {
    Wire.beginTransmission(addr);
    if (Wire.endTransmission() == 0) {
      Serial.print(F("  device at 0x"));
      Serial.println(addr, HEX);
      if (i2cFoundCount < sizeof(i2cFound)) i2cFound[i2cFoundCount++] = addr;
      found++;
    }
  }
  if (found == 0) Serial.println(F("  NOTHING FOUND - check SDA/SCL wiring, 3V3, GND and pull-ups."));
}

/*What: Prints one line saying whether an IMU answered, and what it said.
Why: "No data" on the serial monitor has several very different causes. The WHO_AM_I value tells
 them apart: 0x00 / no answer = nothing on the bus (wiring, power, wrong address, missing pull-ups);
 0x70/0x71/0x73/0x68 = a real chip that is accepted; anything else = a different chip.*/
static void reportImu(const char *name, uint8_t addr, const MPU6500 &imu, bool ok) {
  Serial.print(name);
  Serial.print(F(" IMU (0x"));
  Serial.print(addr, HEX);
  Serial.print(F("): "));
  if (ok) {
    Serial.print(F("OK, WHO_AM_I=0x"));
    Serial.println(imu.lastWhoAmI(), HEX);
  } else if (imu.lastWhoAmI() == 0) {
    Serial.println(F("NO ANSWER - check wiring, power, SDA/SCL pins and the AD0 address."));
  } else {
    Serial.print(F("FAILED, WHO_AM_I=0x"));
    Serial.print(imu.lastWhoAmI(), HEX);
    Serial.println(F(" - unexpected chip, or its configuration could not be verified."));
  }
}

/*What: One compact line summarising the sensor state, printed every 5 s and on the 'i' command.
Why: The boot messages scroll away (or are printed before the serial monitor attaches), so the answer
 to "why is the angle stuck at 0?" must be repeated in the stream itself. It starts with '#' so it
 is easy to tell from the CSV data lines.
How: Shows which I2C addresses answered at boot, whether each IMU initialised, and its WHO_AM_I.*/
static void printStatusLine() {
  Serial.print(F("# status i2c=["));
  for (uint8_t i = 0; i < i2cFoundCount; i++) {
    if (i) Serial.print(' ');
    Serial.print(F("0x"));
    Serial.print(i2cFound[i], HEX);
  }
  Serial.print(F("] upper(0x68)="));
  Serial.print(imuUpperOk ? F("OK") : F("FAIL"));
  Serial.print(F(" who=0x"));
  Serial.print(imuUpper.lastWhoAmI(), HEX);
  Serial.print(F(" forearm(0x69)="));
  Serial.print(imuForearmOk ? F("OK") : F("FAIL"));
  Serial.print(F(" who=0x"));
  Serial.println(imuForearm.lastWhoAmI(), HEX);
}

// Counts failed IMU reads in the main loop and reports them at most every 2 s, so a sensor that
// drops out after boot (loose wire) is visible without flooding the monitor.
static uint32_t upperReadFails = 0, forearmReadFails = 0;
static bool upperLastReadOk = false, forearmLastReadOk = false; // shown on every CSV line
static void reportImuReadFailures() {
  static uint32_t lastReport = 0;
  uint32_t nowMs = millis();
  if ((nowMs - lastReport) < 2000) return;
  lastReport = nowMs;
  if (upperReadFails || forearmReadFails) {
    Serial.print(F("WARNING: IMU read failures in last 2s - upper: "));
    Serial.print(upperReadFails);
    Serial.print(F(", forearm: "));
    Serial.println(forearmReadFails);
    upperReadFails = forearmReadFails = 0;
  }
}

/*What: Tries again, once a second, to start any IMU that did not answer at boot.
Why: begin() used to run only in setup(). A sensor that was not answering at that moment (a loose wire,
 or its AD0 wire moved while the band was on) was then never used, so its orientation never changed and
 the elbow angle sat at 0 until a full restart.
How: When a retry succeeds, that sensor's gyro bias is measured again (hold still for ~0.6 s) and its
 fusion filter restarts from rest. Send 'z' afterwards to set the zero pose with both sensors working.*/
static void retryMissingImus() {
  static uint32_t lastTry = 0;
  if (imuUpperOk && imuForearmOk) return;
  uint32_t nowMs = millis();
  if ((nowMs - lastTry) < 1000) return;
  lastTry = nowMs;
  if (!imuUpperOk && imuUpper.begin(Wire)) {
    imuUpperOk = true;
    imuUpper.calibrateGyroBias(300);
    fusionUpper.reset();
    Serial.println(F("Upper arm IMU (0x68) found after boot - now in use. Send 'z' to set the zero pose."));
  }
  if (!imuForearmOk && imuForearm.begin(Wire)) {
    imuForearmOk = true;
    imuForearm.calibrateGyroBias(300);
    fusionForearm.reset();
    Serial.println(F("Forearm IMU (0x69) found after boot - now in use. Send 'z' to set the zero pose."));
  }
  lastLoopMicros = micros(); // the calibration paused the loop; don't feed fusion one huge time step
}

void setup() {
  pinMode(PIN_STATUS_LED, OUTPUT);
  statusLedSet(false);    // off until a phone connects over BLE (see updateStatusLed)

  Serial.begin(115200);
  waitForSerial(2500);
  Serial.println();
  Serial.println(F("=== ArmEMG-IMU firmware booting ==="));

  Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL);
  Wire.setClock(400000);

  analogReadResolution(12);

  scanI2cBus();

  bool ok1 = imuUpper.begin(Wire);
  bool ok2 = imuForearm.begin(Wire);
  imuUpperOk = ok1;
  imuForearmOk = ok2;
  reportImu("Upper arm", ADDR_UPPER_ARM, imuUpper, ok1);
  reportImu("Forearm", ADDR_FOREARM, imuForearm, ok2);

  emg1.begin();

  bleStreamer.begin(BLE_DEVICE_NAME);

  calibrateGyros();

  Serial.println(F("Ready. Hold arm at reference pose (fully extended) and send 'z'."));
  Serial.print(F("Advertising over BLE as: "));
  Serial.println(BLE_DEVICE_NAME);
  Serial.println(F("time_ms,elbow_deg,emg1_raw,emg1_pct,imu_upper_ok,imu_forearm_ok"));

  lastLoopMicros = micros();
}

void loop() {
  uint32_t now = micros();
  if ((uint32_t)(now - lastLoopMicros) < LOOP_PERIOD_US) return;
  float dt = (now - lastLoopMicros) / 1000000.0f;
  lastLoopMicros = now;

  updateStatusLed();
  pollCommandSources();

  float ax, ay, az, gx, gy, gz;
  upperLastReadOk = imuUpper.read(ax, ay, az, gx, gy, gz);
  if (upperLastReadOk) {
    fusionUpper.updateIMU(gx, gy, gz, ax, ay, az, dt);
  } else {
    upperReadFails++;
  }
  forearmLastReadOk = imuForearm.read(ax, ay, az, gx, gy, gz);
  if (forearmLastReadOk) {
    fusionForearm.updateIMU(gx, gy, gz, ax, ay, az, dt);
  } else {
    forearmReadFails++;
  }
  reportImuReadFailures();
  retryMissingImus();
  {
    static uint32_t lastStatus = 0;
    if ((millis() - lastStatus) >= 5000) {
      lastStatus = millis();
      printStatusLine();
    }
  }

  emg1.update();

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
    // The angle only means something when BOTH sensors are being read. With one missing, the number
    // would follow the other sensor alone (and drift), which looks like real movement but is not.
    // Send NaN instead: the app ignores it and tells the patient it cannot see the arm move.
    if (!(upperLastReadOk && forearmLastReadOk)) elbowDeg = NAN;

    float emg1Pct = emg1.getPercentMVC();

    if (printCounter >= PRINT_DECIMATE) {
      printCounter = 0;
      Serial.print(millis());
      Serial.print(',');
      Serial.print(elbowDeg, 2);
      Serial.print(',');
      Serial.print(emg1.getRaw());
      Serial.print(',');
      Serial.print(emg1Pct, 1);
      // 1 = that IMU is configured and its last read worked, 0 = it is not
      // working. Two 1s with a flat elbow_deg means the sensors are fine and
      // simply not seeing a bend; a 0 names the sensor that is broken.
      Serial.print(',');
      Serial.print(upperLastReadOk ? 1 : 0);
      Serial.print(',');
      Serial.println(forearmLastReadOk ? 1 : 0);
    }

    if (bleCounter >= BLE_DECIMATE) {
      bleCounter = 0;
      bleStreamer.sendData(elbowDeg, emg1Pct);
    }
  }
}
