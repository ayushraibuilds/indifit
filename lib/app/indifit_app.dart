import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/providers.dart';
import '../core/di/theme_provider.dart';
import '../core/router/app_router.dart';
import '../core/services/auto_backup_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/rest_presence_service.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/app_logger.dart';
import '../data/database/app_database.dart';
import '../features/workout_player/b02_strength_execution_controller.dart';

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
      unawaited(
        ref
            .read(b02StrengthExecutionControllerProvider.notifier)
            .reconcilePendingRestIntent(),
      );
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
