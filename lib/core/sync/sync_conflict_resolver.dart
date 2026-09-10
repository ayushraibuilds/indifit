/// Deterministic conflict resolution engine for multi-device record synchronization.
library;

import '../capabilities/sync_capability.dart';
import 'sync_mutation.dart';

/// The result of reconciling a local mutation against an incoming remote mutation.
class SyncConflictResult {
  const SyncConflictResult({
    required this.winner,
    required this.wasLocalOverwritten,
    required this.isTombstoneDominant,
  });

  /// The winning mutation that must be stored in local SQLite.
  final SyncMutation winner;

  /// Whether the local mutation was superseded by the incoming remote mutation.
  final bool wasLocalOverwritten;

  /// Whether a tombstone (deletion) extinguished an earlier or concurrent write.
  final bool isTombstoneDominant;
}

/// Pure deterministic conflict reconciliation engine.
class SyncConflictResolver {
  const SyncConflictResolver();

  /// Synced tables inventory (audited 20 tables in AppDatabase).
  /// Any table not in this set is strictly local-only or cache.
  static const Set<String> syncedTables = {
    'workout_sessions',
    'workout_sets',
    'exercises',
    'food_logs',
    'food_items',
    'body_measurements',
    'workout_routines',
    'routine_days',
    'routine_exercises',
    'meal_templates',
    'meal_template_items',
    'nutrition_recipes',
    'nutrition_recipe_versions',
    'nutrition_recipe_ingredients',
    'nutrition_goal_versions',
    'equipment_profiles',
    'equipment_profile_items',
    'user_profiles',
    'user_settings',
    'achievement_unlocks',
  };

  /// Strictly excluded local-only and cache tables.
  static const Set<String> localOnlyTables = {
    'outbox_operations',
    'notification_schedules',
    'remote_catalog_cache',
    'barcode_cache',
    'training_plan_settings',
  };

  /// Explicit syncable preferences allowlist (cross-device user preferences & goals).
  static const Set<String> syncableSettingsAllowlist = {
    'display_units',
    'user_theme_mode',
    'water_goal',
    'water_glass_size',
    'pref_hydration_daily_goal_ml',
    'streak_freezes_count',
    'pref_streak_freeze_count',
  };

  /// Strictly excluded device-local settings and state keys.
  static const Set<String> deviceLocalSettingsDenylist = {
    'pref_crash_reporting_enabled',
    'pref_offline_only',
    'offline_only',
    'onboarding_completed',
    'onboarding_skipped',
    'water_logged',
    'water_last_logged_date',
    'auto_sync_health_on_open',
    'health_last_sync_time',
    'user_streak_count',
    'last_streak_date',
    'last_freeze_claimed_at',
    'weekly_action_type',
    'weekly_action_text',
    'weekly_action_target',
    'weekly_action_target_date',
    'indifit_auto_backup_device_secret_v1',
  };

  /// Prefixes that denote device-local notification schedules, cursors, or transient sessions.
  static const List<String> deviceLocalSettingsPrefixes = [
    'pref_remind_',
    'prefRemind',
    'pref_quiet_hours_',
    'prefQuietHours',
    'pref_workout_reminder_',
    'pref_lunch_reminder_',
    'pref_dinner_reminder_',
    'pref_water_reminder_',
    'pref_daily_logging_reminder_',
    'pref_weekly_progress_',
    'workout_reminder_',
    'sync_last_synced_hlc_',
    'sync_last_sync_timestamp_',
    'draft_',
    'session_',
    'handoff_',
    'rest_presence_',
    'celebration_',
  ];

  /// Returns whether a given table name is registered for multi-device synchronization.
  static bool isTableSynced(String tableName) => syncedTables.contains(tableName);

  /// Returns whether a setting key is permitted to synchronize cross-device.
  static bool isSettingKeySyncable(String key) {
    if (!syncableSettingsAllowlist.contains(key)) return false;
    if (deviceLocalSettingsDenylist.contains(key)) return false;
    for (final prefix in deviceLocalSettingsPrefixes) {
      if (key.startsWith(prefix)) return false;
    }
    return true;
  }

  /// Identifies bundled offline starter plans by deterministic ID prefix.
  static bool isCatalogProgramId(String id) => id.startsWith('offline-starter::');

  /// Returns whether the domain represents immutable append-only evidence (workouts, weights).
  static bool isAppendOnlyEvidence(SyncDomain domain) {
    return domain == SyncDomain.workouts || domain == SyncDomain.weights;
  }

  /// Reconciles two conflicting mutations for the exact same entity.
  ///
  /// Guarantees:
  /// 1. Strict convergence: reconciling A with B produces the exact same winner
  ///    as reconciling B with A (commutativity).
  /// 2. Anti-resurrection: a tombstone with HLC >= write HLC always extinguishes the write.
  /// 3. Determinism: identical HLC timestamps resolve identically across all devices.
  SyncConflictResult reconcile({
    required SyncMutation local,
    required SyncMutation incoming,
  }) {
    if (local.entityId != incoming.entityId) {
      throw ArgumentError(
        'Cannot reconcile mutations with different entity IDs: "${local.entityId}" vs "${incoming.entityId}"',
      );
    }
    if (local.domain != incoming.domain) {
      throw ArgumentError(
        'Cannot reconcile mutations with different domains: "${local.domain.name}" vs "${incoming.domain.name}"',
      );
    }

    // Rule 1: Tombstone Dominance (Anti-Resurrection)
    final localIsDelete = local.isDeleted;
    final incomingIsDelete = incoming.isDeleted;

    if (localIsDelete != incomingIsDelete) {
      final tombstone = localIsDelete ? local : incoming;
      final write = localIsDelete ? incoming : local;

      // If the tombstone is newer or equal to the write, tombstone dominates
      if (tombstone.hlc >= write.hlc) {
        return SyncConflictResult(
          winner: tombstone,
          wasLocalOverwritten: incomingIsDelete,
          isTombstoneDominant: true,
        );
      } else {
        // The write was explicitly created after the deletion
        return SyncConflictResult(
          winner: write,
          wasLocalOverwritten: incoming == write,
          isTombstoneDominant: false,
        );
      }
    }

    // Rule 2: Last-Write-Wins (LWW) ordered strictly by HLC.
    // Commutativity: reconcile(A,B) must equal reconcile(B,A). HLC compareTo
    // already tie-breaks on nodeId, so comparison==0 means identical HLC
    // (same millis+counter+node). In that impossible-but-possible case, break
    // the tie deterministically on payload content (order-independent max)
    // instead of "local wins", which diverges per device.
    final comparison = incoming.hlc.compareTo(local.hlc);

    if (comparison > 0) {
      // Incoming is strictly newer
      return SyncConflictResult(
        winner: incoming,
        wasLocalOverwritten: true,
        isTombstoneDominant: false,
      );
    } else if (comparison < 0) {
      return SyncConflictResult(
        winner: local,
        wasLocalOverwritten: false,
        isTombstoneDominant: false,
      );
    } else {
      final incomingKey = incoming.payload.toString();
      final localKey = local.payload.toString();
      final incomingWins = incomingKey.compareTo(localKey) >= 0;
      return SyncConflictResult(
        winner: incomingWins ? incoming : local,
        wasLocalOverwritten: incomingWins,
        isTombstoneDominant: false,
      );
    }
  }
}
