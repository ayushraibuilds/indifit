import 'dart:convert';
import 'package:drift/drift.dart';

import '../../core/algorithms/adaptive_tdee_engine.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../../core/utils/tdee_calculator.dart';
import '../database/app_database.dart';
import '../models/adaptive_tdee_models.dart';
import 'nutrition_read_model_repository.dart';

/// Read-only repository for evaluating on-device Adaptive TDEE.
///
/// Strictly adheres to:
/// 1. Single target authority (computes read-only estimates, never writes to NutritionGoalVersions).
/// 2. Precedence rule: canonical nutrition snapshot energy takes precedence over foodLogs for any
///    civil day; they are never summed together (eliminating double-counting).
/// 3. Civil date and timezone safety via [LocalScheduleDateService]; no internal calls to DateTime.now().
/// 4. Multi-weigh-in median resolution on the same calendar day.
/// 5. Bounded historical lookback (capped to policy.maxHistoryDays).
class AdaptiveTdeeRepository {
  final AppDatabase _database;
  final LocalScheduleDateService _dates;
  final NutritionReadModelRepository? _nutrition;
  final AdaptiveTdeeEngine _engine;

  AdaptiveTdeeRepository(
    this._database, {
    LocalScheduleDateService? dates,
    NutritionReadModelRepository? nutrition,
    AdaptiveTdeeEngine engine = const AdaptiveTdeeEngine(),
  })  : _dates = dates ?? LocalScheduleDateService(),
        _nutrition = nutrition,
        _engine = engine;

  /// Evaluates current adaptive TDEE estimate as of [nowUtc] in [timezoneId].
  Future<AdaptiveTdeeEstimate> evaluate({
    required DateTime nowUtc,
    required String timezoneId,
    AdaptiveTdeePolicy policy = AdaptiveTdeePolicy.v1,
    String? userId,
  }) async {
    final now = nowUtc.toUtc();
    final todayLocalDate = _dates.localDateFor(now, timezoneId);

    // 1. Read User Profile Baseline & Identity
    final profileBaseline = await _readProfileBaseline(userId: userId);
    final effectiveUserId = profileBaseline.userId;

    // 2. Read Scale Weights & Compute Daily Medians
    final dailyWeights = await _readDailyWeights(now, timezoneId);

    // 3. Read Daily Caloric Intakes with Precedence
    final dailyIntakes = await _readDailyIntakes(
      now,
      timezoneId,
      userId: effectiveUserId,
    );

    // 4. Determine Timeline Boundaries
    final allDates = <String>{...dailyWeights.keys, ...dailyIntakes.keys};
    if (allDates.isEmpty) {
      return _engine.calculate(
        policy: policy,
        baselineBmr: profileBaseline.bmr,
        baselineTdeeKcal: profileBaseline.tdee,
        days: const [],
        evaluationLocalDate: todayLocalDate,
        timezoneId: timezoneId,
      );
    }

    final sortedDates = allDates.toList()..sort();
    String startDate = sortedDates.first;

    // Bound lookback to maxHistoryDays
    final minAllowedDate = _dates.addCalendarDays(
      todayLocalDate,
      timezoneId,
      -policy.maxHistoryDays,
    );
    if (_dates.compare(startDate, minAllowedDate) < 0) {
      startDate = minAllowedDate;
    }

    // 5. Build Continuous Day Sequence from startDate to todayLocalDate
    final dayInputs = <AdaptiveTdeeDayInput>[];
    String cursor = startDate;

    while (_dates.compare(cursor, todayLocalDate) <= 0) {
      final weight = dailyWeights[cursor];
      final intake = dailyIntakes[cursor];

      dayInputs.add(
        AdaptiveTdeeDayInput(
          localDate: cursor,
          scaleWeightKg: weight,
          caloriesConsumed: intake?.calories,
          intakeSource: intake?.source ?? AdaptiveTdeeIntakeSource.none,
        ),
      );

      cursor = _dates.addCalendarDays(cursor, timezoneId, 1);
    }

    return _engine.calculate(
      policy: policy,
      baselineBmr: profileBaseline.bmr,
      baselineTdeeKcal: profileBaseline.tdee,
      days: dayInputs,
      evaluationLocalDate: todayLocalDate,
      timezoneId: timezoneId,
    );
  }

