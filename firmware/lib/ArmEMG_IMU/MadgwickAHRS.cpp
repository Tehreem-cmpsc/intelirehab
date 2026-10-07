#include "MadgwickAHRS.h"
#include <math.h>

MadgwickAHRS::MadgwickAHRS(float betaGain) : beta(betaGain) {
    reset();
}

void MadgwickAHRS::reset() {
    q0 = 1.0f; q1 = 0.0f; q2 = 0.0f; q3 = 0.0f;
}

void MadgwickAHRS::updateIMU(float gx, float gy, float gz, float ax, float ay, float az, float dt) {
    float recipNorm;
    float s0, s1, s2, s3;
    float qDot1, qDot2, qDot3, qDot4;
    float _2q0, _2q1, _2q2, _2q3, _4q0, _4q1, _4q2, _8q1, _8q2, q0q0, q1q1, q2q2, q3q3;

    // Rate of change of quaternion from gyroscope
    qDot1 = 0.5f * (-q1 * gx - q2 * gy - q3 * gz);
    qDot2 = 0.5f * ( q0 * gx + q2 * gz - q3 * gy);
    qDot3 = 0.5f * ( q0 * gy - q1 * gz + q3 * gx);
    qDot4 = 0.5f * ( q0 * gz + q1 * gy - q2 * gx);

    // Only correct with the accelerometer if the reading is non-zero
    if (!(ax == 0.0f && ay == 0.0f && az == 0.0f)) {
        recipNorm = 1.0f / sqrtf(ax * ax + ay * ay + az * az);
        ax *= recipNorm; ay *= recipNorm; az *= recipNorm;

        _2q0 = 2.0f * q0; _2q1 = 2.0f * q1; _2q2 = 2.0f * q2; _2q3 = 2.0f * q3;
        _4q0 = 4.0f * q0; _4q1 = 4.0f * q1; _4q2 = 4.0f * q2;
        _8q1 = 8.0f * q1; _8q2 = 8.0f * q2;
        q0q0 = q0 * q0; q1q1 = q1 * q1; q2q2 = q2 * q2; q3q3 = q3 * q3;

        // Gradient descent corrective step
        s0 = _4q0 * q2q2 + _2q2 * ax + _4q0 * q1q1 - _2q1 * ay;
        s1 = _4q1 * q3q3 - _2q3 * ax + 4.0f * q0q0 * q1 - _2q0 * ay - _4q1 + _8q1 * q1q1 + _8q1 * q2q2 + _4q1 * az;
        s2 = 4.0f * q0q0 * q2 + _2q0 * ax + _4q2 * q3q3 - _2q3 * ay - _4q2 + _8q2 * q1q1 + _8q2 * q2q2 + _4q2 * az;
        s3 = 4.0f * q1q1 * q3 - _2q1 * ax + 4.0f * q2q2 * q3 - _2q2 * ay;

        // A zero-length correction (the estimate already matches gravity exactly) would divide by
        // zero and turn the orientation into NaN for good. Nothing to correct, so skip it.
        float sNorm = sqrtf(s0 * s0 + s1 * s1 + s2 * s2 + s3 * s3);
        if (sNorm > 1e-9f) {
            recipNorm = 1.0f / sNorm;
            s0 *= recipNorm; s1 *= recipNorm; s2 *= recipNorm; s3 *= recipNorm;

            qDot1 -= beta * s0;
            qDot2 -= beta * s1;
            qDot3 -= beta * s2;
            qDot4 -= beta * s3;
        }
    }

    // Integrate to yield the new quaternion
    q0 += qDot1 * dt;
    q1 += qDot2 * dt;
    q2 += qDot3 * dt;
    q3 += qDot4 * dt;

    float qNorm = sqrtf(q0 * q0 + q1 * q1 + q2 * q2 + q3 * q3);
    if (!(qNorm > 1e-9f) || isnan(qNorm) || isinf(qNorm)) {
        reset(); // a bad sample (NaN/inf from the sensor) must not freeze the estimate forever
        return;
    }
    recipNorm = 1.0f / qNorm;
    q0 *= recipNorm; q1 *= recipNorm; q2 *= recipNorm; q3 *= recipNorm;
}

void MadgwickAHRS::getQuaternion(float &w, float &x, float &y, float &z) const {
    w = q0; x = q1; y = q2; z = q3;
}
