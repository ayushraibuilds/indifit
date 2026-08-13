import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/fixtures/b05_foundation_registry.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/presentation/diet_preference_presentation.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../education/b05_education_content.dart';

/// The only goal-to-education decision in B05. It uses the goal explicitly
/// selected by the user; it does not inspect profile, health, dietary, or
/// coaching state to infer a path.
abstract final class B05GoalLessonMapping {
  static const Map<String, List<String>> _lessonIdsByGoal = {
    'lose': ['energy_balance', 'protein', 'recovery'],
    'maintain': ['energy_balance', 'protein', 'recovery', 'rpe'],
    'gain': ['progressive_overload', 'protein', 'rpe', 'recovery'],
    'weight_loss': ['energy_balance', 'protein', 'recovery'],
    'hypertrophy': ['progressive_overload', 'protein', 'rpe', 'recovery'],
    'strength': ['rpe', 'progressive_overload', 'recovery'],
  };

  static List<String> lessonIdsFor(String selectedGoal) {
    final goal = selectedGoal.trim().toLowerCase();
    return List.unmodifiable(_lessonIdsByGoal[goal] ?? const <String>[]);
  }
}

class B05AdaptiveOnboardingPlan {
  final String selectedGoal;
  final List<B05EducationContentDescriptor> lessons;

  const B05AdaptiveOnboardingPlan({
    required this.selectedGoal,
    required this.lessons,
  });

  factory B05AdaptiveOnboardingPlan.fromGoal({
    required String selectedGoal,
    B05EducationContentRegistry? registry,
  }) {
    final contentRegistry = registry ?? b05BundledEducationRegistry;
    final byId = {
      for (final lesson in contentRegistry.lessons) lesson.contentId: lesson,
    };
    return B05AdaptiveOnboardingPlan(
      selectedGoal: selectedGoal.trim().toLowerCase(),
      lessons: List.unmodifiable([
        for (final contentId in B05GoalLessonMapping.lessonIdsFor(selectedGoal))
          if (byId[contentId] != null) byId[contentId]!,
      ]),
    );
  }
}

class B05AdaptiveOnboardingLesson {
  final B05EducationLessonProgress lesson;

  const B05AdaptiveOnboardingLesson(this.lesson);

  bool get isCompleted => lesson.progress.isComplete;
}

enum B05AdaptiveOnboardingStatus { loading, ready, saving, error }

class B05AdaptiveOnboardingState {
  final B05AdaptiveOnboardingStatus status;
  final B05AdaptiveOnboardingPlan plan;
  final List<B05AdaptiveOnboardingLesson> lessons;
  final int currentLessonIndex;
  final String? errorMessage;

  const B05AdaptiveOnboardingState({
    required this.status,
    required this.plan,
    this.lessons = const [],
    this.currentLessonIndex = 0,
    this.errorMessage,
  });

  const B05AdaptiveOnboardingState.loading({
    required B05AdaptiveOnboardingPlan plan,
  }) : this(status: B05AdaptiveOnboardingStatus.loading, plan: plan);

  bool get isSaving => status == B05AdaptiveOnboardingStatus.saving;
  bool get hasLessons => lessons.isNotEmpty;
  bool get isComplete =>
      hasLessons && lessons.every((item) => item.isCompleted);

  B05AdaptiveOnboardingState copyWith({
    B05AdaptiveOnboardingStatus? status,
    B05AdaptiveOnboardingPlan? plan,
    List<B05AdaptiveOnboardingLesson>? lessons,
    int? currentLessonIndex,
    String? errorMessage,
    bool clearError = false,
  }) => B05AdaptiveOnboardingState(
    status: status ?? this.status,
    plan: plan ?? this.plan,
    lessons: lessons ?? this.lessons,
    currentLessonIndex: currentLessonIndex ?? this.currentLessonIndex,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );
}

