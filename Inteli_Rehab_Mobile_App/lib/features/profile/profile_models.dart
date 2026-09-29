/// Everything the Profile screen shows, straight from Supabase — see
/// ProfileRepository. Nothing here is invented past PATIENT / WEARABLE_DEVICE
/// and the clinic/physio names resolved through the existing onboarding
/// lookups (patients can't read `clinics`/`physiotherapists` directly).
class ProfileData {
  final String name;
  final String phone;
  final String email;
  final DateTime? dateOfBirth;
  final String? gender;
  final double? heightCm;
  final double? weightKg;

  final String? clinicName;
  final String? physioName;

  final PairedDevice? device;

  const ProfileData({
    required this.name,
    required this.phone,
    required this.email,
    required this.dateOfBirth,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.clinicName,
    required this.physioName,
    required this.device,
  });
}

class PairedDevice {
  final String id;
  final String serial;
  final String? firmware;
  final int batteryPercent;

  const PairedDevice({
    required this.id,
    required this.serial,
    required this.firmware,
    required this.batteryPercent,
  });

  /// Same friendly-name convention as OnboardingRepository.hydrate.
  String get displayName => 'Inteli Band ${serial.length > 4 ? serial.substring(serial.length - 4) : serial}';
}
