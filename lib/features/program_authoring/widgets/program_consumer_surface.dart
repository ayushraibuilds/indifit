import 'package:flutter/material.dart';

import '../../../core/presentation/consumer_count_label.dart';
import '../../../data/repositories/program_repository.dart';

/// Consumer plan-surface widgets (PV1-ENG-05E first pass).
///
/// Extracted verbatim from `program_author_screen.dart`; builder receivers
/// became explicit constructor params. Unchanged otherwise.

/// A single consumer day row: block/week/template ordinals plus template.
typedef ConsumerDayEntry = ({
  int blockIndex,
  int weekIndex,
  int templateIndex,
  SessionTemplateInput template,
});

String programWeekdayLabel(int weekday) => switch (weekday) {

  DateTime.monday => 'Mon',

  DateTime.tuesday => 'Tue',

  DateTime.wednesday => 'Wed',

  DateTime.thursday => 'Thu',

  DateTime.friday => 'Fri',

  DateTime.saturday => 'Sat',

  DateTime.sunday => 'Sun',

  _ => 'Unknown day',

};



class ProgramConsumerPlanSurface extends StatelessWidget {
  const ProgramConsumerPlanSurface({
    super.key,
    required this.entries,
    required this.canEdit,
    required this.onAddDay,
    required this.onAddPrescription,
  });

  final List<ConsumerDayEntry> entries;
  final bool canEdit;
  final VoidCallback onAddDay;
  final void Function(int blockIndex, int weekIndex, int templateIndex)
      onAddPrescription;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Days',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          ConsumerCountLabel.format(entries.length, 'day'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (canEdit) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAddDay,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add day'),
            ),
          ),
        ],
        if (entries.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Add a day to start building workouts and exercises.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          )
        else
          for (var dayIndex = 0; dayIndex < entries.length; dayIndex++)
            ProgramConsumerDayCard(
              entry: entries[dayIndex],
              dayIndex: dayIndex,
              canEdit: canEdit,
              onAddPrescription: onAddPrescription,
            ),
      ],
    );
  }
}

class ProgramConsumerDayCard extends StatelessWidget {
  const ProgramConsumerDayCard({
    super.key,
    required this.entry,
    required this.dayIndex,
    required this.canEdit,
    required this.onAddPrescription,
  });

  final ConsumerDayEntry entry;
  final int dayIndex;
  final bool canEdit;
  final void Function(int blockIndex, int weekIndex, int templateIndex)
      onAddPrescription;

  @override
  Widget build(BuildContext context) {
    final workout = entry.template;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.calendar_today_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Day ${dayIndex + 1}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${programWeekdayLabel(workout.plannedWeekday)} · ${workout.name}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              'Workout',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Exercises',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Text(
                  'Sets/reps',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (workout.prescriptions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No exercises added yet.'),
              )
            else
              for (final prescription in workout.prescriptions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(prescription.exerciseNameSnapshot),
                  subtitle: prescription.exerciseId == null
                      ? const Text('Choose an exercise')
                      : null,
                  trailing: Text(
                    '${prescription.plannedSets} × ${prescription.repsRange}',
                    textAlign: TextAlign.end,
                  ),
                ),
            if (canEdit)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => onAddPrescription(
                    entry.blockIndex,
                    entry.weekIndex,
                    entry.templateIndex,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add exercise'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
