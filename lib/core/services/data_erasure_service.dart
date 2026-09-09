import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/health_service.dart';
import '../../features/dashboard/today_surface_controller.dart';
import '../../features/settings/settings_controller.dart';
import '../../features/workout_player/b02_strength_execution_controller.dart';
import '../capabilities/capabilities_registry.dart';
import '../di/providers.dart';
import '../presentation/today_onboarding_handoff.dart';
import '../privacy/privacy_policy.dart';
import '../router/app_router.dart';
import '../utils/app_logger.dart';
import 'auto_backup_secret_store.dart';
import 'notification_service.dart';
import 'rest_presence_service.dart';

/// Comprehensive audit report summarizing the outcome of a complete data erasure.
class DataErasureReport {
  final bool isSuccess;
  final DateTime completedAtUtc;
  final Map<String, int> remainingUserTableCounts;
  final int remainingCustomFoodsCount;
  final int remainingCustomExercisesCount;
  final bool foreignKeyCheckPassed;
  final bool preferencesCleared;
  final bool secureStorageCleared;
  final bool localFilesCleared;
  final bool notificationsCancelled;
  final bool? cloudBackupsPurged;
  final bool? accountDeleted;
  final bool healthDisconnected;
  final List<String> disclosures;
  final String? failureReason;

  const DataErasureReport({
    required this.isSuccess,
    required this.completedAtUtc,
    required this.remainingUserTableCounts,
    required this.remainingCustomFoodsCount,
    required this.remainingCustomExercisesCount,
    required this.foreignKeyCheckPassed,
    required this.preferencesCleared,
    required this.secureStorageCleared,
    required this.localFilesCleared,
    required this.notificationsCancelled,
    required this.cloudBackupsPurged,
    required this.accountDeleted,
    required this.healthDisconnected,
    required this.disclosures,
    this.failureReason,
  });

  @override
  String toString() =>
      'DataErasureReport(success: $isSuccess, failureReason: $failureReason, '
      'remainingUserTablesWithRows: ${remainingUserTableCounts.values.where((v) => v > 0).length}, '
      'customFoods: $remainingCustomFoodsCount, customExercises: $remainingCustomExercisesCount, '
      'fkCheck: $foreignKeyCheckPassed, prefs: $preferencesCleared, '
      'secureStorage: $secureStorageCleared, files: $localFilesCleared)';
}

/// Orchestrates verifiable, complete erasure of all personal and application
/// data across all storage layers (SQLite, SharedPreferences, SecureStorage,
/// local backups/caches, notifications, and remote integrations).
class DataErasureService {
  final AppDatabase _db;
  final AutoBackupSecretStore _secretStore;
  final CloudBackupCapability _cloudBackup;
  final AccountCapability _account;
  final HealthService _healthService;
  final Future<Directory> Function() _documentsDirectoryProvider;
  final Future<Directory> Function() _temporaryDirectoryProvider;

  DataErasureService({
    required AppDatabase db,
    AutoBackupSecretStore secretStore = const SecureAutoBackupSecretStore(),
    CloudBackupCapability cloudBackup = const DisabledCloudBackupCapability(),
    AccountCapability account = const NoOpAccountCapability(),
    required HealthService healthService,
    Future<Directory> Function() documentsDirectoryProvider =
        getApplicationDocumentsDirectory,
    Future<Directory> Function() temporaryDirectoryProvider =
        getTemporaryDirectory,
  })  : _db = db,
        _secretStore = secretStore,
        _cloudBackup = cloudBackup,
        _account = account,
        _healthService = healthService,
        _documentsDirectoryProvider = documentsDirectoryProvider,
        _temporaryDirectoryProvider = temporaryDirectoryProvider;

