import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/colors.dart';

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
      home: const TempDashboardScreen(),
    );
  }
}

class TempDashboardScreen extends StatelessWidget {
  const TempDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IndiFit AI Coach'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryGlow,
                  borderRadius: BorderRadius.circular(50),
                ),
                padding: const EdgeInsets.all(24),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  size: 64,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'IndiFit is Ready!',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Indian Food Database & Gym Tracker. Database scaffolded successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
