import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import 'b05_education_content.dart';

/// Consumer-facing entry point for packaged education. It deliberately keeps
/// lesson progress behind a quiet list; education is useful, but never a gate
/// for onboarding or daily actions.
class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(b05EducationLessonsControllerProvider);
    final controller = ref.read(b05EducationLessonsControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: switch (state.status) {
        B05EducationLessonsStatus.loading when state.lessons.isEmpty =>
          const Padding(
            padding: EdgeInsets.all(B05Layout.space16),
            child: ConsumerStatusRow(
              label: 'Loading lessons',
              detail: 'Short, optional guides you can read anytime.',
              loading: true,
            ),
          ),
        B05EducationLessonsStatus.error when state.lessons.isEmpty =>
          ProductEmptyState(
            icon: Icons.menu_book_outlined,
            title: 'Learn is unavailable right now',
            message: 'Try again when you have a moment.',
            action: controller.retry,
            actionLabel: 'Try again',
            actionIcon: Icons.refresh_rounded,
          ),
        _ => _LearnList(
          lessons: state.lessons,
          onOpen: (lesson) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  LearnLessonScreen(contentId: lesson.lesson.contentId),
            ),
          ),
        ),
      },
    );
  }
}

class _LearnList extends StatelessWidget {
  const _LearnList({required this.lessons, required this.onOpen});

  final List<B05EducationLessonProgress> lessons;
  final ValueChanged<B05EducationLessonProgress> onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        B05Layout.space16,
        B05Layout.space12,
        B05Layout.space16,
        B05Layout.space24,
      ),
      children: [
        Text('Learn', style: B05Typography.pageTitle(context)),
        const SizedBox(height: B05Layout.space4),
        Text(
          'Short guides for training and nutrition. Pick what helps today.',
          style: B05Typography.body(context),
        ),
        const SizedBox(height: B05Layout.space16),
        for (var index = 0; index < lessons.length; index++) ...[
          _LearnRow(
            lesson: lessons[index],
            onTap: () => onOpen(lessons[index]),
          ),
          if (index < lessons.length - 1)
            Divider(height: 1, color: context.b05Colors.border),
        ],
      ],
    );
  }
}

class _LearnRow extends StatelessWidget {
  const _LearnRow({required this.lesson, required this.onTap});

  final B05EducationLessonProgress lesson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = lesson.progress;
    final status = switch (progress.state) {
      B05EducationProgressState.completed => 'Completed',
      B05EducationProgressState.inProgress => 'In progress',
      B05EducationProgressState.dismissed => 'Not started',
      B05EducationProgressState.notStarted => 'Not started',
    };
    return Semantics(
      button: true,
      label: '${_topicTitle(lesson.lesson.topic)}, $status',
      hint: 'Open lesson',
      onTap: onTap,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: B05Layout.space4),
        leading: Icon(
          Icons.menu_book_outlined,
          color: context.b05Colors.action,
        ),
        title: Text(
          _topicTitle(lesson.lesson.topic),
          style: B05Typography.label(context),
        ),
        subtitle: Text(
          '3–4 min · $status',
          style: B05Typography.caption(context),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class LearnLessonScreen extends ConsumerWidget {
  const LearnLessonScreen({required this.contentId, super.key});

  final String contentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(b05EducationLessonsControllerProvider);
    final controller = ref.read(b05EducationLessonsControllerProvider.notifier);
    final item = state.lessons
        .where((candidate) => candidate.lesson.contentId == contentId)
        .firstOrNull;
    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Learn')),
        body: ProductEmptyState(
          icon: Icons.menu_book_outlined,
          title: 'Lesson unavailable',
          message: 'Choose another guide from Learn.',
          action: () => Navigator.of(context).pop(),
          actionLabel: 'Back to Learn',
        ),
      );
    }
    final completed = item.progress.isComplete;
    return Scaffold(
      appBar: AppBar(title: Text(_topicTitle(item.lesson.topic))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          B05Layout.space20,
          B05Layout.space16,
          B05Layout.space20,
          B05Layout.space32,
        ),
        children: [
          Text(
            _topicTitle(item.lesson.topic),
            style: B05Typography.pageTitle(context),
          ),
          const SizedBox(height: B05Layout.space16),
          Text(
            item.lesson.body,
            style: B05Typography.body(context).copyWith(height: 1.55),
          ),
          const SizedBox(height: B05Layout.space24),
          Text('Was this useful?', style: B05Typography.label(context)),
          const SizedBox(height: B05Layout.space8),
          B05ActionButton(
            label: completed ? 'Read again' : 'Got it',
            icon: completed ? Icons.replay_rounded : Icons.check_rounded,
            onPressed: () async {
              if (completed) {
                await controller.revisit(contentId);
              } else {
                await controller.complete(contentId);
              }
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          if (!completed) ...[
            const SizedBox(height: B05Layout.space4),
            TextButton(
              onPressed: () async {
                await controller.dismiss(contentId);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Not now'),
            ),
          ],
        ],
      ),
    );
  }
}

String _topicTitle(String topic) => switch (topic) {
  'rpe' => 'Understanding RPE',
  'progressive_overload' => 'Progressive overload',
  'energy_balance' => 'Energy balance',
  'protein' => 'Protein basics',
  'recovery' => 'Recovery',
  _ => topic.isEmpty ? 'Learn' : topic[0].toUpperCase() + topic.substring(1),
};