/// Controller boundary for goal-aware lesson selection and progress. Widgets
/// invoke these commands and render its typed state; they do not read Drift.
class B05AdaptiveOnboardingController
    extends StateNotifier<B05AdaptiveOnboardingState> {
  final B05EducationProgressRepository _repository;
  final String _userId;
  Future<void> Function()? _retryAction;

  B05AdaptiveOnboardingController({
    required B05EducationProgressRepository repository,
    required B05EducationContentRegistry registry,
    required String userId,
    required String selectedGoal,
  }) : _repository = repository,
       _userId = userId,
       super(
         B05AdaptiveOnboardingState.loading(
           plan: B05AdaptiveOnboardingPlan.fromGoal(
             selectedGoal: selectedGoal,
             registry: registry,
           ),
         ),
       );

  Future<void> load() async {
    final plan = state.plan;
    final previous = state.lessons;
    state = B05AdaptiveOnboardingState(
      status: B05AdaptiveOnboardingStatus.loading,
      plan: plan,
      lessons: previous,
      currentLessonIndex: state.currentLessonIndex,
    );
    try {
      final lessons = [
        for (final lesson in plan.lessons)
          B05AdaptiveOnboardingLesson(
            await _repository.readLesson(userId: _userId, lesson: lesson),
          ),
      ];
      if (!mounted) return;
      _retryAction = null;
      state = state.copyWith(
        status: B05AdaptiveOnboardingStatus.ready,
        lessons: List.unmodifiable(lessons),
        currentLessonIndex: _nextIncompleteIndex(lessons),
        clearError: true,
      );
    } catch (_) {
      if (!mounted) return;
      _retryAction = load;
      state = state.copyWith(
        status: B05AdaptiveOnboardingStatus.error,
        errorMessage: 'Your learning plan could not be loaded. Try again.',
      );
    }
  }

  Future<void> complete(String contentId) => _run(contentId, (lesson) {
    return _repository.complete(userId: _userId, lesson: lesson);
  });

  Future<void> revisit(String contentId) => _run(contentId, (lesson) {
    return _repository.revisit(userId: _userId, lesson: lesson);
  });

  Future<void> retry() async {
    final action = _retryAction;
    if (action == null || state.isSaving) return;
    await action();
  }

  Future<void> _run(
    String contentId,
    Future<B05EducationProgress> Function(B05EducationContentDescriptor lesson)
    action,
  ) async {
    if (state.isSaving || state.status == B05AdaptiveOnboardingStatus.loading) {
      return;
    }
    final lesson = state.plan.lessons
        .where((item) => item.contentId == contentId)
        .firstOrNull;
    if (lesson == null) {
      state = state.copyWith(
        status: B05AdaptiveOnboardingStatus.error,
        errorMessage: 'That lesson is not part of the selected goal.',
      );
      return;
    }
    state = state.copyWith(
      status: B05AdaptiveOnboardingStatus.saving,
      clearError: true,
    );
    try {
      await action(lesson);
      if (!mounted) return;
      await load();
    } catch (_) {
      if (!mounted) return;
      _retryAction = () => _run(contentId, action);
      state = state.copyWith(
        status: B05AdaptiveOnboardingStatus.error,
        errorMessage: 'That lesson could not be saved. Try again.',
      );
    }
  }

  int _nextIncompleteIndex(List<B05AdaptiveOnboardingLesson> lessons) {
    final index = lessons.indexWhere((item) => !item.isCompleted);
    return index < 0 ? lessons.length : index;
  }
}

final b05AdaptiveOnboardingControllerProvider = StateNotifierProvider
    .autoDispose
    .family<
      B05AdaptiveOnboardingController,
      B05AdaptiveOnboardingState,
      String
    >((ref, selectedGoal) {
      final controller = B05AdaptiveOnboardingController(
        repository: ref.watch(b05EducationProgressRepositoryProvider),
        registry: ref.watch(b05EducationRegistryProvider),
        userId: kLocalNutritionUserScopeId,
        selectedGoal: selectedGoal,
      );
      unawaited(controller.load());
      return controller;
    });

/// Bounded draft adapter for the existing local onboarding convention. It
/// persists only answers/step metadata already owned by onboarding; no lesson
/// bodies, profile authority, or generated routine is copied into the draft.
class B05RoutineWizardDraft {
  final int currentStep;
  final String selectedGoal;
  final String selectedEquipment;
  final int daysPerWeek;
  final String selectedExperience;
  final String injuries;

  const B05RoutineWizardDraft({
    required this.currentStep,
    required this.selectedGoal,
    required this.selectedEquipment,
    required this.daysPerWeek,
    required this.selectedExperience,
    required this.injuries,
  });
}

class B05ProfileOnboardingDraft {
  final int currentPage;
  final String? sex;
  final String name;
  final String age;
  final String height;
  final String weight;
  final String activityLevel;
  final String goal;
  final String targetWeight;
  final String dietPreference;
  final int flowVersion;

  const B05ProfileOnboardingDraft({
    required this.currentPage,
    required this.sex,
    required this.name,
    required this.age,
    required this.height,
    required this.weight,
    required this.activityLevel,
    required this.goal,
    required this.targetWeight,
    required this.dietPreference,
    this.flowVersion = 1,
  });
}

