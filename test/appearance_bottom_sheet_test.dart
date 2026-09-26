import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/theme_provider.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/features/dashboard/widgets/appearance_bottom_sheet.dart';
import 'package:indifit/features/dashboard/widgets/today_module_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestApp({
    ThemeMode initialMode = ThemeMode.system,
    required Widget child,
  }) {
    return ProviderScope(
      overrides: [
        themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          final mode = ref.watch(themeModeProvider);
          return MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: mode,
            home: Scaffold(body: child),
          );
        },
      ),
    );
  }

  testWidgets('AppearanceBottomSheet renders 3 preview options and switches theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => AppearanceBottomSheet.show(context),
            child: const Text('Open Appearance'),
          ),
        ),
      ),
    );

    // Open sheet
    await tester.tap(find.text('Open Appearance'));
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Choose how IndiFit looks on your device'), findsOneWidget);
    expect(find.text('System default'), findsOneWidget);
    expect(find.text('Light mode'), findsOneWidget);
    expect(find.text('Dark mode'), findsOneWidget);

    // Tap Dark mode
    await tester.tap(find.text('Dark mode'));
    await tester.pumpAndSettle();

    // Verify dark mode selection is indicated
    final element = tester.element(find.byType(AppearanceBottomSheet));
    final container = ProviderScope.containerOf(element);
    expect(container.read(themeModeProvider), ThemeMode.dark);

    // Tap Light mode
    await tester.tap(find.text('Light mode'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), ThemeMode.light);

    // Tap System default
    await tester.tap(find.text('System default'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  testWidgets('TodayHeader displays theme toggle action button and triggers callback', (
    tester,
  ) async {
    var appearanceOpened = false;

    await tester.pumpWidget(
      buildTestApp(
        child: TodayHeader(
          userName: 'Alex',
          streakCount: 5,
          selectedDate: DateTime(2026, 9, 22),
          referenceNow: DateTime(2026, 9, 22),
          onOpenSettings: () {},
          onOpenAppearance: () {
            appearanceOpened = true;
          },
        ),
      ),
    );

    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsNothing);

    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await tester.pump();

    expect(appearanceOpened, isTrue);
  });
}
