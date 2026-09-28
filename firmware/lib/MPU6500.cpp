#include "MPU6500.h"

MPU6500::MPU6500(uint8_t address)
    : _address(address), _wire(nullptr), _connected(false), _whoAmI(0),
      _accelScale(0), _gyroScale(0),
      _gyroBiasX(0), _gyroBiasY(0), _gyroBiasZ(0) {}

void MPU6500::writeRegister(uint8_t reg, uint8_t value) {
    _wire->beginTransmission(_address);
    _wire->write(reg);
    _wire->write(value);
    _wire->endTransmission();
}

bool MPU6500::readRegisters(uint8_t reg, uint8_t *buffer, uint8_t length) {
    _wire->beginTransmission(_address);
    _wire->write(reg);
    if (_wire->endTransmission(false) != 0) return false; // repeated start, keep bus held
    uint8_t got = _wire->requestFrom((uint8_t)_address, length);
    if (got != length) return false;
    for (uint8_t i = 0; i < length; i++) buffer[i] = _wire->read();
    return true;
}

uint8_t MPU6500::readRegister(uint8_t reg) {
    uint8_t value = 0;
    readRegisters(reg, &value, 1);
    return value;
}

bool MPU6500::writeAndVerify(uint8_t reg, uint8_t value, uint8_t maxAttempts) {
    for (uint8_t attempt = 0; attempt < maxAttempts; attempt++) {
        writeRegister(reg, value);
        delay(2);
        if (readRegister(reg) == value) return true;
    }
    return false;
}

bool MPU6500::begin(TwoWire &wire) {
    _wire = &wire;

    uint8_t whoAmI = 0;
    if (!readRegisters(MPU6500_REG_WHO_AM_I, &whoAmI, 1)) {
        _connected = false;
        return false;
    }
    _whoAmI = whoAmI;

    // Genuine MPU6500 silicon reports 0x70. A lot of boards sold as
    // "MPU6500" are actually MPU9250/9255 (0x71/0x73) with the same
    // register map for accel+gyro, or occasionally an MPU6050 (0x68).
    // We accept all of these rather than failing a working sensor.
    _connected = (whoAmI == 0x70 || whoAmI == 0x71 || whoAmI == 0x73 || whoAmI == 0x68);
    if (!_connected) return false;

    // Deliberately using &= (not &&) across all four writes: we want every
    // register attempted even if an earlier one failed, so a transient
    // glitch on one register doesn't leave a different one unconfigured.
    bool configOk = true;
    configOk &= writeAndVerify(MPU6500_REG_PWR_MGMT_1, 0x01);   // wake, PLL with X-gyro reference clock
    delay(10); // let the clock source switch settle before further writes
    configOk &= writeAndVerify(MPU6500_REG_CONFIG, 0x03);       // DLPF: ~41 Hz gyro / ~44.8 Hz accel, enables 1kHz internal ODR
    configOk &= writeAndVerify(MPU6500_REG_SMPLRT_DIV, 1);      // 1000 Hz / (1+1) = 500 Hz output rate
    configOk &= writeAndVerify(MPU6500_REG_GYRO_CONFIG, 0x08);  // +-500 dps
    configOk &= writeAndVerify(MPU6500_REG_ACCEL_CONFIG, 0x10); // +-8 g

    if (!configOk) {
        _connected = false; // chip answered, but we can't trust its configuration - don't report success
        return false;
    }

    _gyroScale = (500.0f / 32768.0f) * (PI / 180.0f); // rad/s per LSB
    _accelScale = 8.0f / 32768.0f;                     // g per LSB

    return true;
}

bool MPU6500::read(float &ax, float &ay, float &az, float &gx, float &gy, float &gz) {
    uint8_t raw[14];
    if (!readRegisters(MPU6500_REG_ACCEL_XOUT_H, raw, 14)) return false;

    int16_t rawAx = (int16_t)((raw[0] << 8) | raw[1]);
    int16_t rawAy = (int16_t)((raw[2] << 8) | raw[3]);
    int16_t rawAz = (int16_t)((raw[4] << 8) | raw[5]);
    // raw[6],raw[7] = temperature, unused here
    int16_t rawGx = (int16_t)((raw[8] << 8) | raw[9]);
    int16_t rawGy = (int16_t)((raw[10] << 8) | raw[11]);
    int16_t rawGz = (int16_t)((raw[12] << 8) | raw[13]);

    ax = rawAx * _accelScale;
    ay = rawAy * _accelScale;
    az = rawAz * _accelScale;

    gx = rawGx * _gyroScale - _gyroBiasX;
    gy = rawGy * _gyroScale - _gyroBiasY;
    gz = rawGz * _gyroScale - _gyroBiasZ;

    return true;
}

void MPU6500::calibrateGyroBias(uint16_t samples) {
    float sx = 0, sy = 0, sz = 0;
    float ax, ay, az, gx, gy, gz;

    // Temporarily zero the bias so read() returns raw (uncorrected) values
    // while we measure the offset.
    _gyroBiasX = _gyroBiasY = _gyroBiasZ = 0;

    uint16_t got = 0;
    for (uint16_t i = 0; i < samples; i++) {
        if (read(ax, ay, az, gx, gy, gz)) {
            sx += gx; sy += gy; sz += gz;
            got++;
        }
        delay(2);
    }
    if (got > 0) {
        _gyroBiasX = sx / got;
        _gyroBiasY = sy / got;
        _gyroBiasZ = sz / got;
    }
}