class B05OnboardingDraftStore {
  static const _profilePageKey = 'onboarding_draft_page';
  static const _profileSexKey = 'onboarding_draft_sex';
  static const _profileNameKey = 'onboarding_draft_name';
  static const _profileAgeKey = 'onboarding_draft_age';
  static const _profileHeightKey = 'onboarding_draft_height';
  static const _profileWeightKey = 'onboarding_draft_weight';
  static const _profileActivityKey = 'onboarding_draft_activity';
  static const _profileGoalKey = 'onboarding_draft_goal';
  static const _profileTargetWeightKey = 'onboarding_draft_target_weight';
  static const _profileDietKey = 'onboarding_draft_diet';
  static const _profileFlowVersionKey = 'onboarding_draft_flow_version';

  static const _routineStepKey = 'onboarding_draft_routine_step';
  static const _routineGoalKey = 'onboarding_draft_routine_goal';
  static const _routineEquipmentKey = 'onboarding_draft_routine_equipment';
  static const _routineDaysKey = 'onboarding_draft_routine_days';
  static const _routineExperienceKey = 'onboarding_draft_routine_experience';
  static const _routineInjuriesKey = 'onboarding_draft_routine_injuries';

  const B05OnboardingDraftStore();

  Future<B05ProfileOnboardingDraft?> readProfileDraft() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_profilePageKey)) return null;
    return B05ProfileOnboardingDraft(
      currentPage: _validProfilePage(prefs.getInt(_profilePageKey)),
      sex: _choiceOrNull(prefs.getString(_profileSexKey), const {
        'male',
        'female',
      }),
      name: _bounded(prefs.getString(_profileNameKey) ?? '', maxLength: 100),
      age: _bounded(prefs.getString(_profileAgeKey) ?? '25', maxLength: 16),
      height: _bounded(
        prefs.getString(_profileHeightKey) ?? '170',
        maxLength: 16,
      ),
      weight: _bounded(
        prefs.getString(_profileWeightKey) ?? '70',
        maxLength: 16,
      ),
      activityLevel: normalizeActivity(prefs.getString(_profileActivityKey)),
      goal: normalizeProfileGoal(prefs.getString(_profileGoalKey)),
      targetWeight: _bounded(
        prefs.getString(_profileTargetWeightKey) ?? '70',
        maxLength: 16,
      ),
      dietPreference: normalizeDiet(prefs.getString(_profileDietKey)),
      flowVersion: prefs.getInt(_profileFlowVersionKey) ?? 1,
    );
  }

  Future<void> saveProfileDraft(B05ProfileOnboardingDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_profilePageKey, _validProfilePage(draft.currentPage));
    if (draft.sex == null) {
      await prefs.remove(_profileSexKey);
    } else {
      await prefs.setString(
        _profileSexKey,
        _choiceOrNull(draft.sex, const {'male', 'female'})!,
      );
    }
    await prefs.setString(
      _profileNameKey,
      _bounded(draft.name, maxLength: 100),
    );
    await prefs.setString(_profileAgeKey, _bounded(draft.age, maxLength: 16));
    await prefs.setString(
      _profileHeightKey,
      _bounded(draft.height, maxLength: 16),
    );
    await prefs.setString(
      _profileWeightKey,
      _bounded(draft.weight, maxLength: 16),
    );
    await prefs.setString(
      _profileActivityKey,
      normalizeActivity(draft.activityLevel),
    );
    await prefs.setString(_profileGoalKey, normalizeProfileGoal(draft.goal));
    await prefs.setString(
      _profileTargetWeightKey,
      _bounded(draft.targetWeight, maxLength: 16),
    );
    await prefs.setString(_profileDietKey, normalizeDiet(draft.dietPreference));
    await prefs.setInt(_profileFlowVersionKey, draft.flowVersion);
  }

  Future<void> clearProfileDraft() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in const [
      _profilePageKey,
      _profileSexKey,
      _profileNameKey,
      _profileAgeKey,
      _profileHeightKey,
      _profileWeightKey,
      _profileActivityKey,
      _profileGoalKey,
      _profileTargetWeightKey,
      _profileDietKey,
      _profileFlowVersionKey,
    ]) {
      await prefs.remove(key);
    }
  }

  /// Marks profile setup as intentionally deferred without creating a
  /// profile, target, eligibility, or adaptive recommendation from defaults.
  Future<void> markProfileOnboardingSkipped() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    await prefs.setBool('onboarding_skipped', true);
    await clearProfileDraft();
  }

  Future<B05RoutineWizardDraft?> readRoutineDraft() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_routineStepKey) &&
        !prefs.containsKey(_routineGoalKey)) {
      return null;
    }
    return B05RoutineWizardDraft(
      currentStep: _validRoutineStep(prefs.getInt(_routineStepKey)),
      selectedGoal: normalizeRoutineGoal(prefs.getString(_routineGoalKey)),
      selectedEquipment: normalizeEquipment(
        prefs.getString(_routineEquipmentKey),
      ),
      daysPerWeek: _validDays(prefs.getInt(_routineDaysKey)),
      selectedExperience: normalizeExperience(
        prefs.getString(_routineExperienceKey),
      ),
      injuries: normalizeInjuries(prefs.getString(_routineInjuriesKey)),
    );
  }

  Future<void> saveRoutineDraft(B05RoutineWizardDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_routineStepKey, _validRoutineStep(draft.currentStep));
    await prefs.setString(
      _routineGoalKey,
      normalizeRoutineGoal(draft.selectedGoal),
    );
    await prefs.setString(
      _routineEquipmentKey,
      normalizeEquipment(draft.selectedEquipment),
    );
    await prefs.setInt(_routineDaysKey, _validDays(draft.daysPerWeek));
    await prefs.setString(
      _routineExperienceKey,
      normalizeExperience(draft.selectedExperience),
    );
    await prefs.setString(
      _routineInjuriesKey,
      normalizeInjuries(draft.injuries),
    );
  }

  Future<void> clearRoutineDraft() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in const [
      _routineStepKey,
      _routineGoalKey,
      _routineEquipmentKey,
      _routineDaysKey,
      _routineExperienceKey,
      _routineInjuriesKey,
    ]) {
      await prefs.remove(key);
    }
  }

  static String normalizeActivity(String? value) => _choice(value, const {
    'sedentary',
    'light',
    'moderate',
    'active',
  }, fallback: 'moderate');

  static String normalizeProfileGoal(String? value) =>
      _choice(value, const {'lose', 'maintain', 'gain'}, fallback: 'maintain');

  static String normalizeDiet(String? value) =>
      DietPreferencePresentation.normalizeForOnboarding(value);

  static String normalizeRoutineGoal(String? value) => _choice(value, const {
    'hypertrophy',
    'strength',
    'weight_loss',
  }, fallback: 'hypertrophy');

  static String normalizeEquipment(String? value) {
    final normalized = value?.trim().toLowerCase();
    return switch (normalized) {
      'full_gym' || 'gym' => 'gym',
      'dumbbells' => 'dumbbells',
      'bodyweight' => 'bodyweight',
      _ => 'gym',
    };
  }

  static String normalizeExperience(String? value) => _choice(value, const {
    'beginner',
    'intermediate',
    'advanced',
  }, fallback: 'beginner');

  static String normalizeInjuries(String? value) =>
      _bounded(value ?? '', maxLength: 512);

  static String _choice(
    String? value,
    Set<String> allowed, {
    required String fallback,
  }) {
    final normalized = value?.trim().toLowerCase();
    return normalized != null && allowed.contains(normalized)
        ? normalized
        : fallback;
  }

  static String? _choiceOrNull(String? value, Set<String> allowed) {
    final normalized = value?.trim().toLowerCase();
    return normalized != null && allowed.contains(normalized)
        ? normalized
        : null;
  }

  static String _bounded(String value, {required int maxLength}) {
    final normalized = value.trim();
    return normalized.length <= maxLength
        ? normalized
        : normalized.substring(0, maxLength);
  }

  static int _validProfilePage(int? value) => (value ?? 0).clamp(0, 7).toInt();

  static int _validRoutineStep(int? value) => (value ?? 0).clamp(0, 4).toInt();

  static int _validDays(int? value) =>
      value != null && value >= 3 && value <= 6 ? value : 3;
}

