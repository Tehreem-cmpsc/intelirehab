#ifndef MADGWICK_AHRS_H
#define MADGWICK_AHRS_H

// Madgwick's IMU-only (6DOF: gyro+accel, no magnetometer) orientation filter.
// Reference: S.O.H. Madgwick, "An efficient orientation filter for inertial
// and inertial/magnetic sensor arrays", 2010 (open-source AHRS algorithm,
// MadgwickAHRSupdateIMU variant). Re-implemented here without the classic
// fast-inverse-sqrt bit hack, since the ESP32-S3 has a hardware FPU.
class MadgwickAHRS {
public:
    explicit MadgwickAHRS(float betaGain = 0.1f);

    // Resets orientation to identity (w=1,x=y=z=0).
    void reset();

    // gx,gy,gz in rad/s. ax,ay,az in any consistent unit (internally
    // normalised), only their direction matters. dt in seconds.
    void updateIMU(float gx, float gy, float gz, float ax, float ay, float az, float dt);

    void getQuaternion(float &w, float &x, float &y, float &z) const;

    // Filter gain: higher trusts the accelerometer more (faster correction,
    // more sensitive to real linear acceleration / vibration noise), lower
    // trusts the gyro more (smoother, but drifts more over time).
    // Typical range 0.01 - 0.3; this does not need to be re-tuned if you
    // change the sample rate.
    float beta;

private:
    float q0, q1, q2, q3;
};

#endif
