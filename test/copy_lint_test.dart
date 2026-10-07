// Copy lint (audit UX-04 / A-07): internal engineering words must not reach
// text people read. Scans string literals in UI code, ignoring identifiers,
// keys, interpolations and messages that are only thrown for developers.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Words from the audit's jargon list, matched as whole words, any case.
final _banned = <String, RegExp>{
  'Canonical': RegExp(r'\bcanonical\b', caseSensitive: false),
  'snapshot': RegExp(r'\bsnapshots?\b', caseSensitive: false),
  'contract': RegExp(r'\bcontracts?\b', caseSensitive: false),
  'archetype': RegExp(r'\barchetypes?\b', caseSensitive: false),
  'dual-basis': RegExp(r'dual-basis', caseSensitive: false),
  'bundled': RegExp(r'\bbundled\b', caseSensitive: false),
  'Kitchen AI': RegExp(r'kitchen ai', caseSensitive: false),
  '(<10s)': RegExp(r'\(<\s*10\s*s\)', caseSensitive: false),
  'External volume': RegExp(r'external volume', caseSensitive: false),
};

/// UI code outside `lib/features` whose strings people read.
const _extraUiFiles = [
  'lib/core/nutrition_legacy_read_models.dart',
  'lib/core/privacy/dpdp_consent_dialog.dart',
];

final _literal = RegExp(
  r"'(?:[^'\\\n]|\\.)*'"
  r'|"(?:[^"\\\n]|\\.)*"',
);
final _interpolation = RegExp(r'\$\{[^}]*\}|\$[A-Za-z_]\w*');

void main() {
  test('UI text uses plain words, not internal terms', () {
    final files = [
      ...Directory('lib/features')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.endsWith('.g.dart')),
      for (final path in _extraUiFiles) File(path),
    ];
    expect(files.length, greaterThan(100), reason: 'scan found the UI code');

    final violations = <String>[];
    for (final file in files) {
      violations.addAll(lintSource(file.path, file.readAsStringSync()));
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('the lint catches each banned term and ignores developer text', () {
    const source = '''
// A comment about the canonical snapshot contract is fine.
final a = 'Log Snapshot (<10s)';
final b = 'QUICK MEAL ARCHETYPES';
final c = 'Canonical nutrition snapshot';
final d = 'Extract dual-basis facts';
final e = 'Kitchen AI is down';
final f = 'shown on bundled rows';
final g = 'External volume';
final key = 'canonical::food';
final name = '\${slot.exerciseNameSnapshot} sets';
final ok = 'Squeeze at peak contraction';
void h() {
  throw StateError('Canonical activation created no workouts.');
}
''';
    final found = lintSource('sample.dart', source);
    // Lines 2 and 4 each hold two banned words.
    expect(found, hasLength(9), reason: found.join('\n'));
    expect(found.join('\n'), isNot(contains('canonical::food')));
    expect(found.join('\n'), isNot(contains('activation created')));
  });
}

/// Returns one line per banned word found in a UI string literal.
List<String> lintSource(String path, String source) {
  // Drop whole-line comments: their apostrophes would confuse the scan.
  final lines = source
      .split('\n')
      .map((line) => line.trimLeft().startsWith('//') ? '' : line)
      .toList();
  final text = lines.join('\n');
  final violations = <String>[];
  for (final match in _literal.allMatches(text)) {
    final visible = match
        .group(0)!
        .substring(1, match.group(0)!.length - 1)
        .replaceAll(_interpolation, ' ');
    // Keys, ids and route names have no spaces; UI text does.
    if (!visible.trim().contains(' ')) continue;
    if (_isThrownForDevelopers(text, match.start)) continue;
    for (final entry in _banned.entries) {
      if (entry.value.hasMatch(visible)) {
        final line = '\n'.allMatches(text.substring(0, match.start)).length + 1;
        violations.add('$path:$line uses "${entry.key}": ${match.group(0)}');
      }
    }
  }
  return violations;
}

/// True when the literal sits in a `throw` statement (a developer message,
/// never shown as UI copy).
bool _isThrownForDevelopers(String text, int literalStart) {
  final before = text.substring(0, literalStart);
  final statementStart = [
    before.lastIndexOf(';'),
    before.lastIndexOf('{\n'),
    before.lastIndexOf('}\n'),
  ].reduce((a, b) => a > b ? a : b);
  return RegExp(r'\bthrow\b').hasMatch(before.substring(statementStart + 1));
}