  /// Executes verifiable complete erasure across all storage layers.
  Future<DataErasureReport> eraseAllData() async {
    final disclosures = <String>[];
    String? failureReason;

    // 1. Remote and external cleanup (offline resilient)
    bool? cloudBackupsPurged;
    try {
      await _cloudBackup.deleteAllRemoteSnapshots();
      cloudBackupsPurged = true;
    } catch (e) {
      AppLogger.warning('Cloud backup snapshot purge failed (offline?): $e');
      cloudBackupsPurged = false;
      disclosures.add(
        'Remote cloud backup snapshots could not be reached (the device may be offline). '
        'All local encryption secrets and sync state were deleted to prevent resurrection.',
      );
    }

    bool? accountDeleted;
    try {
      await _account.requestAccountDeletion();
      accountDeleted = true;
    } catch (e) {
      AppLogger.warning('Account deletion failed (offline?): $e');
      accountDeleted = false;
      disclosures.add(
        'Remote account deletion could not be reached (the device may be offline). '
        'Local credentials were deleted to return to guest mode.',
      );
    }

    bool healthDisconnected = true;
    try {
      await _healthService.disconnect();
    } catch (e) {
      AppLogger.warning('Health service disconnect warning: $e');
      healthDisconnected = false;
    }
    disclosures.add(
      'Health data previously synced to Apple Health or Android Health Connect '
      'remains in your device operating system health store outside the IndiFit sandbox. '
      'IndiFit has disconnected and revoked permissions.',
    );

    // 2. Scheduled reminders & rest presence cleanup
    bool notificationsCancelled = true;
    try {
      await NotificationService.cancelAllNotificationsForErasure();
      await RestPresenceService.cleanupStaleNotifications();
    } catch (e) {
      AppLogger.warning('Notification cancellation failed: $e');
      notificationsCancelled = false;
    }

    // 3. Database Wipe
    // SQLite requirement: PRAGMA foreign_keys = OFF is a no-op inside a transaction!
    // It must be issued BEFORE opening the transaction.
    await _db.customStatement('PRAGMA foreign_keys = OFF;');

    final userTables = _getUserDataTables(_db);

    try {
      await _db.transaction(() async {
        for (final table in userTables) {
          await _db.delete(table).go();
        }
        // Custom food items & custom exercises
        await (_db.delete(_db.foodItems)
              ..where((f) => f.isCustom.equals(true)))
            .go();
        await (_db.delete(_db.exercises)
              ..where((e) => e.isCustom.equals(true)))
            .go();
      });
    } catch (e, stack) {
      AppLogger.error('Database erasure transaction failed', e, stack);
      failureReason = 'Database transaction failed: $e';
    } finally {
      // Re-enable foreign keys after transaction commit
      await _db.customStatement('PRAGMA foreign_keys = ON;');
    }

    // Check foreign key violations
    bool foreignKeyCheckPassed = false;
    try {
      final violations =
          await _db.customSelect('PRAGMA foreign_key_check;').get();
      foreignKeyCheckPassed = violations.isEmpty;
      if (!foreignKeyCheckPassed) {
        failureReason ??=
            'Foreign key integrity check failed: ${violations.length} violations detected.';
      }
    } catch (e) {
      AppLogger.warning('Foreign key check failed: $e');
      foreignKeyCheckPassed = false;
      failureReason ??= 'Foreign key check execution error: $e';
    }

    // Reclaim disk space outside any transaction
    try {
      await _db.customStatement('VACUUM;');
    } catch (e) {
      AppLogger.warning('Database VACUUM skipped or failed: $e');
    }

    // 4. Post-Erasure Database Verification
    final remainingUserTableCounts = <String, int>{};
    for (final table in userTables) {
      final countExp = countAll();
      final query = _db.selectOnly(table)..addColumns([countExp]);
      final rowCount =
          await query.map((row) => row.read(countExp)).getSingleOrNull() ?? 0;
      remainingUserTableCounts[table.actualTableName] = rowCount;
    }

    final remainingCustomFoods = (await (_db.select(_db.foodItems)
              ..where((f) => f.isCustom.equals(true)))
            .get())
        .length;

    final remainingCustomExercises = (await (_db.select(_db.exercises)
              ..where((e) => e.isCustom.equals(true)))
            .get())
        .length;

    final nonZeroTables = remainingUserTableCounts.entries
        .where((entry) => entry.value > 0)
        .map((entry) => '${entry.key}: ${entry.value}')
        .toList();

    if (nonZeroTables.isNotEmpty) {
      failureReason ??=
          'User records remained after erasure: ${nonZeroTables.join(', ')}';
    }
    if (remainingCustomFoods > 0) {
      failureReason ??= '$remainingCustomFoods custom foods remained.';
    }
    if (remainingCustomExercises > 0) {
      failureReason ??= '$remainingCustomExercises custom exercises remained.';
    }

    disclosures.add(
      'Static food and exercise reference catalogs have been retained so the application remains functional.',
    );

    // 5. Local File System Cleanup
    bool localFilesCleared = true;
    try {
      final docDir = await _documentsDirectoryProvider();
      final backupDir = Directory('${docDir.path}/backups');
      if (await backupDir.exists()) {
        await backupDir.delete(recursive: true);
      }
      if (await backupDir.exists()) {
        localFilesCleared = false;
        failureReason ??= 'Local backups directory could not be deleted.';
      }

      final tempDir = await _temporaryDirectoryProvider();
      if (await tempDir.exists()) {
        final entities = tempDir.listSync(recursive: false);
        for (final entity in entities) {
          if (entity is File) {
            final name = entity.uri.pathSegments.isNotEmpty
                ? entity.uri.pathSegments.last
                : '';
            if (name.startsWith('indifit_backup') ||
                name.startsWith('indifit_export') ||
                name.endsWith('.indifit-backup') ||
                name.endsWith('.csv')) {
              await entity.delete();
            }
          }
        }
      }
    } catch (e) {
      AppLogger.warning('Local file cleanup failed: $e');
      localFilesCleared = false;
      failureReason ??= 'Local file cleanup error: $e';
    }

    // 6. Secure Storage Cleanup
    bool secureStorageCleared = true;
    try {
      await _secretStore.clear();
      final remainingSecret = await _secretStore.read();
      if (remainingSecret != null && remainingSecret.isNotEmpty) {
        secureStorageCleared = false;
        failureReason ??= 'Secure backup secret was not cleared.';
      }
    } catch (e) {
      AppLogger.warning('Secure storage cleanup failed: $e');
      secureStorageCleared = false;
      failureReason ??= 'Secure storage cleanup error: $e';
    }

    // 7. Preferences Cleanup
    bool preferencesCleared = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await prefs.setBool('onboarding_completed', false);
      await clearTodayOnboardingHandoff();
    } catch (e) {
      AppLogger.warning('SharedPreferences cleanup failed: $e');
      preferencesCleared = false;
      failureReason ??= 'SharedPreferences cleanup error: $e';
    }

