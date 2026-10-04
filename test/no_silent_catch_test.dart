import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards against failures that disappear without a trace (P1 WS-C).
///
/// The `empty_catches` lint can't do this: it exempts a catch variable named
/// `_`, which is how every silent catch in this codebase was written. Rules:
/// - a `catch` (or `on Type`) block may not do nothing. Log the error,
///   surface it, or explain why it is safe with a `// Safe: <reason>` comment
///   inside the block. Any other comment alone doesn't count;
/// - a no-op `catchError((_) {})` needs a `// Safe: <reason>` comment on one
///   of the three lines above it.
void main() {
  test('no unexplained silent catches in lib/', () {
    // A catch clause whose body holds nothing but whitespace and comments.
    final silentCatch = RegExp(
      r'(?:catch\s*\([^)]*\)|\}\s*on\s+\w+(?:<[^>]*>)?)\s*\{((?:\s*//[^\n]*)*)\s*\}',
    );
    final noOpCatchError = RegExp(
      r'catchError\(\s*\(\s*\w*\s*\)\s*(\{\s*\}|=>\s*null)\s*\)',
    );
    final violations = <String>[];

    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));
    for (final file in files) {
      final source = file.readAsStringSync();
      int lineOf(int offset) =>
          '\n'.allMatches(source.substring(0, offset)).length + 1;
      final lines = source.split('\n');

      for (final match in silentCatch.allMatches(source)) {
        if (match.group(1)!.contains('// Safe:')) continue;
        violations.add('${file.path}:${lineOf(match.start)} silent catch');
      }
      for (final match in noOpCatchError.allMatches(source)) {
        final line = lineOf(match.start);
        final context = lines.sublist((line - 4).clamp(0, lines.length), line);
        if (!context.any((l) => l.contains('// Safe:'))) {
          violations.add('${file.path}:$line no-op catchError');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Log the failure, surface it, or add a `// Safe: <reason>` comment.',
    );
  });
}
