#ifndef BLE_STREAMER_H
#define BLE_STREAMER_H

#include <Arduino.h>

// Streams sensor data to a connected BLE central (the phone app) and
// receives single-byte calibration commands back from it, over a small
// custom GATT service. This class hides all NimBLE details from the rest
// of the firmware.
class BLEStreamer {
public:
    void begin(const char *deviceName);

    // Sends one sample as a packed 8-byte payload: 2 little-endian floats
    // in the order (elbowDeg, emg1Pct). Does nothing if no
    // central is currently connected.
    void sendData(float elbowDeg, float emg1Pct);

    bool isConnected() const;

    // Mirrors Serial's available()/read() so the exact same command-handling
    // code can service both the USB serial link and the BLE write
    // characteristic without duplicating logic.
    bool hasCommand() const;
    char readCommand();
};

extern BLEStreamer bleStreamer; // single global instance, used the way Serial is used

#endif
