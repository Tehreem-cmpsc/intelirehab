import 'package:supabase_flutter/supabase_flutter.dart';

/// Cloud & Infrastructure Layer (SDD §3.1.6) entry point — the one place
/// both the mobile app and the web portal's Supabase client point at the
/// same project (Intelli_Rehab_Web_Portal/.env), so auth, the database and
/// realtime all agree. This is the publishable/anon key — safe to embed in
/// a client app; every table it touches is gated by the RLS policies in
/// the supabase_*.sql files, which is what actually enforces "each layer
/// only reaches the one below it" for data access.
///
/// Override per build to point at another project (e.g. staging):
///   flutter build apk --dart-define=SUPABASE_URL=https://xyz.supabase.co
///                     --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
/// With no overrides the production project below is used.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://ewnetwncsuvbvtrnuyke.supabase.co');
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_9GgLEFrfxrtFrIqL3xaSAA_hoAzuT5h',
);

/// [authOptions] lets tests swap in in-memory session storage.
Future<void> initSupabase({FlutterAuthClientOptions authOptions = const FlutterAuthClientOptions()}) {
  return Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
    authOptions: authOptions,
  );
}

SupabaseClient get supabase => Supabase.instance.client;
