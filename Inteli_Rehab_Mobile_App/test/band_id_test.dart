// A saved band id that isn't a real BLE id (e.g. the simulated "IR-A1F3"
// serials from before pairing was real) must never reach the OS: Android
// throws "not a valid Bluetooth address" and the band could never connect.
import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/features/home/ble/arm_band_ble_service.dart';

void main() {
  group('ArmBandBleService.isValidDeviceId', () {
    test('accepts an Android MAC address and an iOS UUID', () {
      expect(ArmBandBleService.isValidDeviceId('24:6F:28:AB:CD:EF'), isTrue);
      expect(ArmBandBleService.isValidDeviceId('24:6f:28:ab:cd:ef'), isTrue);
      expect(ArmBandBleService.isValidDeviceId('E621E1F8-C36C-495A-93FC-0C247A3E6E5F'), isTrue);
    });

    test('rejects simulated serials and malformed ids', () {
      for (final id in ['IR-A1F3', '', '24:6F:28:AB:CD', '24:6F:28:AB:CD:EG', 'E621E1F8-C36C-495A-93FC']) {
        expect(ArmBandBleService.isValidDeviceId(id), isFalse, reason: id);
      }
    });
  });
}
