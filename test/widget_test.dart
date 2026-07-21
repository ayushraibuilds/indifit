import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:indifit/features/settings/settings_screen.dart';

void main() {
  // Disable runtime fetching of fonts in tests to prevent network exceptions
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('IndiFit Settings Screen render test', (WidgetTester tester) async {
    // Set mock initial values for SharedPreferences
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );
    
    // Wait for the async loading of SharedPreferences to complete and settle
    await tester.pumpAndSettle();

    // Verify that the SettingsScreen renders its options list
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
