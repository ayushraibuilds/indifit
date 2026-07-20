import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/di/theme_provider.dart';
import 'core/router/app_router.dart';
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
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    NotificationService.onNotificationNavigate = (payload) {
      if (payload == 'workout') {
        router.go('/workout');
      } else if (payload.startsWith('meal_')) {
        final mealType = payload.replaceFirst('meal_', '');
        router.go('/food?mealType=$mealType');
      } else if (payload == 'weekly_report') {
        router.go('/weekly-report');
      }
    };

    return MaterialApp.router(
      title: 'IndiFit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
