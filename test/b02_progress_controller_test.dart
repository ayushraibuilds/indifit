import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/models/b02_muscle_volume_models.dart';
import 'package:indifit/data/models/b02_progress_read_models.dart';
import 'package:indifit/data/repositories/b02_progress_read_repository.dart';
import 'package:indifit/features/progress/b02_progress_controller.dart';

void main() {
  const query = B02ProgressQuery(
    startLocalDate: '2026-08-01',
    endLocalDate: '2026-08-07',
    timezoneId: 'UTC',
  );

  test('publishes ready only after all read components succeed', () async {
    final source = _FakeProgressSource();
    final controller = B02ProgressController(source);
    addTearDown(controller.dispose);

    expect(controller.state.status, B02ProgressStatus.loading);
    await controller.load(query);

    expect(controller.state.status, B02ProgressStatus.ready);
    expect(controller.state.data?.activityHistory, isEmpty);
    expect(controller.state.data?.groupHistory, isEmpty);
    expect(controller.state.data?.targetEvidence, isEmpty);
    expect(controller.state.data?.muscleVolume, isNotNull);
    expect(controller.state.issues, isEmpty);
  });

  test('keeps successful components and exposes partial failures', () async {
    final source = _FakeProgressSource()..failTargets = true;
    final controller = B02ProgressController(source);
    addTearDown(controller.dispose);

    await controller.load(query);

    expect(controller.state.status, B02ProgressStatus.partial);
    expect(controller.state.data?.activityHistory, isNotNull);
    expect(controller.state.data?.targetEvidence, isNull);
    expect(controller.state.issues.single, contains('Target evidence'));
  });

  test(
    'distinguishes initial failure from recovery of retained data',
    () async {
      final source = _FakeProgressSource();
      final controller = B02ProgressController(source);
      addTearDown(controller.dispose);

      await controller.load(query);
      source.failActivity = true;
      source.failGroups = true;
      source.failTargets = true;
      source.failMuscle = true;
      await controller.retry();

      expect(controller.state.status, B02ProgressStatus.recovery);
      expect(controller.state.data, isNotNull);
      expect(controller.state.issues, hasLength(4));

      final initialFailureSource = _FakeProgressSource()
        ..failActivity = true
        ..failGroups = true
        ..failTargets = true
        ..failMuscle = true;
      final initialFailure = B02ProgressController(initialFailureSource);
      addTearDown(initialFailure.dispose);
      await initialFailure.load(query);
      expect(initialFailure.state.status, B02ProgressStatus.failure);
      expect(initialFailure.state.data, isNull);
    },
  );
}

class _FakeProgressSource implements B02ProgressReadSource {
  bool failActivity = false;
  bool failGroups = false;
  bool failTargets = false;
  bool failMuscle = false;

  @override
  Future<List<B02ProgressActivityRecord>> readActivityHistory(
    B02ProgressQuery query,
  ) async {
    if (failActivity) throw StateError('offline activity');
    return const [];
  }

  @override
  Future<List<B02ProgressGroupHistory>> readGroupHistory(
    B02ProgressQuery query,
  ) async {
    if (failGroups) throw StateError('offline groups');
    return const [];
  }

  @override
  Future<List<B02ProgressTargetEvidence>> readTargetEvidence(
    B02ProgressQuery query,
  ) async {
    if (failTargets) throw StateError('offline targets');
    return const [];
  }

  @override
  Future<B02MuscleVolumeReadModel> readMuscleVolume(
    B02ProgressQuery query,
  ) async {
    if (failMuscle) throw StateError('offline muscle volume');
    return B02MuscleVolumeReadModel(
      startLocalDate: query.startLocalDate,
      endLocalDate: query.endLocalDate,
      timezoneId: query.timezoneId,
      startUtc: DateTime.utc(2026, 8, 1),
      endExclusiveUtc: DateTime.utc(2026, 8, 8),
      muscles: const [],
      unknown: const B02MuscleVolumeUnknown(
        workingSetUnits: 0,
        effectiveSetUnits: null,
        effectiveEvidenceUnits: 0,
        workingSetCount: 0,
      ),
      totalWorkingSetCount: 0,
      mappedWorkingSetCount: 0,
      mappedWorkingSetUnits: 0,
      mappedEffectiveSetUnits: null,
      totalEffectiveEvidenceUnits: 0,
    );
  }
}
