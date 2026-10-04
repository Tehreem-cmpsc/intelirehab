"""The band's Bluetooth profile, as the phone app sees it.

Kept identical to Inteli_Rehab_Mobile_App/lib/features/home/ble/arm_band_protocol.dart and
firmware/lib/ArmEMG_IMU/BLEStreamer.cpp. If one changes, change all three.
"""
import struct

DEVICE_NAME = "ArmEMG-IMU"
SERVICE_UUID = "a1b2c3d0-0001-4000-8000-00805f9b34fb"
DATA_UUID = "a1b2c3d0-0002-4000-8000-00805f9b34fb"  # notify: the sensor packet
CMD_UUID = "a1b2c3d0-0003-4000-8000-00805f9b34fb"  # write: one command byte

CMD_RECALIBRATE_GYRO = b"g"  # hold the band still
CMD_SET_ZERO_POSE = b"z"  # arm hanging relaxed: this pose becomes 0 degrees
CMD_START_MVC = b"m"  # 5 s maximum contraction window

NOMINAL_RATE_HZ = 31.25  # the band's notify rate; the real rate is measured per recording


def parse_packet(data):
    """Returns (elbow_deg, emg_pct) from one notification, or None if it is not a valid packet.

    Eight bytes: two little-endian 32-bit floats. (The app also accepts 16 bytes and reads the first eight.)
    """
    if len(data) not in (8, 16):
        return None
    elbow_deg, emg_pct = struct.unpack("<ff", bytes(data[:8]))
    if elbow_deg != elbow_deg or emg_pct != emg_pct:  # NaN
        return None
    return elbow_deg, emg_pct
