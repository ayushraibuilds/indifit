import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nutrition_household_measures.dart';
import '../../core/utils/app_logger.dart';
import '../../core/widgets/indifit_month_sheet.dart';
import '../../data/repositories/workout_repository.dart';
import '../nutrition/nutrition_providers.dart';
import '../vrat/vrat_day_sheet.dart';
import '../vrat/vrat_days.dart';

/// The month sheet's dots (U-9): days with food logged and workouts saved,
/// read from the diary and the workout history. A read that fails leaves
/// its dots out rather than blocking the picker.
IndiFitMonthMarksLoader diaryMonthMarks(ProviderContainer container) {
  final consumption = container.read(
    nutritionConsumptionRepositoryProvider.future,
  );
  final workouts = container.read(workoutRepositoryProvider);
  return (monthStart) async {
    final vrat = container.read(vratDaysProvider);
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0);
    var foodDays = <DateTime>{};
    var workoutDays = <DateTime>{};
    try {
      final dates = await (await consumption).activeLocalDates(
        userId: kLocalNutritionUserScopeId,
        fromLocalDate: _isoDate(monthStart),
        toLocalDate: _isoDate(monthEnd),
      );
      foodDays = {for (final date in dates) DateTime.parse(date)};
    } on Object catch (error) {
      AppLogger.warning('Month food dots skipped: $error', 'MonthSheet');
    }
    try {
      for (final completed in await workouts.getAllSessionDates()) {
        final local = completed.toLocal();
        final day = DateTime(local.year, local.month, local.day);
        if (!day.isBefore(monthStart) && !day.isAfter(monthEnd)) {
          workoutDays.add(day);
        }
      }
    } on Object catch (error) {
      AppLogger.warning('Month workout dots skipped: $error', 'MonthSheet');
    }
    final monthPrefix = _isoDate(monthStart).substring(0, 8);
    return IndiFitMonthMarks(
      foodDays: foodDays,
      workoutDays: workoutDays,
      vratDays: {
        for (final date in vrat)
          if (date.startsWith(monthPrefix)) DateTime.parse(date),
      },
    );
  };
}

/// [showIndiFitMonthSheet] with the diary's dots; without a ProviderScope
/// above [context] the sheet opens without them.
Future<DateTime?> pickDiaryDay(
  BuildContext context, {
  required DateTime initialDay,
  DateTime? firstDay,
  DateTime? lastDay,
  DateTime? today,
  String title = 'Pick a day',
}) {
  IndiFitMonthMarksLoader? marks;
  try {
    marks = diaryMonthMarks(ProviderScope.containerOf(context, listen: false));
  } on StateError {
    marks = null;
  }
  return showIndiFitMonthSheet(
    context,
    initialDay: initialDay,
    firstDay: firstDay,
    lastDay: lastDay,
    today: today,
    marks: marks,
    title: title,
    // Without a ProviderScope there is nowhere to keep vrat days.
    onLongPressDay: marks == null
        ? null
        : (sheetContext, day) => showVratDaySheet(sheetContext, day: day),
  );
}

String _isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
