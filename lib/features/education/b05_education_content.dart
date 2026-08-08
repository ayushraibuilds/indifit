import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/fixtures/b02_muscle_catalog.dart';
import '../../core/fixtures/b05_foundation_registry.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/database/app_database.dart';
import '../../data/models/b02_execution_models.dart';
import '../../data/models/b02_muscle_volume_models.dart';
import '../../data/repositories/b02_muscle_volume_repository.dart';
import '../../data/repositories/equipment_preference_repository.dart';
import '../media/b05_media_bundle.dart';
import '../media/b05_muscle_diagram.dart';

/// The five bundled, offline lessons shipped in B05.  Lesson text is
/// packaged content; progress is the only user-owned value persisted by the
/// repository below.
const List<B05EducationContentDescriptor> kB05BundledEducationLessons = [
  B05EducationContentDescriptor(
    contentId: 'rpe',
    version: '1.0.0',
    topic: 'rpe',
    body:
        'RPE is your reported effort for a set. Use the feeling of the whole '
        'set and leave room to stop when form or safety requires it.',
    relevanceTags: {'rpe', 'training'},
  ),
  B05EducationContentDescriptor(
    contentId: 'progressive_overload',
    version: '1.0.0',
    topic: 'progressive_overload',
    body:
        'Progressive overload means gradually giving a well-recovered body a '
        'clearer training challenge. A change can be a little more load, '
        'repetition, control, or consistency rather than a forced jump.',
    relevanceTags: {'progressive_overload', 'training'},
  ),
  B05EducationContentDescriptor(
    contentId: 'protein',
    version: '1.0.0',
    topic: 'protein',
    body:
        'Protein is one part of a varied eating pattern and supports normal '
        'tissue maintenance. Spread ordinary meals across the day and use '
        'your existing nutrition guidance when making choices.',
    relevanceTags: {'protein', 'nutrition'},
  ),
  B05EducationContentDescriptor(
    contentId: 'energy_balance',
    version: '1.0.0',
    topic: 'energy_balance',
    body:
        'Energy balance describes energy consumed and energy used over time. '
        'It is a trend, not a single-meal score, and it does not replace the '
        'app\'s nutrition guidance or safety checks.',
    relevanceTags: {'energy_balance', 'nutrition'},
  ),
  B05EducationContentDescriptor(
    contentId: 'recovery',
    version: '1.0.0',
    topic: 'recovery',
    body:
        'Recovery includes rest, sleep, food, hydration, and adjusting the '
        'session when you do not feel ready. Use the existing workout and '
        'coaching surfaces for any schedule decision.',
    relevanceTags: {'recovery', 'training'},
  ),
];

/// Single packaged registry used by education, onboarding and later media
/// surfaces.  It has no network or filesystem dependency, so the lessons are
/// available in strict-offline mode.
final B05EducationContentRegistry b05BundledEducationRegistry =
    B05EducationContentRegistry(kB05BundledEducationLessons);

enum B05EducationProgressState {
  notStarted('notStarted'),
  inProgress('inProgress'),
  completed('completed'),
  dismissed('dismissed');

  final String dbValue;

  const B05EducationProgressState(this.dbValue);

  static B05EducationProgressState parse(Object? value) {
    for (final state in values) {
      if (state.dbValue == value) return state;
    }
    throw ArgumentError.value(
      value,
      'state',
      'Unknown education progress state.',
    );
  }
}

class B05EducationProgress {
  final String contentId;
  final String contentVersion;
  final B05EducationProgressState state;
  final DateTime updatedAtUtc;

  const B05EducationProgress({
    required this.contentId,
    required this.contentVersion,
    required this.state,
    required this.updatedAtUtc,
  });

  bool get isComplete => state == B05EducationProgressState.completed;
  bool get isDismissed => state == B05EducationProgressState.dismissed;

  B05EducationProgress copyWith({
    B05EducationProgressState? state,
    DateTime? updatedAtUtc,
  }) => B05EducationProgress(
    contentId: contentId,
    contentVersion: contentVersion,
    state: state ?? this.state,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
}

/// Read projection for one current lesson.  [isRevision] is true when a
/// previous version exists but the current packaged version has no progress;
/// the old row is retained for portable history and the current lesson starts
/// as notStarted.
class B05EducationLessonProgress {
  final B05EducationContentDescriptor lesson;
  final B05EducationProgress progress;
  final String? previousVersion;

  const B05EducationLessonProgress({
    required this.lesson,
    required this.progress,
    required this.previousVersion,
  });

