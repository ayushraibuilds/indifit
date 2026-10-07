import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:indifit/core/di/health_provider.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/fixtures/b05_foundation_registry.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/health_service.dart';
import 'package:indifit/features/media/b05_playlist_launcher.dart';
import 'package:indifit/features/settings/settings_screen.dart';
import 'package:indifit/features/support/tip_jar_products.dart';
import 'package:indifit/features/support/tip_jar_screen.dart';
import 'package:indifit/features/support/tip_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  testWidgets('products render with store prices in tip order', (tester) async {
    final store = _FakeTipStore();
    await _pumpTipJar(tester, store);

    expect(find.text('Buy a chai'), findsOneWidget);
    expect(find.text('Chai and a snack'), findsOneWidget);
    expect(find.text('Buy a thali'), findsOneWidget);
    expect(find.text('₹49.00'), findsOneWidget);
    expect(find.text('₹99.00'), findsOneWidget);
    expect(find.text('₹199.00'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('₹49.00')).dy,
      lessThan(tester.getTopLeft(find.text('₹199.00')).dy),
    );
    expect(find.textContaining('never sees your card details'), findsOneWidget);
    expect(store.queriedIds, TipJarProducts.ids.toSet());
  });

  testWidgets('missing products show a friendly not-set-up message', (
    tester,
  ) async {
    final store = _FakeTipStore(products: const []);
    await _pumpTipJar(tester, store);

    expect(find.text('Tips aren’t set up yet'), findsOneWidget);
    expect(find.textContaining('check back later'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('an unavailable store says so and offers a retry', (
    tester,
  ) async {
    final store = _FakeTipStore(available: false);
    await _pumpTipJar(tester, store);

    expect(find.text('The store isn’t available'), findsOneWidget);
    expect(store.queriedIds, isNull);
  });

  testWidgets('a successful tip completes the purchase and shows thanks', (
    tester,
  ) async {
    final store = _FakeTipStore();
    await _pumpTipJar(tester, store);

    await tester.tap(find.text('₹99.00'));
    await tester.pump();
    expect(store.boughtIds, [TipJarProducts.medium]);
    expect(find.text('Opening the store'), findsOneWidget);

    store.emit(
      const TipPurchaseUpdate(
        productId: TipJarProducts.medium,
        status: TipPurchaseStatus.purchased,
        needsCompletion: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(store.completedIds, [TipJarProducts.medium]);
    expect(find.byType(TipThanksScreen), findsOneWidget);
    expect(find.text('Thank you for your support'), findsOneWidget);
    expect(find.textContaining('stays exactly the same'), findsOneWidget);
  });

  testWidgets('cancelling returns to the list without thanks', (tester) async {
    final store = _FakeTipStore();
    await _pumpTipJar(tester, store);

    await tester.tap(find.text('₹49.00'));
    await tester.pump();
    store.emit(
      const TipPurchaseUpdate(
        productId: TipJarProducts.small,
        status: TipPurchaseStatus.cancelled,
        needsCompletion: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TipThanksScreen), findsNothing);
    expect(find.text('No payment was made'), findsOneWidget);
    expect(find.text('₹49.00'), findsOneWidget);
    expect(store.completedIds, [TipJarProducts.small]);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '₹49.00'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('a pending payment shows a waiting state', (tester) async {
    final store = _FakeTipStore();
    await _pumpTipJar(tester, store);

    await tester.tap(find.text('₹199.00'));
    await tester.pump();
    store.emit(
      const TipPurchaseUpdate(
        productId: TipJarProducts.large,
        status: TipPurchaseStatus.pending,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Waiting for your payment'), findsOneWidget);
    expect(find.byType(TipThanksScreen), findsNothing);
    expect(store.completedIds, isEmpty);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '₹49.00'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('a store error shows plain copy and is still completed', (
    tester,
  ) async {
    final store = _FakeTipStore();
    await _pumpTipJar(tester, store);

    await tester.tap(find.text('₹49.00'));
    await tester.pump();
    store.emit(
      const TipPurchaseUpdate(
        productId: TipJarProducts.small,
        status: TipPurchaseStatus.error,
        needsCompletion: true,
        errorCode: 'purchase_error',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('The payment didn’t go through'), findsOneWidget);
    expect(find.textContaining('You can try again'), findsOneWidget);
    expect(find.textContaining('purchase_error'), findsNothing);
    expect(find.byType(TipThanksScreen), findsNothing);
    expect(store.completedIds, [TipJarProducts.small]);
  });

  testWidgets('a failed product query shows plain copy', (tester) async {
    final store = _FakeTipStore(queryError: StateError('billing down'));
    await _pumpTipJar(tester, store);

    expect(find.text('Couldn’t load tips'), findsOneWidget);
    expect(find.textContaining('billing down'), findsNothing);
  });

  testWidgets('Offline Mode never contacts the store', (tester) async {
    final store = _FakeTipStore();
    await _pumpTipJar(tester, store, offline: true);

    expect(find.text('Offline Mode is on'), findsOneWidget);
    expect(store.availabilityChecks, 0);
    expect(store.queriedIds, isNull);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('Settings shows Support IndiFit and opens the tip jar', (
    tester,
  ) async {
    final store = _FakeTipStore();
    await _pumpSettingsWithRouter(tester, store);

    final row = find.widgetWithText(ListTile, 'Support IndiFit');
    await tester.scrollUntilVisible(
      row,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Leave an optional tip'), findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.byType(TipJarScreen), findsOneWidget);
    expect(find.text('₹49.00'), findsOneWidget);
  });
}

class _FakeTipStore implements TipStore {
  _FakeTipStore({
    this.available = true,
    List<TipProduct>? products,
    this.queryError,
  }) : products =
           products ??
           const [
             // Deliberately out of order: the screen sorts by tip size.
             TipProduct(
               id: TipJarProducts.large,
               title: 'Large tip',
               price: '₹199.00',
             ),
             TipProduct(
               id: TipJarProducts.small,
               title: 'Small tip',
               price: '₹49.00',
             ),
             TipProduct(
               id: TipJarProducts.medium,
               title: 'Medium tip',
               price: '₹99.00',
             ),
           ];

  final bool available;
  final List<TipProduct> products;
  final Object? queryError;

  final _updates = StreamController<List<TipPurchaseUpdate>>.broadcast();
  int availabilityChecks = 0;
  Set<String>? queriedIds;
  final List<String> boughtIds = [];
  final List<String> completedIds = [];

  void emit(TipPurchaseUpdate update) => _updates.add([update]);

  @override
  Future<bool> isAvailable() async {
    availabilityChecks++;
    return available;
  }

  @override
  Future<TipProductQuery> queryProducts(Set<String> ids) async {
    queriedIds = ids;
    final error = queryError;
    if (error != null) throw error;
    return TipProductQuery(
      products: products,
      notFoundIds: products.isEmpty ? ids.toList() : const [],
    );
  }

  @override
  Stream<List<TipPurchaseUpdate>> get purchaseUpdates => _updates.stream;

  @override
  Future<bool> buy(String productId) async {
    boughtIds.add(productId);
    return true;
  }

  @override
  Future<void> complete(TipPurchaseUpdate update) async {
    completedIds.add(update.productId);
  }
}

Future<void> _pumpTipJar(
  WidgetTester tester,
  _FakeTipStore store, {
  bool offline = false,
}) async {
  SharedPreferences.setMockInitialValues({
    PrivacyPolicyNotifier.prefOfflineOnly: offline,
  });
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: TextButton(
            onPressed: () => context.push(tipJarRoutePath),
            child: const Text('Open tips'),
          ),
        ),
      ),
      GoRoute(
        path: tipJarRoutePath,
        builder: (context, state) => const TipJarScreen(),
      ),
      GoRoute(
        path: tipThanksRoutePath,
        builder: (context, state) => const TipThanksScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privacyPolicyProvider.overrideWith(
          (ref) => PrivacyPolicyNotifier(prefs),
        ),
        tipStoreProvider.overrideWithValue(store),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    ),
  );
  await tester.tap(find.text('Open tips'));
  await tester.pumpAndSettle();
}

Future<void> _pumpSettingsWithRouter(
  WidgetTester tester,
  _FakeTipStore store,
) async {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final database = AppDatabase.memory();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    unawaited(database.close());
  });
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: tipJarRoutePath,
        builder: (context, state) => const TipJarScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        healthStateProvider.overrideWith((ref) => _TestHealthNotifier()),
        b05PlaylistProviderRegistryProvider.overrideWithValue(
          B05PlaylistProviderRegistry(const []),
        ),
        privacyPolicyProvider.overrideWith(
          (ref) => PrivacyPolicyNotifier(prefs),
        ),
        tipStoreProvider.overrideWithValue(store),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

class _TestHealthNotifier extends HealthStateNotifier {
  _TestHealthNotifier() : super(HealthService()) {
    state = const HealthState(status: HealthStatus.notRequested);
  }

  @override
  Future<void> loadHealthData() async {}

  @override
  Future<void> refresh() async {}
}
