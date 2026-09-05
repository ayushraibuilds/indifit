import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/di/providers.dart';
import 'core/di/theme_provider.dart';
import 'core/privacy/privacy_policy.dart';
import 'core/router/app_router.dart';
import 'core/services/auto_backup_service.dart';
import 'core/services/crash_reporting_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/rest_presence_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_logger.dart';
import 'data/database/app_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      privacyPolicyProvider.overrideWith((ref) => PrivacyPolicyNotifier(prefs)),
      themeModeProvider.overrideWith((ref) => ThemeModeNotifier(prefs)),
      // Seed the synchronous router gate once; onboarding/restore/erase
      // flows keep it updated so navigation never re-awaits SharedPreferences.
      onboardingCompletedProvider.overrideWith(
        (ref) => prefs.getBool('onboarding_completed') ?? false,
      ),
    ],
  );
  // Construct the shared database eagerly so schema migrations run before
  // the first widget reads it. The post-frame bootstrap and the lifecycle
  // observer reuse this same instance through the container.
  container.read(databaseProvider);

  // Initialize the local notification plugin (timezone data + tap handling)
  // before first frame; it is cheap and required before any scheduling.
  await NotificationService.initialize();

  // R07F-0: reminder rescheduling and the auto-backup check previously ran
  // (awaited) before runApp, delaying the first frame. They are deliberately
  // moved to a post-frame bootstrap in _IndiFitAppState — they only need to
  // complete within the first seconds after launch, not before UI exists.
  // Sentry keeps wrapping runApp because that is the documented correct
  // integration for capturing startup crashes.
  await CrashReportingService.initialize(() {
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const IndiFitApp(),
      ),
    );
  });
}

class IndiFitApp extends ConsumerStatefulWidget {
  const IndiFitApp({super.key});

  @override
  ConsumerState<IndiFitApp> createState() => _IndiFitAppState();
}

class _IndiFitAppState extends ConsumerState<IndiFitApp>
    with WidgetsBindingObserver {
  final List<StreamSubscription<dynamic>> _reminderDataSubscriptions = [];
  Timer? _reminderReconcileDebounce;
  bool _reminderReconcileRunning = false;
  bool _reminderReconcilePending = false;
  bool _reminderTimezoneRefreshPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(civilDateRevisionProvider.notifier).start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runPostFrameBootstrap();
    });
  }

  /// Non-critical startup work that must not delay the first frame.
  ///
  /// Reminder rescheduling (cancel + re-plan from preferences and the DB) and
  /// the auto-backup check run here, after the first frame has rendered.
  /// Failures are logged; the resume lifecycle check re-runs the timezone
  /// reschedule as before.
  void _runPostFrameBootstrap() {
    final db = ref.read(databaseProvider);
    _startReminderDataWatchers(db);
    unawaited(_reconcileReminders());
    // Clear any rest-timer notifications orphaned by a pre-restart crash.
    // No rest state is reconstructed: presence is foreground-driven and the
    // ticker does not survive process death by design.
    unawaited(
      RestPresenceService.cleanupStaleNotifications().catchError((e) {
        AppLogger.warning('Rest presence startup cleanup failed: $e');
      }),
    );
    unawaited(
      AutoBackupService.performBackup(db).catchError((e) {
        AppLogger.warning('Auto-backup startup check failed: $e');
      }),
    );
  }

  /// Reminder state depends on both legacy and canonical nutrition writes plus
  /// completed workout sessions. Reconcile centrally so every write path gets
  /// the same stale-reminder protection without UI-specific hooks.
  void _startReminderDataWatchers(AppDatabase db) {
    if (_reminderDataSubscriptions.isNotEmpty) return;
    _reminderDataSubscriptions.addAll([
      db.select(db.workoutSessions).watch().skip(1).listen((_) {
        _queueReminderReconciliation();
      }),
      db.select(db.foodLogs).watch().skip(1).listen((_) {
        _queueReminderReconciliation();
      }),
      db.select(db.nutritionConsumptionSnapshots).watch().skip(1).listen((_) {
        _queueReminderReconciliation();
      }),
    ]);
  }

  void _queueReminderReconciliation({bool refreshTimezone = false}) {
    _reminderTimezoneRefreshPending |= refreshTimezone;
    _reminderReconcileDebounce?.cancel();
    _reminderReconcileDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_reconcileReminders());
    });
  }

  /// Serializes cancel-and-replan operations. Writes that arrive while a plan
  /// is being built collapse into one additional pass rather than racing it.
  Future<void> _reconcileReminders() async {
    _reminderReconcilePending = true;
    if (_reminderReconcileRunning) return;

    _reminderReconcileRunning = true;
    try {
      while (_reminderReconcilePending) {
        _reminderReconcilePending = false;
        final refreshTimezone = _reminderTimezoneRefreshPending;
        _reminderTimezoneRefreshPending = false;
        final db = ref.read(databaseProvider);
        var alreadyRescheduled = false;
        if (refreshTimezone) {
          alreadyRescheduled =
              await NotificationService.checkAndUpdateTimezoneAndReschedule(db);
        }
        if (!alreadyRescheduled) {
          await NotificationService.scheduleAllReminders(db);
        }
      }
    } catch (e) {
      AppLogger.warning('Reminder reconciliation failed: $e');
    } finally {
      _reminderReconcileRunning = false;
    }
  }

  @override
  void dispose() {
    _reminderReconcileDebounce?.cancel();
    for (final subscription in _reminderDataSubscriptions) {
      unawaited(subscription.cancel());
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(civilDateRevisionProvider.notifier).refresh();
      _queueReminderReconciliation(refreshTimezone: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    NotificationService.onNotificationNavigate = (payload) {
      final destination = NotificationService.destinationForPayload(payload);
      if (destination != null) router.go(destination);
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