  bool get isRevision =>
      previousVersion != null &&
      previousVersion != lesson.version &&
      progress.contentVersion == lesson.version &&
      progress.state == B05EducationProgressState.notStarted;
}

class B05EducationProgressRepository {
  final AppDatabase _database;
  final Uuid _uuid;
  final DateTime Function() _nowUtc;

  B05EducationProgressRepository({
    required AppDatabase database,
    Uuid? uuid,
    DateTime Function()? nowUtc,
  }) : _database = database,
       _uuid = uuid ?? const Uuid(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  Future<B05EducationProgress?> read({
    required String userId,
    required String contentId,
    required String contentVersion,
  }) async {
    final owner = _owner(userId);
    final id = _contentId(contentId);
    final version = _version(contentVersion);
    final row =
        await (_database.select(_database.educationContentProgress)..where(
              (table) =>
                  table.userId.equals(owner) &
                  table.contentId.equals(id) &
                  table.contentVersion.equals(version),
            ))
            .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<List<B05EducationProgress>> readAll({required String userId}) async {
    final owner = _owner(userId);
    final rows =
        await (_database.select(_database.educationContentProgress)
              ..where((table) => table.userId.equals(owner))
              ..orderBy([
                (table) => OrderingTerm(expression: table.contentId),
                (table) => OrderingTerm(expression: table.contentVersion),
              ]))
            .get();
    return List.unmodifiable(rows.map(_fromRow));
  }

  Stream<List<B05EducationProgress>> watchAll({required String userId}) {
    final owner = _owner(userId);
    return (_database.select(_database.educationContentProgress)
          ..where((table) => table.userId.equals(owner))
          ..orderBy([
            (table) => OrderingTerm(expression: table.contentId),
            (table) => OrderingTerm(expression: table.contentVersion),
          ]))
        .watch()
        .map((rows) => List.unmodifiable(rows.map(_fromRow)));
  }

  Future<B05EducationLessonProgress> readLesson({
    required String userId,
    required B05EducationContentDescriptor lesson,
  }) async {
    final rows = await _rowsForLesson(
      userId: userId,
      contentId: lesson.contentId,
    );
    final current = rows
        .where((row) => row.contentVersion == lesson.version)
        .firstOrNull;
    final previous =
        rows.where((row) => row.contentVersion != lesson.version).toList()
          ..sort((a, b) => b.updatedAtUtc.compareTo(a.updatedAtUtc));
    final now = _nowUtc();
    return B05EducationLessonProgress(
      lesson: lesson,
      progress:
          current ??
          B05EducationProgress(
            contentId: lesson.contentId,
            contentVersion: lesson.version,
            state: B05EducationProgressState.notStarted,
            updatedAtUtc: now,
          ),
      previousVersion: previous.firstOrNull?.contentVersion,
    );
  }

  Future<List<B05EducationLessonProgress>> readLessons({
    required String userId,
    B05EducationContentRegistry? registry,
  }) async {
    final contentRegistry = registry ?? b05BundledEducationRegistry;
    return List.unmodifiable([
      for (final lesson in contentRegistry.lessons)
        await readLesson(userId: userId, lesson: lesson),
    ]);
  }

  Future<B05EducationProgress> setState({
    required String userId,
    required B05EducationContentDescriptor lesson,
    required B05EducationProgressState state,
  }) async {
    _validateLesson(lesson);
    final owner = _owner(userId);
    final now = _nowUtc().toUtc();
    final existing = await read(
      userId: owner,
      contentId: lesson.contentId,
      contentVersion: lesson.version,
    );
    final rowId = existing == null
        ? _uuid.v4()
        : (await (_database.select(_database.educationContentProgress)..where(
                    (table) =>
                        table.userId.equals(owner) &
                        table.contentId.equals(lesson.contentId) &
                        table.contentVersion.equals(lesson.version),
                  ))
                  .getSingle())
              .id;
    final companion = EducationContentProgressCompanion(
      id: Value(rowId),
      userId: Value(owner),
      contentId: Value(lesson.contentId),
      contentVersion: Value(lesson.version),
      state: Value(state.dbValue),
      updatedAtUtc: Value(now),
    );
    await _database
        .into(_database.educationContentProgress)
        .insertOnConflictUpdate(companion);
    return B05EducationProgress(
      contentId: lesson.contentId,
      contentVersion: lesson.version,
      state: state,
      updatedAtUtc: now,
    );
  }

  Future<B05EducationProgress> start({
    required String userId,
    required B05EducationContentDescriptor lesson,
  }) => setState(
    userId: userId,
    lesson: lesson,
    state: B05EducationProgressState.inProgress,
  );

  Future<B05EducationProgress> complete({
    required String userId,
    required B05EducationContentDescriptor lesson,
  }) => setState(
    userId: userId,
    lesson: lesson,
    state: B05EducationProgressState.completed,
  );

  Future<B05EducationProgress> dismiss({
    required String userId,
    required B05EducationContentDescriptor lesson,
  }) => setState(
    userId: userId,
    lesson: lesson,
    state: B05EducationProgressState.dismissed,
  );

  /// Revisit intentionally reopens the current version. It never deletes
  /// completion history or writes a second row for the same content version.
  Future<B05EducationProgress> revisit({
    required String userId,
    required B05EducationContentDescriptor lesson,
  }) => start(userId: userId, lesson: lesson);

  /// Explicit revision entry point. A new version is written as inProgress;
  /// older version rows remain untouched and can still be restored from v10.
  Future<B05EducationProgress> beginRevision({
    required String userId,
    required B05EducationContentDescriptor lesson,
  }) => start(userId: userId, lesson: lesson);

  Future<List<B05EducationProgress>> _rowsForLesson({
    required String userId,
    required String contentId,
  }) async {
    final owner = _owner(userId);
    final id = _contentId(contentId);
    final rows =
        await (_database.select(_database.educationContentProgress)..where(
              (table) =>
                  table.userId.equals(owner) & table.contentId.equals(id),
            ))
            .get();
    return rows.map(_fromRow).toList(growable: false);
  }

  B05EducationProgress _fromRow(EducationContentProgressRow row) =>
      B05EducationProgress(
        contentId: row.contentId,
        contentVersion: row.contentVersion,
        state: B05EducationProgressState.parse(row.state),
        updatedAtUtc: row.updatedAtUtc.toUtc(),
      );

  static String _owner(String value) {
    final owner = value.trim();
    if (owner.isEmpty) throw ArgumentError.value(value, 'userId');
    return owner;
  }

  static String _contentId(String value) {
    final id = value.trim();
    if (id.isEmpty) throw ArgumentError.value(value, 'contentId');
    return id;
  }

  static String _version(String value) {
    final version = value.trim();
    if (version.isEmpty) throw ArgumentError.value(value, 'contentVersion');
    return version;
  }

  static void _validateLesson(B05EducationContentDescriptor lesson) {
    if (lesson.contentId.trim().isEmpty || lesson.version.trim().isEmpty) {
      throw ArgumentError('Education lesson identity must not be blank.');
    }
  }
}

/// Stable muscle role labels for the canonical B02 mapping contract. Unknown
/// mappings stay unknown and never become a zero-valued contribution.
class B05MuscleLabel {
  final String muscleId;
  final String displayName;
  final B02MuscleRole? role;
  final int? contributionBasisPoints;

  const B05MuscleLabel({
    required this.muscleId,
    required this.displayName,
    required this.role,
    required this.contributionBasisPoints,
  });

  String get roleLabel => role?.dbValue ?? 'unknown';
}

class B05MuscleLabelSet {
  final List<B05MuscleLabel> labels;
  final bool isUnknown;

  const B05MuscleLabelSet({required this.labels, required this.isUnknown});

  Iterable<B05MuscleLabel> forRole(B02MuscleRole role) =>
      labels.where((label) => label.role == role);
}

class B05MuscleLabelMapper {
  const B05MuscleLabelMapper();

  B05MuscleLabelSet map(
    B02MuscleVolumeMapping? mapping, {
    Iterable<B02MuscleCatalogEntry> catalog = B02CanonicalMuscleCatalog.muscles,
  }) {
    if (mapping == null || mapping.status == B02MappingStatus.unknown) {
      return const B05MuscleLabelSet(labels: [], isUnknown: true);
    }
    final byId = {for (final item in catalog) item.id: item};
    var unknown = false;
    final labels = <B05MuscleLabel>[];
    for (final contribution in mapping.contributions) {
      final entry = byId[contribution.muscleId];
      if (entry == null) unknown = true;
      labels.add(
        B05MuscleLabel(
          muscleId: contribution.muscleId,
          displayName: entry?.displayName ?? 'Unknown muscle',
          role: entry == null ? null : contribution.role,
          contributionBasisPoints: entry == null
              ? null
              : contribution.contributionBasisPoints,
        ),
      );
    }
    return B05MuscleLabelSet(
      labels: List.unmodifiable(labels),
      isUnknown: unknown,
    );
  }
}

class B05ExerciseChecklistItem {
  final String id;
  final String label;

  const B05ExerciseChecklistItem({required this.id, required this.label});
}

class B05ExerciseEducationCatalog {
  const B05ExerciseEducationCatalog();

  List<B05ExerciseChecklistItem> checklist({
    required String exerciseName,
    List<String> catalogueCues = const [],
  }) {
    final cleanName = exerciseName.trim().isEmpty
        ? 'this exercise'
        : exerciseName.trim();
    final cue = catalogueCues.firstWhere(
      (value) => value.trim().isNotEmpty,
      orElse: () => 'Keep a controlled range that feels safe for $cleanName.',
    );
    return [
      B05ExerciseChecklistItem(
        id: 'setup',
        label: 'Set up $cleanName consistently.',
      ),
      B05ExerciseChecklistItem(
        id: 'brace',
        label: 'Use a stable brace and starting position.',
      ),
      B05ExerciseChecklistItem(id: 'cue', label: cue.trim()),
      const B05ExerciseChecklistItem(
        id: 'control',
        label: 'Control the movement; do not rush the return.',
      ),
      const B05ExerciseChecklistItem(
        id: 'stop',
        label: 'Stop or reduce the set if form or safety changes.',
      ),
    ];
  }
}

/// A presentation model that keeps catalogue guidance and personal cues
/// visibly separate while sharing one canonical B02 muscle mapping.
class B05ExerciseEducationModel {
  final String exerciseName;
  final String? stableExerciseId;
  final List<String> catalogueCues;
  final List<String> catalogueMistakes;
  final List<String> personalCues;
  final List<B05ExerciseChecklistItem> checklist;
  final B05MuscleLabelSet muscles;

  const B05ExerciseEducationModel({
    required this.exerciseName,
    required this.stableExerciseId,
    required this.catalogueCues,
    required this.catalogueMistakes,
    required this.personalCues,
    required this.checklist,
    required this.muscles,
  });
}

final b05EducationRegistryProvider = Provider<B05EducationContentRegistry>(
  (_) => b05BundledEducationRegistry,
);

final b05EducationProgressRepositoryProvider =
    Provider<B05EducationProgressRepository>(
      (ref) =>
          B05EducationProgressRepository(database: ref.watch(databaseProvider)),
    );

final b05EducationLessonsProvider =
    FutureProvider<List<B05EducationLessonProgress>>((ref) async {
      final repository = ref.watch(b05EducationProgressRepositoryProvider);
      final registry = ref.watch(b05EducationRegistryProvider);
      return repository.readLessons(
        userId: kLocalNutritionUserScopeId,
        registry: registry,
      );
    });

enum B05EducationLessonsStatus { loading, ready, saving, error }

class B05EducationLessonsState {
  final B05EducationLessonsStatus status;
  final List<B05EducationLessonProgress> lessons;
  final String? errorMessage;

  const B05EducationLessonsState({
    required this.status,
    this.lessons = const [],
    this.errorMessage,
  });

  const B05EducationLessonsState.loading()
    : status = B05EducationLessonsStatus.loading,
      lessons = const [],
      errorMessage = null;

  bool get isSaving => status == B05EducationLessonsStatus.saving;
}

/// Presentation controller for the bundled lesson list. It owns only local
/// content progress commands; lesson text remains in the packaged registry and
/// no B01–B04 domain fact is calculated here.
class B05EducationLessonsController
    extends StateNotifier<B05EducationLessonsState> {
  final B05EducationProgressRepository _repository;
  final B05EducationContentRegistry _registry;
  final String _userId;
  Future<void> Function()? _retryAction;

  B05EducationLessonsController({
    required B05EducationProgressRepository repository,
    required B05EducationContentRegistry registry,
    required String userId,
  }) : _repository = repository,
       _registry = registry,
       _userId = userId,
       super(const B05EducationLessonsState.loading());

  Future<void> load() async {
    final previous = state.lessons;
    state = B05EducationLessonsState(
      status: B05EducationLessonsStatus.loading,
      lessons: previous,
    );
    try {
      final lessons = await _repository.readLessons(
        userId: _userId,
        registry: _registry,
      );
      if (!mounted) return;
      _retryAction = null;
      state = B05EducationLessonsState(
        status: B05EducationLessonsStatus.ready,
        lessons: lessons,
      );
    } catch (error) {
      if (!mounted) return;
      _retryAction = load;
      state = B05EducationLessonsState(
        status: B05EducationLessonsStatus.error,
        lessons: previous,
        errorMessage: ProductFailurePresentation.fromError(
          error,
          title: 'Mini lessons are unavailable',
        ).message,
      );
    }
  }

  Future<void> complete(String contentId) => _run(contentId, (lesson) {
    return _repository.complete(userId: _userId, lesson: lesson);
  });

  Future<void> dismiss(String contentId) => _run(contentId, (lesson) {
    return _repository.dismiss(userId: _userId, lesson: lesson);
  });

  Future<void> revisit(String contentId) => _run(contentId, (lesson) {
    return _repository.revisit(userId: _userId, lesson: lesson);
  });

  Future<void> beginRevision(String contentId) => _run(contentId, (lesson) {
    return _repository.beginRevision(userId: _userId, lesson: lesson);
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
    if (state.isSaving) return;
    final lesson = _registry.lessons
        .where((item) => item.contentId == contentId)
        .firstOrNull;
    if (lesson == null) {
      state = B05EducationLessonsState(
        status: B05EducationLessonsStatus.error,
        lessons: state.lessons,
        errorMessage: 'Unknown lesson.',
      );
      return;
    }
    state = B05EducationLessonsState(
      status: B05EducationLessonsStatus.saving,
      lessons: state.lessons,
    );
    try {
      await action(lesson);
      if (!mounted) return;
      await load();
    } catch (error) {
      if (!mounted) return;
      _retryAction = () => _run(contentId, action);
      state = B05EducationLessonsState(
        status: B05EducationLessonsStatus.error,
        lessons: state.lessons,
        errorMessage: ProductFailurePresentation.fromError(
          error,
          title: 'Mini lesson could not be saved',
        ).message,
      );
    }
  }
}

final b05EducationLessonsControllerProvider =
    StateNotifierProvider.autoDispose<
      B05EducationLessonsController,
      B05EducationLessonsState
    >((ref) {
      final controller = B05EducationLessonsController(
        repository: ref.watch(b05EducationProgressRepositoryProvider),
        registry: ref.watch(b05EducationRegistryProvider),
        userId: kLocalNutritionUserScopeId,
      );
      unawaited(controller.load());
      return controller;
    });

/// Offline mini-lesson list with explicit completion, dismissal and revisit
/// actions. It remains useful when media is absent because it only renders
/// packaged text and local progress.
class B05MiniLessonsPanel extends ConsumerWidget {
  const B05MiniLessonsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(b05EducationLessonsControllerProvider);
    final controller = ref.read(b05EducationLessonsControllerProvider.notifier);
    if (state.status == B05EducationLessonsStatus.loading &&
        state.lessons.isEmpty) {
      return const B05StatusMessage(
        status: B05SemanticStatus.info,
        label: 'Loading mini lessons',
      );
    }
    if (state.status == B05EducationLessonsStatus.error &&
        state.lessons.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          B05StatusMessage(
            status: B05SemanticStatus.unavailable,
            label: 'Mini lessons are unavailable',
            value: state.errorMessage,
          ),
          const SizedBox(height: B05Layout.space8),
          B05ActionButton(
            label: 'Retry',
            icon: Icons.refresh_rounded,
            hint: 'Retry loading offline mini lessons.',
            emphasis: B05ActionEmphasis.secondary,
            onPressed: controller.retry,
          ),
        ],
      );
    }
    if (state.lessons.isEmpty) {
      return const B05StatusMessage(
        status: B05SemanticStatus.info,
        label: 'No mini lessons are available',
      );
    }
    return B05Surface(
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              container: true,
              header: true,
              label: 'Mini lessons',
              child: ExcludeSemantics(
                child: Text(
                  'Mini lessons',
                  style: B05Typography.title(context),
                ),
              ),
            ),
            const SizedBox(height: B05Layout.space12),
            for (var index = 0; index < state.lessons.length; index++)
              _B05MiniLessonTile(
                item: state.lessons[index],
                onComplete: () =>
                    controller.complete(state.lessons[index].lesson.contentId),
                onDismiss: () =>
                    controller.dismiss(state.lessons[index].lesson.contentId),
                onRevisit: () =>
                    controller.revisit(state.lessons[index].lesson.contentId),
                onRevision: () => controller.beginRevision(
                  state.lessons[index].lesson.contentId,
                ),
                isSaving: state.isSaving,
                focusBase: index * 4,
              ),
          ],
        ),
      ),
    );
  }
}

