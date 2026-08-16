import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/theme_provider.dart';
import 'package:indifit/core/theme/app_colors_extension.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4: Theme & Visual System Unit Tests', () {
    setUpAll(() {});

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      '1. ThemeModeNotifier initializes synchronously and supports light/dark/system persistence',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final notifier = ThemeModeNotifier(prefs);

        // Default when no key is set should be system mode
        expect(notifier.state, equals(ThemeMode.system));

        // Set light mode
        await notifier.setThemeMode(ThemeMode.light);
        expect(notifier.state, equals(ThemeMode.light));
        expect(prefs.getString(ThemeModeNotifier.prefKey), equals('light'));

        // Reload notifier from prefs synchronously
        final reloadedNotifier = ThemeModeNotifier(prefs);
        expect(reloadedNotifier.state, equals(ThemeMode.light));

        // Set dark mode
        await notifier.setThemeMode(ThemeMode.dark);
        expect(notifier.state, equals(ThemeMode.dark));
        expect(prefs.getString(ThemeModeNotifier.prefKey), equals('dark'));
      },
    );

    test(
      '2. AppTheme.lightTheme and AppTheme.darkTheme register AppColorsExtension',
      () {
        final darkTheme = AppTheme.darkTheme;
        final lightTheme = AppTheme.lightTheme;

        expect(darkTheme.brightness, equals(Brightness.dark));
        expect(lightTheme.brightness, equals(Brightness.light));

        final darkExt = darkTheme.extension<AppColorsExtension>();
        final lightExt = lightTheme.extension<AppColorsExtension>();

        expect(darkExt, isNotNull);
        expect(lightExt, isNotNull);

        expect(darkExt!.streakOrange, equals(const Color(0xFFFF7A00)));
        expect(lightExt!.streakOrange, equals(const Color(0xFFEA580C)));
        expect(darkExt.cardBackground, equals(const Color(0x1F111928)));
        expect(lightExt.cardBackground, equals(Colors.white));
      },
    );

    testWidgets(
      '3. BuildContext.appColors extension resolves correctly in widget tree',
      (tester) async {
        late AppColorsExtension resolvedExt;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            home: Builder(
              builder: (context) {
                resolvedExt = context.appColors;
                return const Scaffold(body: Text('Theme test'));
              },
            ),
          ),
        );

        expect(resolvedExt, isNotNull);
        expect(resolvedExt.cardBackground, equals(Colors.white));
      },
    );
  });
}
