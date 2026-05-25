import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url:      AppConstants.supabaseUrl,
    anonKey:  AppConstants.supabaseAnonKey,
    debug:    false,         // set to true during development for verbose logs
  );

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