class _B05MiniLessonTile extends StatelessWidget {
  final B05EducationLessonProgress item;
  final VoidCallback onComplete;
  final VoidCallback onDismiss;
  final VoidCallback onRevisit;
  final VoidCallback onRevision;
  final bool isSaving;
  final int focusBase;

  const _B05MiniLessonTile({
    required this.item,
    required this.onComplete,
    required this.onDismiss,
    required this.onRevisit,
    required this.onRevision,
    required this.isSaving,
    required this.focusBase,
  });

  @override
  Widget build(BuildContext context) {
    final progress = item.progress;
    final stateLabel = switch (progress.state) {
      B05EducationProgressState.notStarted => 'Not started',
      B05EducationProgressState.inProgress => 'In progress',
      B05EducationProgressState.completed => 'Completed',
      B05EducationProgressState.dismissed => 'Dismissed',
    };
    final actions = <Widget>[];
    if (item.isRevision) {
      actions.add(
        B05ActionButton(
          label: 'Read refreshed lesson',
          icon: Icons.auto_awesome_outlined,
          hint: 'Starts the refreshed ${item.lesson.topic} lesson.',
          onPressed: isSaving ? null : onRevision,
          focusOrder: focusBase.toDouble(),
        ),
      );
    } else if (progress.state == B05EducationProgressState.completed ||
        progress.state == B05EducationProgressState.dismissed) {
      actions.add(
        B05ActionButton(
          label: 'Revisit',
          icon: Icons.replay_rounded,
          hint: 'Reopens this lesson for review.',
          emphasis: B05ActionEmphasis.secondary,
          onPressed: isSaving ? null : onRevisit,
          focusOrder: focusBase.toDouble(),
        ),
      );
    } else {
      actions.addAll([
        B05ActionButton(
          label: 'Mark complete',
          icon: Icons.check_rounded,
          hint: 'Marks this lesson complete.',
          onPressed: isSaving ? null : onComplete,
          focusOrder: focusBase.toDouble(),
        ),
        B05ActionButton(
          label: 'Dismiss',
          icon: Icons.close_rounded,
          hint: 'Dismisses this lesson without deleting its content.',
          emphasis: B05ActionEmphasis.secondary,
          onPressed: isSaving ? null : onDismiss,
          focusOrder: (focusBase + 1).toDouble(),
        ),
      ]);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: B05Layout.space16),
      child: Semantics(
        container: true,
        label: item.lesson.topic,
        value: stateLabel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _topicTitle(item.lesson.topic),
              style: B05Typography.label(context),
            ),
            const SizedBox(height: B05Layout.space4),
            Text(item.lesson.body, style: B05Typography.body(context)),
            const SizedBox(height: B05Layout.space4),
            Text(stateLabel, style: B05Typography.body(context)),
            if (item.isRevision) ...[
              const SizedBox(height: B05Layout.space4),
              const B05StatusMessage(
                status: B05SemanticStatus.info,
                label: 'A refreshed lesson is available',
                value: 'Your earlier progress remains in your history.',
              ),
            ],
            const SizedBox(height: B05Layout.space8),
            B05ActionGroup(children: actions),
          ],
        ),
      ),
    );
  }

  static String _topicTitle(String topic) => switch (topic) {
    'rpe' => 'RPE',
    'progressive_overload' => 'Progressive overload',
    'energy_balance' => 'Energy balance',
    _ =>
      topic.isEmpty ? topic : '${topic[0].toUpperCase()}${topic.substring(1)}',
  };
}

