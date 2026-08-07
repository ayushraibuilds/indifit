import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/food_repository.dart';
import 'food_contextual_actions.dart';

DateTime _civilDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Read-only provider boundary for the legacy B03 food-log read. The panel
/// consumes this typed snapshot; it never queries Drift from a widget. A
/// one-shot read avoids retaining a database stream while an action is being
/// reconciled; mutations explicitly invalidate the provider below.
final foodLogsForDayProvider = FutureProvider.autoDispose
    .family<List<FoodLog>, DateTime>((ref, date) {
      return ref
          .watch(foodRepositoryProvider)
          .watchLogsForDay(_civilDay(date))
          .first;
    });

/// A compact production food-log surface used by the existing food-search/log
/// flow. It keeps mutation and undo behavior inside [FoodContextualActions].
class FoodLogEntriesPanel extends ConsumerWidget {
  const FoodLogEntriesPanel({required this.date, super.key});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(foodLogsForDayProvider(_civilDay(date)));
    return B05Surface(
      padding: const EdgeInsets.all(B05Layout.space12),
      radius: B05SurfaceRadius.small,
      child: logs.when(
        loading: () => const B05StatusMessage(
          status: B05SemanticStatus.info,
          label: 'Loading logged food',
        ),
        error: (error, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            B05StatusMessage(
              status: B05SemanticStatus.unavailable,
              label: 'Logged food is unavailable',
              value: error.toString(),
            ),
            const SizedBox(height: B05Layout.space8),
            B05ActionButton(
              label: 'Retry logged food',
              icon: Icons.refresh_rounded,
              emphasis: B05ActionEmphasis.secondary,
              onPressed: () =>
                  ref.invalidate(foodLogsForDayProvider(_civilDay(date))),
            ),
          ],
        ),
        data: (items) {
          if (items.isEmpty) {
            return const B05StatusMessage(
              status: B05SemanticStatus.info,
              label: 'No food logged for this day',
              value: 'Use the search below to add a meal.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Logged food', style: B05Typography.title(context)),
              const SizedBox(height: B05Layout.space8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: B05Layout.space8),
                  itemBuilder: (context, index) => FoodContextualActions(
                    log: items[index],
                    onChanged: () =>
                        ref.invalidate(foodLogsForDayProvider(_civilDay(date))),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