  Future<({String userId, double bmr, double tdee})> _readProfileBaseline({
    String? userId,
  }) async {
    final profiles = await _database.select(_database.userProfiles).get();
    if (profiles.isEmpty) {
      // Fallback defaults: 70kg, 170cm, 25yo male, moderate activity
      const bmr = 1655.0;
      const tdee = 1655.0 * 1.55;
      return (
        userId: userId ?? kLocalNutritionUserScopeId,
        bmr: bmr,
        tdee: tdee,
      );
    }

    final p = profiles.first;
    final resolvedUserId = userId ??
        (p.id > 0 ? p.id.toString() : kLocalNutritionUserScopeId);
    final age = p.age;
    final height = p.height;
    final weight = p.weight;
    final isFemale = p.sex.toLowerCase() == 'female';
    final gender = isFemale ? Gender.female : Gender.male;
    final multiplier = _parseActivityMultiplier(p.activityLevel);

    if (age <= 0 || height <= 0 || weight <= 0) {
      final fallbackTdee = p.calorieGoal > 0 ? p.calorieGoal.toDouble() : 2000.0;
      return (userId: resolvedUserId, bmr: 0.0, tdee: fallbackTdee);
    }

    final bmr = TdeeCalculator.calculateBmr(
      weightKg: weight,
      heightCm: height,
      ageYears: age,
      gender: gender,
    );
    final tdee = bmr * multiplier;
    return (userId: resolvedUserId, bmr: bmr, tdee: tdee);
  }

  double _parseActivityMultiplier(String? level) {
    final raw = level?.trim().toLowerCase();
    switch (raw) {
      case 'sedentary':
        return 1.2;
      case 'light':
      case 'lightly_active':
        return 1.375;
      case 'moderate':
      case 'moderately_active':
        return 1.55;
      case 'very_active':
      case 'heavy':
        return 1.725;
      case 'extra_active':
      case 'athlete':
        return 1.9;
      default:
        return 1.55; // moderate default fallback
    }
  }

  Future<Map<String, double>> _readDailyWeights(
    DateTime nowUtc,
    String timezoneId,
  ) async {
    final rows = await (_database.select(_database.bodyMeasurements)
          ..where((tbl) => tbl.recordedAt.isSmallerOrEqualValue(nowUtc))
          ..where((tbl) => tbl.weight.isNotNull()))
        .get();

    final weightsByDay = <String, List<double>>{};
    for (final row in rows) {
      final weight = row.weight;
      if (weight == null || weight <= 0) continue;
      final localDate = _dates.localDateFor(row.recordedAt.toUtc(), timezoneId);
      weightsByDay.putIfAbsent(localDate, () => []).add(weight);
    }

    final dailyMedians = <String, double>{};
    for (final entry in weightsByDay.entries) {
      dailyMedians[entry.key] = _median(entry.value);
    }
    return dailyMedians;
  }

