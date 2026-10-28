import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/plus/plus_gate.dart';

class _FakeEntitlement implements PlusEntitlement {
  const _FakeEntitlement(this.isActive);

  @override
  final bool isActive;
}

Future<void> _pump(WidgetTester tester, List<Override> overrides) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        home: Scaffold(body: PlusGate(child: Text('plus feature'))),
      ),
    ),
  );
}

void main() {
  test('the local stub never grants Plus', () {
    expect(const LocalPlusEntitlementStub().isActive, isFalse);
  });

  testWidgets('hidden by default', (tester) async {
    await _pump(tester, const []);
    expect(find.text('plus feature'), findsNothing);
  });

  testWidgets('hidden with the remote switch alone', (tester) async {
    await _pump(tester, [plusRemoteEnabledProvider.overrideWithValue(true)]);
    expect(find.text('plus feature'), findsNothing);
  });

  testWidgets('hidden with the entitlement alone', (tester) async {
    await _pump(tester, [
      plusEntitlementProvider.overrideWithValue(const _FakeEntitlement(true)),
      plusRemoteEnabledProvider.overrideWithValue(false),
    ]);
    expect(find.text('plus feature'), findsNothing);
  });

  testWidgets('shown only when both are true', (tester) async {
    await _pump(tester, [
      plusEntitlementProvider.overrideWithValue(const _FakeEntitlement(true)),
      plusRemoteEnabledProvider.overrideWithValue(true),
    ]);
    expect(find.text('plus feature'), findsOneWidget);
  });
}