final b05ExerciseMuscleMappingProvider = FutureProvider.autoDispose
    .family<B02MuscleVolumeMapping?, String>((ref, stableId) async {
      final id = stableId.trim();
      if (id.isEmpty) return null;
      final repository = B02MuscleVolumeRepository(ref.watch(databaseProvider));
      return repository.readMappingForExercise(id);
    });

/// Existing B01 personal-cue provider is deliberately reused rather than
/// copying exercise preferences into B05.
final b05ExerciseEducationProvider = FutureProvider.autoDispose
    .family<B05ExerciseEducationModel, B05ExerciseEducationQuery>((
      ref,
      query,
    ) async {
      final personal = await ref.watch(
        exercisePreferenceAggregateProvider(query.lookup).future,
      );
      final mapping = query.stableExerciseId == null
          ? null
          : await ref.watch(
              b05ExerciseMuscleMappingProvider(query.stableExerciseId!).future,
            );
      final cues = _cleanLines(query.catalogueCues);
      return B05ExerciseEducationModel(
        exerciseName: query.exerciseName,
        stableExerciseId: query.stableExerciseId,
        catalogueCues: cues,
        catalogueMistakes: _cleanLines(query.catalogueMistakes),
        personalCues: [
          for (final cue
              in personal?.personalCues ?? const <ExercisePersonalCue>[])
            cue.cueText.trim(),
        ].where((cue) => cue.isNotEmpty).toList(growable: false),
        checklist: B05ExerciseEducationCatalog().checklist(
          exerciseName: query.exerciseName,
          catalogueCues: cues,
        ),
        muscles: B05MuscleLabelMapper().map(mapping),
      );
    });