  Future<Map<String, ({double calories, AdaptiveTdeeIntakeSource source})>>
      _readDailyIntakes(
    DateTime nowUtc,
    String timezoneId, {
    required String userId,
  }) async {
    final intakes = <String, ({double calories, AdaptiveTdeeIntakeSource source})>{};

    // 0. Use NutritionReadModelRepository if provided
    if (_nutrition != null) {
      try {
        var records = await _nutrition.listHistory(
          userId: userId,
          toUtc: nowUtc,
        );
        if (records.isEmpty && userId != kLocalNutritionUserScopeId) {
          records = await _nutrition.listHistory(
            userId: kLocalNutritionUserScopeId,
            toUtc: nowUtc,
          );
        }
        for (final r in records) {
          final localDate = r.localDate;
          final energyFacts = r.items
              .expand((item) => item.facts.values)
              .where((fact) => fact.nutrientId == 'energy' || fact.nutrientId == 'energy_kilocalorie');
          double totalKcal = 0.0;
          for (final fact in energyFacts) {
            final amt = fact.point?.value.asDouble ?? (fact.lower?.value.asDouble ?? 0.0);
            totalKcal += amt;
          }
          if (totalKcal > 0) {
            intakes.update(
              localDate,
              (existing) => (calories: existing.calories + totalKcal, source: AdaptiveTdeeIntakeSource.snapshot),
              ifAbsent: () => (calories: totalKcal, source: AdaptiveTdeeIntakeSource.snapshot),
            );
          }
        }
        if (intakes.isNotEmpty) return intakes;
      } catch (_) {
        // Fall back to direct SQL queries below
      }
    }

    // 1. Check Canonical Nutrition Snapshots via direct SQL
    final snapshots = await (_database.select(_database.nutritionConsumptionSnapshots)
          ..where((tbl) => tbl.loggedAt.isSmallerOrEqualValue(nowUtc)))
        .get();

    // Identify superseded snapshots
    final supersededIds = <String>{};
    for (final s in snapshots) {
      final raw = s.lineage;
      if (raw == null || raw.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map && decoded['supersedes_snapshot_id'] is String) {
          supersededIds.add((decoded['supersedes_snapshot_id'] as String).trim());
        }
      } catch (_) {}
    }

    final activeSnapshots = snapshots.where((s) {
      if (supersededIds.contains(s.id)) return false;
      if (s.sourceType.trim().toLowerCase() == 'retraction') return false;
      return true;
    }).toList();

    if (activeSnapshots.isNotEmpty) {
      final snapshotIds = activeSnapshots.map((s) => s.id).toSet();
      final nutrientRows = await (_database.select(_database.nutritionSnapshotNutrients)
            ..where((tbl) => tbl.snapshotId.isIn(snapshotIds)))
          .get();

      final energyBySnapshotId = <String, double>{};
      for (final n in nutrientRows) {
        final id = n.nutrientId.toLowerCase();
        if (id == 'energy' || id == 'energy_kilocalorie') {
          final status = n.status.toLowerCase();
          if (status == 'known' || status == 'known_zero' || status == 'estimated') {
            final amt = n.amount ?? 0.0;
            energyBySnapshotId[n.snapshotId] =
                (energyBySnapshotId[n.snapshotId] ?? 0.0) + amt;
          }
        }
      }

      for (final s in activeSnapshots) {
        final localDate = s.localDate != null && s.localDate!.trim().isNotEmpty
            ? _dates.normalizeLocalDate(s.localDate!)
            : _dates.localDateFor(s.loggedAt.toUtc(), timezoneId);
        final kcal = energyBySnapshotId[s.id] ?? 0.0;
        if (kcal > 0) {
          intakes.update(
            localDate,
            (existing) => (calories: existing.calories + kcal, source: AdaptiveTdeeIntakeSource.snapshot),
            ifAbsent: () => (calories: kcal, source: AdaptiveTdeeIntakeSource.snapshot),
          );
        }
      }
    }

    // 2. Query Food Logs for days that do NOT have active snapshot energy
    final foodLogs = await (_database.select(_database.foodLogs)
          ..where((tbl) => tbl.loggedAt.isSmallerOrEqualValue(nowUtc)))
        .get();

    final foodLogsByDay = <String, double>{};
    for (final log in foodLogs) {
      if (log.calories <= 0) continue;
      final localDate = _dates.localDateFor(log.loggedAt.toUtc(), timezoneId);
      foodLogsByDay[localDate] = (foodLogsByDay[localDate] ?? 0.0) + log.calories;
    }

    // Apply strict precedence: snapshot > foodLog. Never sum both for the same civil day.
    for (final entry in foodLogsByDay.entries) {
      if (!intakes.containsKey(entry.key) && entry.value > 0) {
        intakes[entry.key] = (
          calories: entry.value,
          source: AdaptiveTdeeIntakeSource.foodLog,
        );
      }
    }

    return intakes;
  }

  double _median(List<double> values) {
    if (values.isEmpty) return 0.0;
    final sorted = List<double>.from(values)..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[middle];
    }
    return (sorted[middle - 1] + sorted[middle]) / 2.0;
  }
}
