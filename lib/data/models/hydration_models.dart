import 'package:flutter/foundation.dart';

@immutable
class HydrationIntakeEntry {
  final String id;
  final String localDate; // YYYY-MM-DD
  final int amountMl;
  final DateTime loggedAtUtc;
  final String source; // 'quickAdd', 'manual', 'reminder', 'summary'
  final String? containerType; // 'glass', 'bottle', 'custom'

  const HydrationIntakeEntry({
    required this.id,
    required this.localDate,
    required this.amountMl,
    required this.loggedAtUtc,
    this.source = 'manual',
    this.containerType,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'localDate': localDate,
    'amountMl': amountMl,
    'loggedAtUtc': loggedAtUtc.toIso8601String(),
    'source': source,
    if (containerType != null) 'containerType': containerType,
  };

  factory HydrationIntakeEntry.fromJson(Map<String, dynamic> json) {
    return HydrationIntakeEntry(
      id: json['id'] as String,
      localDate: json['localDate'] as String,
      amountMl: (json['amountMl'] as num).toInt(),
      loggedAtUtc: DateTime.parse(json['loggedAtUtc'] as String).toUtc(),
      source: json['source'] as String? ?? 'manual',
      containerType: json['containerType'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HydrationIntakeEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          localDate == other.localDate &&
          amountMl == other.amountMl &&
          loggedAtUtc == other.loggedAtUtc &&
          source == other.source &&
          containerType == other.containerType;

  @override
  int get hashCode =>
      Object.hash(id, localDate, amountMl, loggedAtUtc, source, containerType);
}

@immutable
class HydrationDailyReadModel {
  final String localDate;
  final int totalMl;
  final int goalMl;
  final List<HydrationIntakeEntry> entries;

  const HydrationDailyReadModel({
    required this.localDate,
    required this.totalMl,
    required this.goalMl,
    this.entries = const [],
  });

  /// Clamped between 0.0 and 1.0 for progress indicators (e.g. LinearProgressIndicator).
  double get clampedProgressRatio {
    if (goalMl <= 0) return 0.0;
    final ratio = totalMl / goalMl;
    return ratio.clamp(0.0, 1.0);
  }

  /// Raw ratio, unclamped, for percentages and statistics.
  double get rawProgressRatio => goalMl <= 0 ? 0.0 : totalMl / goalMl;

  /// Progress percentage (e.g. 100 for goal met, 120 for surplus).
  int get progressPercent => (rawProgressRatio * 100).round();

  bool get isGoalMet => totalMl >= goalMl && goalMl > 0;

  int get remainingMl => (goalMl - totalMl).clamp(0, goalMl);

  /// Volume in fluid ounces (US fluid ounces: 1 fl oz ≈ 29.5735 ml)
  double get totalFlOz => totalMl / 29.5735;
  double get goalFlOz => goalMl / 29.5735;

  /// Number of standard glasses equivalent
  double glassesCount([int glassSizeMl = 250]) =>
      glassSizeMl <= 0 ? 0.0 : totalMl / glassSizeMl;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HydrationDailyReadModel &&
          runtimeType == other.runtimeType &&
          localDate == other.localDate &&
          totalMl == other.totalMl &&
          goalMl == other.goalMl &&
          listEquals(entries, other.entries);

  @override
  int get hashCode =>
      Object.hash(localDate, totalMl, goalMl, Object.hashAll(entries));
}
