import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indifit/main.dart';

void main() {
  testWidgets('IndiFit App initial render smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: IndiFitApp(),
      ),
    );

    // Verify that the app is initialized without crashing
    expect(find.byType(IndiFitApp), findsOneWidget);
  });
}