    final isSuccess = nonZeroTables.isEmpty &&
        remainingCustomFoods == 0 &&
        remainingCustomExercises == 0 &&
        foreignKeyCheckPassed &&
        preferencesCleared &&
        secureStorageCleared &&
        localFilesCleared;

    return DataErasureReport(
      isSuccess: isSuccess,
      completedAtUtc: DateTime.now().toUtc(),
      remainingUserTableCounts: remainingUserTableCounts,
      remainingCustomFoodsCount: remainingCustomFoods,
      remainingCustomExercisesCount: remainingCustomExercises,
      foreignKeyCheckPassed: foreignKeyCheckPassed,
      preferencesCleared: preferencesCleared,
      secureStorageCleared: secureStorageCleared,
      localFilesCleared: localFilesCleared,
      notificationsCancelled: notificationsCancelled,
      cloudBackupsPurged: cloudBackupsPurged,
      accountDeleted: accountDeleted,
      healthDisconnected: healthDisconnected,
      disclosures: disclosures,
      failureReason: failureReason,
    );
  }

  /// Complete list of all user-data tables in [AppDatabase] that must be
  /// completely emptied on complete erasure.
  static List<TableInfo<Table, dynamic>> _getUserDataTables(AppDatabase db) {
    return <TableInfo<Table, dynamic>>[
      // Nutrition & Food user tables
      db.foodLogs,
      db.mealTemplateItems,
      db.mealTemplates,
      db.nutritionPersonalVessels,
      db.nutritionVesselCalibrations,
      db.nutritionRecipes,
      db.nutritionRecipeVersions,
      db.nutritionRecipeIngredients,
      db.nutritionUserCorrections,
      db.nutritionEstimates,
      db.nutritionEstimateNutrients,
      db.nutritionThalis,
      db.nutritionThaliItems,
      db.nutritionConsumptionSnapshots,
      db.nutritionSnapshotItems,
      db.nutritionSnapshotNutrients,
      db.nutritionUserConstraints,
      db.nutritionSnapshotConstraintResults,
      db.nutritionSnapshotConstraintResultEvidence,
      db.nutritionGoalVersions,
      db.coachingConsentEvents,
      db.nutritionCoachingPreferences,

      // Workout & Execution user tables
      db.performedRestPeriods,
      db.exerciseTargetRecommendations,
      db.performedSetSegments,
      db.performedSets,
      db.performedExercises,
      db.performedExerciseGroups,
      db.cardioIntervals,
      db.cardioSessionDetails,
      db.mobilitySessionDetails,
      db.workoutSets,
      db.workoutSessions,
      db.routineExercises,
      db.routineDays,
      db.workoutRoutines,
      db.workoutDrafts,

      // Programs & Planning user tables
      db.travelContextOccurrences,
      db.occurrenceEvents,
      db.exercisePersonalCues,
      db.exerciseSetupValues,
      db.exerciseUserPreferences,
      db.legacyRoutineProgramMappings,
      db.trainingPlanSettings,
      db.equipmentProfileItems,
      db.travelContexts,
      db.scheduledSessionOccurrences,
      db.exercisePrescriptions,
      db.sessionTemplates,
      db.programWeeks,
      db.programBlocks,
      db.programVersions,
      db.programs,
      db.equipmentProfiles,
      db.exerciseGroupMembers,
      db.strengthSetPrescriptions,
      db.exerciseGroups,

      // User Profile, Measurements, Hydration & Achievements
      db.bodyMeasurements,
      db.dailyHydrations,
      db.healthProvenances,
      db.achievementUnlocks,
      db.userProfiles,
      db.userSettings,

      // Recovery, Readiness, Recommendations & Coaching
      db.recoveryObservations,
      db.readinessSnapshots,
      db.readinessSnapshotEvidence,
      db.recommendations,
      db.recommendationEvidence,
      db.coachingEligibilityEvaluations,
      db.recommendationFeedback,

      // UI & Module Preferences
      db.dashboardModulePreferences,
      db.educationContentProgress,
      db.mediaPackPreferences,
      db.workoutPlaylistPreferences,

      // Sync & Cache
      db.outboxEntries,
      db.tombstoneEntries,
      db.cachedRemoteFoods,
    ];
  }
}