/// Goal-filtered lesson surface used inside the existing onboarding screens.
/// It has non-gesture action controls and remains useful without network or
/// media because the lesson registry and progress are local.
class B05AdaptiveLessonPath extends ConsumerWidget {
  final String selectedGoal;

  const B05AdaptiveLessonPath({required this.selectedGoal, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = selectedGoal.trim().toLowerCase();
    if (goal.isEmpty) {
      return const B05StatusMessage(
        status: B05SemanticStatus.info,
        label: 'Choose a goal to see relevant lessons',
      );
    }
    final state = ref.watch(b05AdaptiveOnboardingControllerProvider(goal));
    final controller = ref.read(
      b05AdaptiveOnboardingControllerProvider(goal).notifier,
    );
    if (state.status == B05AdaptiveOnboardingStatus.loading &&
        state.lessons.isEmpty) {
      return const B05StatusMessage(
        status: B05SemanticStatus.info,
        label: 'Loading goal-relevant lessons',
      );
    }
    if (state.status == B05AdaptiveOnboardingStatus.error &&
        state.lessons.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          B05StatusMessage(
            status: B05SemanticStatus.unavailable,
            label: 'Goal-relevant lessons are unavailable',
            value: state.errorMessage,
          ),
          const SizedBox(height: B05Layout.space8),
          B05ActionButton(
            label: 'Retry lessons',
            icon: Icons.refresh_rounded,
            emphasis: B05ActionEmphasis.secondary,
            hint: 'Retry loading the bundled lessons offline.',
            onPressed: controller.retry,
          ),
        ],
      );
    }
    if (state.lessons.isEmpty) {
      return const B05StatusMessage(
        status: B05SemanticStatus.info,
        label: 'No lessons are mapped to this goal',
      );
    }
    return B05Surface(
      subtle: true,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              container: true,
              header: true,
              label: 'Goal-relevant lessons',
              value: '${state.lessons.length} lessons for $goal',
              child: ExcludeSemantics(
                child: Text(
                  'Learn for your $goal goal',
                  style: B05Typography.title(context),
                ),
              ),
            ),
            const SizedBox(height: B05Layout.space4),
            Text(
              state.isComplete
                  ? 'You can revisit any completed lesson.'
                  : 'Completed lessons are skipped on resume.',
              style: B05Typography.body(context),
            ),
            const SizedBox(height: B05Layout.space12),
            for (var index = 0; index < state.lessons.length; index++)
              _B05AdaptiveLessonTile(
                item: state.lessons[index],
                isCurrent: index == state.currentLessonIndex,
                isSaving: state.isSaving,
                onComplete: () => controller.complete(
                  state.lessons[index].lesson.lesson.contentId,
                ),
                onRevisit: () => controller.revisit(
                  state.lessons[index].lesson.lesson.contentId,
                ),
                focusOrder: index.toDouble(),
              ),
          ],
        ),
      ),
    );
  }
}

