import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/di/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/auto_backup_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_logger.dart';
import 'data/database/app_database.dart';
import 'data/repositories/health_service.dart';
import 'core/services/crash_reporting_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Log uncaught Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.error('Flutter Framework Error', details.exception, details.stack);
    CrashReportingService.recordCrash(details.exception, details.stack ?? StackTrace.current, reason: 'Flutter Framework Error');
  };

  // Log uncaught asynchronous errors in the root zone
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLogger.error('Async Root Zone Error', error, stack);
    CrashReportingService.recordCrash(error, stack, reason: 'Async Root Zone Error');
    return true;
  };

  // Initialize local notification service & schedule reminders
  final db = AppDatabase();
  await NotificationService.initialize();
  await NotificationService.scheduleAllReminders(db);

  // Trigger auto-backup check in background
  AutoBackupService.performBackup(db).catchError((e) {
    AppLogger.warning('Auto-backup startup check failed: $e');
  });

  // Trigger Health Service auto-sync on open if enabled
  SharedPreferences.getInstance().then((prefs) {
    final autoSync = prefs.getBool('auto_sync_health_on_open') ?? true;
    if (autoSync) {
      HealthService().fetchTodayHealthData().catchError((e) {
        AppLogger.warning('Health auto-sync startup check failed: $e');
        return const HealthDataSummary();
      });
    }
  });

  await CrashReportingService.initialize(() {
    runApp(
      const ProviderScope(
        child: IndiFitApp(),
      ),
    );
  });
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
