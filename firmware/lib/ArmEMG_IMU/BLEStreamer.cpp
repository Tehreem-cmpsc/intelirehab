#include "BLEStreamer.h"
#include <NimBLEDevice.h>

// Custom 128-bit UUIDs for this project's private GATT profile. These are
// arbitrary (not from any standard profile) - change them if you like, but
// keep the firmware and the phone app in sync since both must use the same
// values to find each other.
static const char *SERVICE_UUID   = "a1b2c3d0-0001-4000-8000-00805f9b34fb";
static const char *DATA_CHAR_UUID = "a1b2c3d0-0002-4000-8000-00805f9b34fb"; // notify: sensor data
static const char *CMD_CHAR_UUID  = "a1b2c3d0-0003-4000-8000-00805f9b34fb"; // write: calibration commands

struct __attribute__((packed)) SensorPacket {
    float elbowDeg;
    float emg1Pct;
    float emg2Pct;
    float emg3Pct;
};

static NimBLECharacteristic *dataChar = nullptr;
static volatile bool bleConnected = false;
static volatile char pendingCommand = 0;
static volatile bool hasPendingCommand = false;

class StreamerServerCallbacks : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer *server, NimBLEConnInfo &connInfo) override {
        bleConnected = true;
    }
    void onDisconnect(NimBLEServer *server, NimBLEConnInfo &connInfo, int reason) override {
        bleConnected = false;
        NimBLEDevice::startAdvertising(); // let the phone reconnect after it drops
    }
};

class StreamerCommandCallbacks : public NimBLECharacteristicCallbacks {
    void onWrite(NimBLECharacteristic *characteristic, NimBLEConnInfo &connInfo) override {
        std::string value = characteristic->getValue();
        if (!value.empty()) {
            pendingCommand = value[0];
            hasPendingCommand = true;
        }
    }
};

static StreamerServerCallbacks serverCallbacks;
static StreamerCommandCallbacks commandCallbacks;

void BLEStreamer::begin(const char *deviceName) {
    NimBLEDevice::init(deviceName);

    NimBLEServer *server = NimBLEDevice::createServer();
    server->setCallbacks(&serverCallbacks);

    NimBLEService *service = server->createService(SERVICE_UUID);

    dataChar = service->createCharacteristic(DATA_CHAR_UUID, NIMBLE_PROPERTY::NOTIFY);

    NimBLECharacteristic *cmdChar =
        service->createCharacteristic(CMD_CHAR_UUID, NIMBLE_PROPERTY::WRITE);
    cmdChar->setCallbacks(&commandCallbacks);

    service->start();

    NimBLEAdvertising *advertising = NimBLEDevice::getAdvertising();
    advertising->addServiceUUID(SERVICE_UUID);
    advertising->setName(deviceName);
    advertising->start();
}

void BLEStreamer::sendData(float elbowDeg, float emg1Pct, float emg2Pct, float emg3Pct) {
    if (!bleConnected || dataChar == nullptr) return;
    SensorPacket packet{elbowDeg, emg1Pct, emg2Pct, emg3Pct};
    dataChar->setValue((uint8_t *)&packet, sizeof(packet));
    dataChar->notify();
}

bool BLEStreamer::isConnected() const {
    return bleConnected;
}

bool BLEStreamer::hasCommand() const {
    return hasPendingCommand;
}

char BLEStreamer::readCommand() {
    hasPendingCommand = false;
    return pendingCommand;
}

BLEStreamer bleStreamer;
