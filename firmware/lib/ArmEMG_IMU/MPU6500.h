#ifndef MPU6500_H
#define MPU6500_H

#include <Arduino.h>
#include <Wire.h>

// MPU6500 register map (register addresses are also shared with MPU6050;
// only WHO_AM_I and full-scale sensitivities differ).
#define MPU6500_REG_SMPLRT_DIV   0x19
#define MPU6500_REG_CONFIG       0x1A
#define MPU6500_REG_GYRO_CONFIG  0x1B
#define MPU6500_REG_ACCEL_CONFIG 0x1C
#define MPU6500_REG_ACCEL_XOUT_H 0x3B
#define MPU6500_REG_PWR_MGMT_1   0x6B
#define MPU6500_REG_WHO_AM_I     0x75

class MPU6500 {
public:
    // address must be 0x68 (AD0 tied to GND) or 0x69 (AD0 tied to 3V3)
    explicit MPU6500(uint8_t address);

    // Wakes the sensor, configures ODR/DLPF/full-scale ranges, verifies WHO_AM_I.
    // Every configuration write is read back and confirmed before begin()
    // reports success - this is deliberate: a flaky I2C connection can let a
    // write silently fail while everything else keeps working, leaving the
    // chip on its power-on-default full-scale range while the driver still
    // assumes the range it meant to set. That produces plausible-looking but
    // wrong data (we hit exactly this: a ~4x accelerometer scale error from
    // a loose wire) instead of an obvious failure, so it's worth catching here.
    // Returns false if the sensor did not answer, answered with an
    // unexpected ID, or any configuration write could not be verified.
    bool begin(TwoWire &wire);

    // Reads one sample. Accel is in g, gyro is in rad/s and already has the
    // bias from calibrateGyroBias() subtracted. Returns false on I2C failure
    // (previous values are left untouched by the caller in that case).
    bool read(float &ax, float &ay, float &az, float &gx, float &gy, float &gz);

    // Averages `samples` raw gyro readings while the sensor MUST be held
    // still, and stores the result as the zero-rate offset used by read().
    // Takes roughly `samples * 2` ms.
    void calibrateGyroBias(uint16_t samples = 300);

    bool isConnected() const { return _connected; }
    uint8_t lastWhoAmI() const { return _whoAmI; }

    // Reads back a single register - exposed mainly for diagnostics (e.g.
    // confirming what's actually stored on the chip when something looks off).
    uint8_t readRegister(uint8_t reg);

private:
    uint8_t _address;
    TwoWire *_wire;
    bool _connected;
    uint8_t _whoAmI;

    float _accelScale; // g per LSB
    float _gyroScale;  // rad/s per LSB

    float _gyroBiasX, _gyroBiasY, _gyroBiasZ; // rad/s

    void writeRegister(uint8_t reg, uint8_t value);
    bool readRegisters(uint8_t reg, uint8_t *buffer, uint8_t length);

    // Writes reg=value, reads it back, and retries a few times if the
    // readback doesn't match - tolerates a one-off I2C glitch without
    // masking a persistently bad connection or register.
    bool writeAndVerify(uint8_t reg, uint8_t value, uint8_t maxAttempts = 3);
};

#endif
