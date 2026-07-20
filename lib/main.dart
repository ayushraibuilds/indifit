import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/colors.dart';
import 'core/services/notification_service.dart';
import 'features/dashboard/main_navigation_scaffold.dart';
import 'features/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local notification service & schedule reminders
  await NotificationService.initialize();
  await NotificationService.scheduleAllReminders();

  runApp(
    const ProviderScope(
      child: IndiFitApp(),
    ),
  );
}

class IndiFitApp extends ConsumerWidget {
  const IndiFitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'IndiFit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: FutureBuilder<bool>(
        future: SharedPreferences.getInstance().then((prefs) => prefs.getBool('onboarding_completed') ?? false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
          if (snapshot.data == true) {
            return const MainNavigationScaffold();
          }
          return const OnboardingScreen();
        },
      ),
    );
  }
}
