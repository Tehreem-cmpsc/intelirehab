import 'package:flutter/material.dart';

import 'app.dart';
import 'core/network/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(const InteliRehabApp());
}
