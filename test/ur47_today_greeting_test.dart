import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/features/dashboard/widgets/today_header_widgets.dart';

/// UR-47: the Today greeting stays on one line at 1.0× text, easing from
/// 22 pt to 19 pt and then ellipsising; two lines are allowed from 1.35×.
///
/// The test font draws every glyph one em wide, so widths here are in ems
/// ("Good evening, Arjun" is 19), not the app font's real widths.
void main() {
  Future<(Text, RenderParagraph)> pump(
    WidgetTester tester,
    String title, {
    required double width,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, child: TodayGreetingTitle(title)),
            ),
          ),
        ),
      ),
    );
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byType(TodayGreetingTitle),
        matching: find.byType(Text),
      ),
    );
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byType(TodayGreetingTitle),
        matching: find.byType(RichText),
      ),
    );
    return (text, paragraph);
  }

  testWidgets('full size when it fits', (tester) async {
    final (text, paragraph) = await pump(
      tester,
      'Good evening, Arjun',
      width: 19 * 22,
    );
    expect(text.style!.fontSize, 22);
    expect(text.maxLines, 1);
    expect(paragraph.didExceedMaxLines, isFalse);
  });

  testWidgets('a little smaller rather than wrapping', (tester) async {
    final (text, paragraph) = await pump(
      tester,
      'Good evening, Arjun',
      width: 19 * 20,
    );
    expect(text.style!.fontSize, 20);
    expect(text.maxLines, 1);
    expect(paragraph.didExceedMaxLines, isFalse);
  });

  testWidgets('a long name ellipsises at 19 pt on one line', (tester) async {
    final (text, paragraph) = await pump(
      tester,
      'Good evening, Venkatanarasimharajuvaripeta',
      width: 19 * 20,
    );
    expect(text.style!.fontSize, TodayGreetingTitle.smallestSize);
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(paragraph.size.height, lessThan(19 * 1.8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('from 1.35× text it may take two lines', (tester) async {
    final (text, _) = await pump(
      tester,
      'Good evening, Arjun',
      width: 19 * 20,
      textScale: 1.35,
    );
    expect(text.maxLines, 2);
    expect(text.style!.fontSize, TodayGreetingTitle.fullSize);
  });
}
