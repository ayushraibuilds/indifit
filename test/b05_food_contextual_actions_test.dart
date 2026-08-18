import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/features/food_log/food_contextual_action_controller.dart';
import 'package:indifit/features/food_log/food_contextual_actions.dart';
import 'package:indifit/features/food_log/food_log_surface.dart';
import 'package:indifit/features/food_log/meal_presentation_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // R07F-0: Outfit is bundled; no runtime font fetching configuration.

  test('meal registry maps stable IDs and leaves unknown values unknown', () {
    expect(
      foodMealPresentationFor('breakfast').category,
      FoodMealCategory.breakfast,
    );
    expect(foodMealPresentationFor('lunch').isKnown, isTrue);
    expect(foodMealPresentationFor('Dinner').stableId, 'dinner');
    expect(foodMealPresentationFor('morning meal').isKnown, isFalse);
    expect(foodMealPresentationFor(null).icon, Icons.restaurant_outlined);
  });

  test(
    'pending duplicate input is suppressed and supported undo calls gateway',
    () async {
      final gateway = _FakeGateway(log: _log())..supportsRestoreValue = true;
      final controller = FoodContextualActionController(
        gateway: gateway,
        source: _log(),
        nowUtc: () => DateTime.utc(2026, 8, 7, 12),
      );
      final gate = Completer<void>();
      gateway.deleteGate = gate;

      final first = controller.delete();
      final duplicate = controller.delete();
      expect(controller.state.status, FoodContextualActionStatus.pending);
      gate.complete();
      await Future.wait([first, duplicate]);

      expect(gateway.deleteCalls, 1);
      expect(controller.state.undoOffer, isNotNull);
      await controller.undo();
      expect(gateway.restoreCalls, 1);
      expect(controller.state.message, 'Food entry restored.');
    },
  );

  test('expired and unsupported undo remain unavailable', () async {
    var now = DateTime.utc(2026, 8, 7, 12);
    final supported = _FakeGateway(log: _log())..supportsRestoreValue = true;
    final controller = FoodContextualActionController(
      gateway: supported,
      source: _log(),
      nowUtc: () => now,
      undoWindow: const Duration(seconds: 2),
    );
    await controller.delete();
    now = now.add(const Duration(seconds: 3));
    await controller.undo();
    expect(controller.state.status, FoodContextualActionStatus.ready);
    expect(supported.restoreCalls, 0);

    final unsupported = _FakeGateway(log: _log());
    final unsupportedController = FoodContextualActionController(
      gateway: unsupported,
      source: _log(),
    );
    await unsupportedController.delete();
    expect(unsupportedController.state.undoOffer, isNull);
    await unsupportedController.undo();
    expect(
      unsupportedController.state.status,
      FoodContextualActionStatus.unavailable,
    );
  });

  test('failure exposes retry and retries the B03 gateway operation', () async {
    final gateway = _FakeGateway(log: _log())
      ..copyError = StateError('offline');
    final controller = FoodContextualActionController(
      gateway: gateway,
      source: _log(),
    );
    await controller.copy();
    expect(controller.state.status, FoodContextualActionStatus.failure);
    gateway.copyError = null;
    await controller.retry();
    expect(controller.state.status, FoodContextualActionStatus.success);
    expect(gateway.copyCalls, 2);
  });

  testWidgets('row exposes swipe and non-swipe actions at compact 2x text', (
    tester,
  ) async {
    final gateway = _FakeGateway(log: _log());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          foodContextualActionGatewayProvider.overrideWithValue(gateway),
        ],
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 720),
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: FoodContextualActions(log: _log()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('Edit food'), findsOneWidget);
    expect(find.bySemanticsLabel('Copy food'), findsOneWidget);
    expect(find.bySemanticsLabel('Delete food'), findsOneWidget);
    expect(
      tester.getSize(find.bySemanticsLabel('Delete food')).height,
      greaterThanOrEqualTo(48),
    );

    final dismissible = find.byType(Dismissible);
    await tester.fling(dismissible, const Offset(-260, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Edit food entry'), findsOneWidget);
    expect(find.bySemanticsLabel('Copy food entry'), findsOneWidget);
    expect(find.bySemanticsLabel('Delete food entry'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Copy food entry'));
    await tester.pump();
    expect(gateway.copyCalls, 1);
  });

  test('production food panel provider reads through FoodRepository', () async {
    final database = AppDatabase.memory();
    final repository = FoodRepository(database);
    final date = DateTime(2026, 8, 7);
    await repository.logFoodEntry(
      name: 'Oats',
      calories: 250,
      proteinG: 10,
      carbsG: 40,
      fatG: 5,
      servingLogged: 1,
      servingUnit: 'bowl',
      mealType: 'breakfast',
      loggedAt: date,
    );
    final container = ProviderContainer(
      overrides: [foodRepositoryProvider.overrideWithValue(repository)],
    );
    final rows = await container.read(foodLogsForDayProvider(date).future);
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Oats');
    container.dispose();
    await database.close();
  });

  test(
    'production action gateway delegates mutations to B03 repository',
    () async {
      final database = AppDatabase.memory();
      addTearDown(database.close);
      final repository = FoodRepository(database);
      final loggedAt = DateTime(2026, 8, 7, 8);
      await repository.logFoodEntry(
        name: 'Oats',
        calories: 250,
        proteinG: 10,
        carbsG: 40,
        fatG: 5,
        servingLogged: 1,
        servingUnit: 'bowl',
        mealType: 'breakfast',
        loggedAt: loggedAt,
      );
      final source = (await database.select(database.foodLogs).get()).single;
      final gateway = FoodRepositoryContextualActionGateway(repository);

      await gateway.edit(
        id: source.id,
        values: const FoodLogEditValues(
          name: 'Overnight oats',
          calories: 260,
          proteinG: 11,
          carbsG: 42,
          fatG: 5,
          servingLogged: 1,
        ),
      );
      expect(
        await database.select(database.nutritionUserCorrections).get(),
        hasLength(1),
      );

      await gateway.copy(
        source: source,
        targetDate: loggedAt,
        targetMealType: 'breakfast',
      );
      expect(await database.select(database.foodLogs).get(), hasLength(2));

      expect(gateway.supportsRestore, isFalse);
      expect(
        () => gateway.restore(source),
        throwsA(isA<FoodContextualUnavailableException>()),
      );
      await gateway.delete(source);
      expect(await database.select(database.foodLogs).get(), hasLength(1));
    },
  );
}

FoodLog _log() => FoodLog(
  id: 11,
  name: 'Oats',
  calories: 250,
  proteinG: 10,
  carbsG: 40,
  fatG: 5,
  servingLogged: 1,
  servingUnit: 'bowl',
  mealType: 'breakfast',
  loggedAt: DateTime.utc(2026, 8, 7, 8),
  isSynced: false,
);

class _FakeGateway implements FoodContextualActionGateway {
  _FakeGateway({required this.log});

  final FoodLog log;
  Completer<void>? deleteGate;
  Object? copyError;
  var supportsRestoreValue = false;
  var deleteCalls = 0;
  var restoreCalls = 0;
  var copyCalls = 0;

  @override
  Future<void> edit({
    required int id,
    required FoodLogEditValues values,
  }) async {}

  @override
  Future<void> copy({
    required FoodLog source,
    required DateTime targetDate,
    required String targetMealType,
  }) async {
    copyCalls++;
    final error = copyError;
    if (error != null) throw error;
  }

  @override
  Future<void> delete(FoodLog source) async {
    deleteCalls++;
    final gate = deleteGate;
    if (gate != null) {
      await gate.future;
      deleteGate = null;
    }
  }

  @override
  bool get supportsRestore => supportsRestoreValue;

  @override
  Future<void> restore(FoodLog source) async {
    restoreCalls++;
  }
}
