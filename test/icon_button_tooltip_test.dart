// Icon-only buttons need a name (audit UX-14): without a tooltip,
// VoiceOver and TalkBack announce just "button". IconButton uses its tooltip
// as the semantic label, so every IconButton in lib/ must set one.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _iconButton = RegExp(r'\bIconButton(?:\.\w+)?\(');

/// "path:line" for each IconButton in [source] without a `tooltip:`.
List<String> untooltippedIconButtons(String path, String source) {
  final found = <String>[];
  for (final match in _iconButton.allMatches(source)) {
    var depth = 1;
    var i = match.end;
    while (depth > 0 && i < source.length) {
      final char = source[i];
      if (char == '(') depth++;
      if (char == ')') depth--;
      i++;
    }
    if (!source.substring(match.start, i).contains('tooltip:')) {
      final line = '\n'.allMatches(source.substring(0, match.start)).length;
      found.add('$path:${line + 1}');
    }
  }
  return found;
}

void main() {
  test('every IconButton has a tooltip', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('.g.dart'))
        .toList();
    expect(files.length, greaterThan(100), reason: 'scan found the UI code');

    final missing = [
      for (final file in files)
        ...untooltippedIconButtons(file.path, file.readAsStringSync()),
    ];
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('the check sees through nested calls and named constructors', () {
    const source = '''
final a = IconButton(
  icon: const Icon(Icons.add),
  onPressed: () => add(foo(1)),
);
final b = IconButton.outlined(
  tooltip: 'Increase amount',
  icon: const Icon(Icons.add),
  onPressed: () {},
);
final c = IconButton.filled(icon: Icon(Icons.close), onPressed: close);
''';
    expect(untooltippedIconButtons('x.dart', source), [
      'x.dart:1',
      'x.dart:10',
    ]);
  });
}
