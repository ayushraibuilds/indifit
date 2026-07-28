import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/config/app_config.dart';
import 'core/di/providers.dart';
import 'core/privacy/privacy_policy.dart';
import 'core/router/app_router.dart';
import 'core/services/auto_backup_service.dart';
import 'core/services/crash_reporting_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_logger.dart';
import 'data/database/app_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validateBootstrapConfig();

  // Log uncaught Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.error(
      'Flutter Framework Error',
      details.exception,
      details.stack,
    );
    CrashReportingService.recordCrash(
      details.exception,
      details.stack ?? StackTrace.current,
      reason: 'Flutter Framework Error',
    );
  };

  // Log uncaught asynchronous errors in the root zone
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLogger.error('Async Root Zone Error', error, stack);
    CrashReportingService.recordCrash(
      error,
      stack,
      reason: 'Async Root Zone Error',
    );
    return true;
  };

  // Single ProviderContainer created up front so the AppDatabase instance
  // used here in main() (before the widget tree/ProviderScope exists) is the
  // exact same instance every `ref.watch(databaseProvider)` resolves to
  // later. Previously this created a second, separate AppDatabase()
  // connection to the same SQLite file, so writes made through one
  // connection wouldn't notify stream watchers listening via the other.
  final privacyPrefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      privacyPolicyProvider.overrideWith(
        (ref) => PrivacyPolicyNotifier(privacyPrefs),
      ),
    ],
  );
  final AppDatabase db = container.read(databaseProvider);

  // Initialize local notification service & schedule reminders
  await NotificationService.initialize();
  await NotificationService.scheduleAllReminders(db);

  // Trigger auto-backup check in background
  unawaited(
    AutoBackupService.performBackup(db).catchError((e) {
      AppLogger.warning('Auto-backup startup check failed: $e');
    }),
  );

  await CrashReportingService.initialize(() {
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const IndiFitApp(),
      ),
    );
  });
}

class IndiFitApp extends ConsumerWidget {
  const IndiFitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

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
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