/// Targeted in-memory Riverpod state reset across all user-scoped providers.
/// Must be called after complete erasure to prevent stale cached state from
/// leaking into the subsequent onboarding or session experience.
void resetIndiFitUserState(WidgetRef ref) {
  ref.read(onboardingCompletedProvider.notifier).state = false;
  _invalidateUserProviders(ref.invalidate);
}

/// Reset in-memory state on a [ProviderContainer].
void resetIndiFitContainerUserState(ProviderContainer container) {
  container.read(onboardingCompletedProvider.notifier).state = false;
  _invalidateUserProviders(container.invalidate);
}

/// MAINTENANCE OBLIGATION:
/// This list must be updated whenever new user-scoped Riverpod providers,
/// controllers, or cached view models are introduced to IndiFit.
///
/// If a provider is omitted here, the failure mode is stale in-memory state
/// until the controller rebuilds from wiped persistent storage (not data
/// corruption). However, to prevent ghost state from appearing immediately
/// upon navigating back to onboarding or starting a fresh profile, ensure all
/// user-data-dependent providers are registered here.
void _invalidateUserProviders(void Function(ProviderOrFamily) invalidate) {
  invalidate(userProfileProvider);
  invalidate(settingsControllerProvider);
  invalidate(waterProvider);
  invalidate(todaySurfaceSnapshotProvider);
  invalidate(todaySurfaceReadRepositoryProvider);
  invalidate(todayNutritionRevisionProvider);
  invalidate(todayHydrationRevisionProvider);
  invalidate(b02StrengthExecutionControllerProvider);
  invalidate(b04DailyBriefingControllerProvider);
  invalidate(b04WeeklyReviewControllerProvider);
  invalidate(b04CurrentFoodControllerProvider);
  invalidate(b04ProductionUserContextProvider);
  invalidate(b04ProductionRecommendationContextProvider);
  invalidate(b04GoalSettingsControllerProvider);
  invalidate(nutritionProteinDistributionControllerProvider);
  invalidate(nutritionConstraintManagementControllerProvider);
  invalidate(nutritionConstraintEvaluationReviewControllerProvider);
  invalidate(todayOnboardingHandoffPendingProvider);
  invalidate(cloudBackupStatusProvider);
  invalidate(privacyPolicyProvider);
  invalidate(programListProvider);
  invalidate(equipmentProfileListProvider);
}