class _B05AdaptiveLessonTile extends StatelessWidget {
  final B05AdaptiveOnboardingLesson item;
  final bool isCurrent;
  final bool isSaving;
  final VoidCallback onComplete;
  final VoidCallback onRevisit;
  final double focusOrder;

  const _B05AdaptiveLessonTile({
    required this.item,
    required this.isCurrent,
    required this.isSaving,
    required this.onComplete,
    required this.onRevisit,
    required this.focusOrder,
  });

  @override
  Widget build(BuildContext context) {
    final progress = item.lesson.progress;
    final completed = progress.isComplete;
    final label = completed
        ? 'Completed'
        : progress.state == B05EducationProgressState.inProgress
        ? 'In progress'
        : 'Not started';
    return Padding(
      padding: const EdgeInsets.only(bottom: B05Layout.space12),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: _title(item.lesson.lesson.topic),
        value: label,
        hint: isCurrent ? 'Next relevant lesson' : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _title(item.lesson.lesson.topic),
                    style: B05Typography.label(context),
                  ),
                ),
                if (isCurrent)
                  Semantics(
                    label: 'Next lesson',
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: B05Layout.iconMedium,
                      color: context.b05Colors.action,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: B05Layout.space4),
            Text(item.lesson.lesson.body, style: B05Typography.body(context)),
            const SizedBox(height: B05Layout.space4),
            Text(label),
            const SizedBox(height: B05Layout.space8),
            B05ActionGroup(
              children: [
                B05ActionButton(
                  label: completed ? 'Revisit lesson' : 'Mark lesson complete',
                  icon: completed ? Icons.replay_rounded : Icons.check_rounded,
                  hint: completed
                      ? 'Reopens this completed lesson intentionally.'
                      : 'Marks this goal-relevant lesson complete.',
                  emphasis: completed
                      ? B05ActionEmphasis.secondary
                      : B05ActionEmphasis.primary,
                  onPressed: isSaving
                      ? null
                      : completed
                      ? onRevisit
                      : onComplete,
                  focusOrder: focusOrder,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _title(String topic) => switch (topic) {
    'rpe' => 'RPE',
    'progressive_overload' => 'Progressive overload',
    'energy_balance' => 'Energy balance',
    _ =>
      topic.isEmpty ? topic : '${topic[0].toUpperCase()}${topic.substring(1)}',
  };
}
