import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/di/providers.dart';
import 'core/di/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/auto_backup_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_logger.dart';
import 'data/database/app_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register global crash & error handlers
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AppLogger.recordCrash(details.exception, details.stack, context: 'FlutterError');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLogger.recordCrash(error, stack, context: 'PlatformDispatcher');
    return true;
  };

  // Initialize local notification service & schedule reminders
  await NotificationService.initialize();
  await NotificationService.scheduleAllReminders();

  // Trigger auto-backup check in background
  final db = AppDatabase();
  AutoBackupService.performBackup(db).catchError((e) {
    AppLogger.warning('Auto-backup startup check failed: $e');
  });

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