class B05ExerciseEducationQuery {
  final String exerciseName;
  final String? stableExerciseId;
  final List<String> catalogueCues;
  final List<String> catalogueMistakes;

  B05ExerciseEducationQuery({
    required this.exerciseName,
    required this.stableExerciseId,
    required this.catalogueCues,
    required this.catalogueMistakes,
  });

  ExercisePreferenceLookup get lookup => stableExerciseId == null
      ? ExercisePreferenceLookup.unresolved(exerciseName)
      : ExercisePreferenceLookup.stable(stableExerciseId!);

  @override
  bool operator ==(Object other) =>
      other is B05ExerciseEducationQuery &&
      other.exerciseName == exerciseName &&
      other.stableExerciseId == stableExerciseId &&
      _same(other.catalogueCues, catalogueCues) &&
      _same(other.catalogueMistakes, catalogueMistakes);

  @override
  int get hashCode => Object.hash(
    exerciseName,
    stableExerciseId,
    Object.hashAll(catalogueCues),
    Object.hashAll(catalogueMistakes),
  );

  static bool _same(List<String> a, List<String> b) =>
      a.length == b.length &&
      a.asMap().entries.every((entry) => entry.value == b[entry.key]);
}

List<String> _cleanLines(Iterable<String> values) => [
  for (final value in values)
    if (value.trim().isNotEmpty) value.trim(),
];

