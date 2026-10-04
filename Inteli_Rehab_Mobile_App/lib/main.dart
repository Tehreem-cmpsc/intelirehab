import 'package:flutter/material.dart';

import 'app.dart';
import 'core/network/supabase_client.dart';
import 'features/exercises/processing/elbow_rep_checker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  // Loads the elbow rep model in the background. A live session that starts before it is ready, or
  // without it, simply uses the simple rep rules.
  ElbowRepChecker.preload();
  runApp(const InteliRehabApp());
}
