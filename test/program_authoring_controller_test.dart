import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/features/program_authoring/program_authoring_controller.dart';

void main() {
  test(
    'authoring controller exposes edit, failure and recovery states',
    () async {
      final controller = ProgramAuthoringController();
      addTearDown(controller.dispose);

      expect(controller.state.status, ProgramAuthoringStatus.idle);
      controller.beginLoading();
      expect(controller.state.status, ProgramAuthoringStatus.loading);
      controller.markEdited();
      expect(controller.state.status, ProgramAuthoringStatus.partial);

      controller.markFailure(StateError('disk unavailable'));
      expect(controller.state.status, ProgramAuthoringStatus.failure);
      expect(controller.state.errorMessage, contains('load this right now'));
      controller.recover();
      expect(controller.state.status, ProgramAuthoringStatus.recovery);
      expect(controller.state.isBusy, isTrue);
    },
  );

  test(
    'run returns to ready after success and retains recovery after failure',
    () async {
      final controller = ProgramAuthoringController();
      addTearDown(controller.dispose);

      expect(await controller.run(() async => 42), 42);
      expect(controller.state.status, ProgramAuthoringStatus.idle);

      await expectLater(
        controller.run<int>(() async => throw StateError('write failed')),
        throwsA(isA<StateError>()),
      );
      expect(controller.state.status, ProgramAuthoringStatus.failure);
      expect(controller.state.errorMessage, contains('load this right now'));
    },
  );
}
