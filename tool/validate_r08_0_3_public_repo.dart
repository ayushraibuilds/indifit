import 'dart:io';

const _generatedRoot = 'assets/generated/repdb/';

// R08 deliberately keeps every WebP out of the public index. The synthetic
// test fixtures use PNG bytes, so this also catches a RepDB copy renamed into
// a review, test, or unrelated production directory.
Future<void> main() async {
  try {
    final tracked = await _gitFiles(['ls-files', '--cached']);
    final trackedWebPs = tracked
        .where((path) => path.toLowerCase().endsWith('.webp'))
        .toList(growable: false);
    final protectedTracked = trackedWebPs;
    if (protectedTracked.isNotEmpty) {
      throw StateError(
        'WebP bytes are Git-tracked; public R08 source must keep raw media '
        'out of Git: '
        '${protectedTracked.join(', ')}',
      );
    }

    final ignoredProbe = await Process.run('git', [
      'check-ignore',
      '--no-index',
      '-q',
      '${_generatedRoot}probe.webp',
    ]);
    if (ignoredProbe.exitCode != 0) {
      throw StateError(
        'The generated RepDB WebP ignore rule is missing or ineffective.',
      );
    }

    stdout.writeln(
      'Public-repository check passed: no tracked RepDB WebPs; '
      'generated WebPs are ignored.',
    );
  } on Object catch (error) {
    stderr.writeln('R08-0.3 public-repository check failed: $error');
    exitCode = 1;
  }
}

Future<List<String>> _gitFiles(List<String> arguments) async {
  final result = await Process.run('git', arguments);
  if (result.exitCode != 0) {
    throw StateError('Git file inspection failed: ${result.stderr}');
  }
  return '${result.stdout}'
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
}
