import 'package:supabase_flutter/supabase_flutter.dart';

/// Same Supabase project the web portal (Intelli_Rehab_Web_Portal/.env) uses.
/// This is the publishable/anon key — safe to embed in a client app; every
/// table it touches is gated by the RLS policies in the supabase_*.sql files.
const _supabaseUrl = 'https://ewnetwncsuvbvtrnuyke.supabase.co';
const _supabasePublishableKey = 'sb_publishable_9GgLEFrfxrtFrIqL3xaSAA_hoAzuT5h';

/// [authOptions] lets tests swap in in-memory session storage.
Future<void> initSupabase({FlutterAuthClientOptions authOptions = const FlutterAuthClientOptions()}) {
  return Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
    authOptions: authOptions,
  );
}

SupabaseClient get supabase => Supabase.instance.client;
