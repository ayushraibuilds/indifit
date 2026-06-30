import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'features/dashboard/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase if keys are provided.
  // In development, if credentials are blank, we catch and bypass to support offline-first testing.
  try {
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    const supabaseAnonKey = String.fromEnvironment('SUPABASE_KEY', defaultValue: '');
    
    if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
    }
  } catch (e) {
    debugPrint("Supabase initialization bypassed or failed: $e");
  }

  runApp(
    const ProviderScope(
      child: IndiFitApp(),
    ),
  );
}

class IndiFitApp extends StatelessWidget {
  const IndiFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IndiFit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const DashboardScreen(),
    );
  }
}
