import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase client configuration connecting to Tehreem's backend.
/// Project URL and Anon/Publishable key match Intelli_Rehab_Web_Portal / Inteli_Rehab_Mobile_App.
class SupabaseService {
  static const String supabaseUrl = 'https://ewnetwncsuvbvtrnuyke.supabase.co';
  static const String supabasePublishableKey = 'sb_publishable_9GgLEFrfxrtFrIqL3xaSAA_hoAzuT5h';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}

/// Top-level getter matching Tehreem's codebase
SupabaseClient get supabase => SupabaseService.client;
