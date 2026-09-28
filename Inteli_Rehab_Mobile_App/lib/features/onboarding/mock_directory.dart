import 'onboarding_data.dart';

/// Stand-in for a Bluetooth scan: the wearable step's search / connect is
/// still simulated until a BLE plugin is added. The chosen band *is*
/// saved to wearable_devices (see OnboardingRepository.saveWearable).
const mockWearables = [
  WearableDevice('IR-A1F3', 'Inteli Band A1F3', 3, 86, firmware: '1.4.2'),
  WearableDevice('IR-7C02', 'Inteli Band 7C02', 1, 54, firmware: '1.4.2'),
];