/// B05 exercise detail education panel. It intentionally contains no media
/// requirement; the text, checklist and muscle list remain useful offline.
class B05ExerciseEducationPanel extends ConsumerStatefulWidget {
  final String exerciseName;
  final String? stableExerciseId;
  final List<String> catalogueCues;
  final List<String> catalogueMistakes;

  const B05ExerciseEducationPanel({
    super.key,
    required this.exerciseName,
    required this.stableExerciseId,
    required this.catalogueCues,
    required this.catalogueMistakes,
  });

  @override
  ConsumerState<B05ExerciseEducationPanel> createState() =>
      _B05ExerciseEducationPanelState();
}

class _B05ExerciseEducationPanelState
    extends ConsumerState<B05ExerciseEducationPanel> {
  final Set<String> _checked = <String>{};

  @override
  Widget build(BuildContext context) {
    final query = B05ExerciseEducationQuery(
      exerciseName: widget.exerciseName,
      stableExerciseId: widget.stableExerciseId,
      catalogueCues: widget.catalogueCues,
      catalogueMistakes: widget.catalogueMistakes,
    );
    final state = ref.watch(b05ExerciseEducationProvider(query));
    final visualRegistry = ref.watch(b05MuscleVisualRegistryProvider);
    return Semantics(
      container: true,
      label: 'Exercise education',
      child: B05Surface(
        radius: B05SurfaceRadius.medium,
        child: state.when(
          loading: () => const B05StatusMessage(
            status: B05SemanticStatus.info,
            label: 'Loading exercise education',
          ),
          error: (_, _) => const B05StatusMessage(
            status: B05SemanticStatus.unavailable,
            label: 'Exercise education is unavailable',
            value: 'Try again later.',
          ),
          data: (model) => _buildContent(context, model, visualRegistry),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    B05ExerciseEducationModel model,
    B05MuscleVisualRegistry? visualRegistry,
  ) {
    return Material(
      type: MaterialType.transparency,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Text(
                'Exercise education',
                style: B05Typography.title(context),
              ),
            ),
            const SizedBox(height: B05Layout.space12),
            _sectionHeading(context, 'Form checklist'),
            ...model.checklist.map((item) => _checklistRow(context, item)),
            const SizedBox(height: B05Layout.space12),
            _sectionHeading(context, 'Catalogue guidance'),
            if (model.catalogueCues.isEmpty)
              Text(
                'No catalogue cues are packaged for this exercise.',
                style: B05Typography.body(context),
              )
            else
              ...model.catalogueCues.map((cue) => _bullet(context, cue)),
            if (model.catalogueMistakes.isNotEmpty) ...[
              const SizedBox(height: B05Layout.space8),
              Text(
                'Common mistakes to notice',
                style: B05Typography.label(context),
              ),
              ...model.catalogueMistakes.map(
                (mistake) => _bullet(context, mistake, danger: true),
              ),
            ],
            const SizedBox(height: B05Layout.space12),
            _sectionHeading(context, 'Your personal cues'),
            if (model.personalCues.isEmpty)
              Text(
                'No personal cues saved for this exercise.',
                style: B05Typography.body(context),
              )
            else
              ...model.personalCues.map(
                (cue) => _bullet(context, cue, personal: true),
              ),
            const SizedBox(height: B05Layout.space12),
            B05ExerciseMediaPanel(
              exerciseId: model.stableExerciseId,
              textFallback: model.checklist
                  .map((item) => item.label)
                  .toList(growable: false),
            ),
            const SizedBox(height: B05Layout.space12),
            _sectionHeading(context, 'Muscle contribution'),
            if (model.muscles.isUnknown && model.muscles.labels.isEmpty)
              const B05StatusMessage(
                status: B05SemanticStatus.unavailable,
                label: 'Muscle contribution is unknown',
                value:
                    'No reviewed B02 mapping is available for this exercise.',
              )
            else ...[
              if (model.muscles.isUnknown)
                const B05StatusMessage(
                  status: B05SemanticStatus.warning,
                  label: 'Some muscle contributions are unknown',
                  value: 'Known reviewed B02 labels are shown below.',
                ),
              ...B02MuscleRole.values.map((role) {
                final labels = model.muscles
                    .forRole(role)
                    .toList(growable: false);
                if (labels.isEmpty) return const SizedBox.shrink();
                return _muscleRoleGroup(context, role, labels);
              }),
              ...model.muscles.labels
                  .where((label) => label.role == null)
                  .map((label) => _unknownMuscleLabel(context, label)),
            ],
            const SizedBox(height: B05Layout.space12),
            B05InteractiveMuscleDiagram(
              muscles: model.muscles,
              visualRegistry: visualRegistry,
            ),
          ],
        ),
      ),
    );
  }

  Widget _checklistRow(BuildContext context, B05ExerciseChecklistItem item) {
    final checked = _checked.contains(item.id);
    return Semantics(
      container: true,
      label: item.label,
      value: checked ? 'Checked' : 'Not checked',
      checked: checked,
      onTap: () => setState(() {
        if (checked) {
          _checked.remove(item.id);
        } else {
          _checked.add(item.id);
        }
      }),
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        value: checked,
        onChanged: (value) => setState(() {
          if (value == true) {
            _checked.add(item.id);
          } else {
            _checked.remove(item.id);
          }
        }),
        title: Text(item.label, style: B05Typography.body(context)),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _sectionHeading(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.only(bottom: B05Layout.space4),
    child: Text(label, style: B05Typography.label(context)),
  );

  Widget _bullet(
    BuildContext context,
    String value, {
    bool danger = false,
    bool personal = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: B05Layout.space4),
    child: Semantics(
      container: true,
      label: '${personal ? 'Personal cue' : 'Catalogue cue'}: $value',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            personal ? Icons.person_outline : Icons.check_circle_outline,
            size: B05Layout.iconSmall,
            color: danger
                ? context.b05Colors.status(B05SemanticStatus.warning).indicator
                : context.b05Colors.action,
          ),
          const SizedBox(width: B05Layout.space8),
          Expanded(child: Text(value, style: B05Typography.body(context))),
        ],
      ),
    ),
  );

  Widget _muscleRoleGroup(
    BuildContext context,
    B02MuscleRole role,
    List<B05MuscleLabel> labels,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: B05Layout.space8),
    child: Semantics(
      container: true,
      label: '${role.dbValue} muscles',
      value: labels.map((label) => label.displayName).join(', '),
      child: Wrap(
        spacing: B05Layout.space8,
        runSpacing: B05Layout.space4,
        children: [
          Text('${_title(role.dbValue)}:', style: B05Typography.label(context)),
          for (final label in labels)
            Chip(
              label: Text(label.displayName),
              avatar: const Icon(
                Icons.accessibility_new_outlined,
                size: B05Layout.iconSmall,
              ),
            ),
        ],
      ),
    ),
  );

  Widget _unknownMuscleLabel(BuildContext context, B05MuscleLabel label) =>
      Padding(
        padding: const EdgeInsets.only(bottom: B05Layout.space8),
        child: Semantics(
          container: true,
          label: 'Unknown muscle contribution',
          value: label.displayName,
          child: B05StatusMessage(
            status: B05SemanticStatus.unavailable,
            label: 'Unknown muscle contribution',
            value: label.displayName,
          ),
        ),
      );

  static String _title(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}
