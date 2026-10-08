import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../dashboard/today_surface_controller.dart';

/// The thali someone logs most, so Today can offer it in one tap.
class UsualThali {
  const UsualThali({
    required this.record,
    required this.timesLogged,
    required this.itemLabels,
    required this.signature,
    this.kcal,
  });

  /// The most recent log of this plate; repeating it logs the same thali.
  final NutritionCanonicalSnapshotReadModel record;
  final int timesLogged;
  final List<String> itemLabels;

  /// Identifies the plate by what's on it, so separately built thalis with
  /// the same foods and amounts count as one.
  final String signature;
  final double? kcal;
}

abstract final class UsualThaliFinder {
  /// How far back "usual" looks.
  static const window = Duration(days: 30);

  /// Logged at least this often in [window] before it's called usual.
  static const minimumTimes = 2;

  /// The plate logged most often in [history] (ties go to the most recent),
  /// or null when no plate was logged [minimumTimes] times.
  static UsualThali? find(Iterable<NutritionHistoricalReadRecord> history) {
    final groups = <String, List<NutritionCanonicalSnapshotReadModel>>{};
    for (final record in history) {
      if (record is! NutritionCanonicalSnapshotReadModel) continue;
      final snapshot = record.snapshot;
      if (snapshot.sourceType != 'thali' || snapshot.thaliId == null) continue;
      if (snapshot.items.isEmpty) continue;
      groups.putIfAbsent(signatureOf(record), () => []).add(record);
    }
    MapEntry<String, List<NutritionCanonicalSnapshotReadModel>>? best;
    DateTime latest(List<NutritionCanonicalSnapshotReadModel> logs) => logs
        .map((log) => log.loggedAtUtc)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    for (final group in groups.entries) {
      if (group.value.length < minimumTimes) continue;
      final current = best;
      if (current == null ||
          group.value.length > current.value.length ||
          (group.value.length == current.value.length &&
              latest(group.value).isAfter(latest(current.value)))) {
        best = group;
      }
    }
    final chosen = best;
    if (chosen == null) return null;
    final newest = chosen.value.reduce(
      (a, b) => a.loggedAtUtc.isAfter(b.loggedAtUtc) ? a : b,
    );
    return UsualThali(
      record: newest,
      timesLogged: chosen.value.length,
      signature: chosen.key,
      itemLabels: [
        for (final item in newest.snapshot.items)
          if (item.displayLabel?.trim().isNotEmpty == true)
            item.displayLabel!.trim(),
      ],
      kcal: newest.totals.facts['energy']?.point?.value.asDouble,
    );
  }

  /// "food|amount|unit" per item, sorted.
  static String signatureOf(NutritionCanonicalSnapshotReadModel record) {
    final parts = [
      for (final item in record.snapshot.items)
        '${item.foodId ?? item.displayLabel ?? item.sourceReference}|'
            '${item.quantity.amount}|${item.quantity.unit.name}',
    ]..sort();
    return parts.join(';');
  }
}

/// The usual thali over the last 30 days; null when there isn't one.
final usualThaliProvider = FutureProvider.autoDispose<UsualThali?>((ref) async {
  ref.watch(todayNutritionRevisionProvider);
  final repository = await ref.watch(
    nutritionReadModelRepositoryProvider.future,
  );
  final now = DateTime.now().toUtc();
  final history = await repository.listHistory(
    userId: kLocalNutritionUserScopeId,
    fromUtc: now.subtract(UsualThaliFinder.window),
    toUtc: now,
  );
  return UsualThaliFinder.find(history);
});
