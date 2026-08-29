import 'dart:io';

import 'package:indifit/features/media/r08_repdb_asset_pipeline.dart';

Future<void> main(List<String> arguments) async {
  final options = _options(arguments);
  if (options.containsKey('help')) {
    stdout.writeln(
      '''Usage: dart run tool/acquire_r08_repdb_assets.dart [options]

Options:
  --manifest=<path>     Provenance manifest (default: assets/third_party/asset_manifest.json)
  --output=<path>       Must be the managed output (default: assets/generated/repdb)
  --source-dir=<path>   Existing RepDB checkout at the pinned commit
  --dry-run             Validate and list approved files without writing bytes
  --no-strict           Allow pre-existing image files in the generated directory
''',
    );
    return;
  }

  try {
    final manifestPath =
        options['manifest'] ?? 'assets/third_party/asset_manifest.json';
    final outputPath = options['output'] ?? 'assets/generated/repdb';
    _requireManagedOutput(outputPath);
    final plan = R08RepDbAcquisitionPlan.fromManifestFile(manifestPath);
    stdout.writeln(
      'Pinned ${plan.source.repository}@${plan.source.immutableCommit}: '
      '${plan.expectedAssetSetCount} asset sets, ${plan.expectedFileCount} files.',
    );
    if (options.containsKey('dry-run')) {
      for (final item in plan.items) {
        stdout.writeln(
          '${item.asset.mediaRole}: ${item.asset.sourceRelativePath} -> '
          '${item.asset.localDestination}',
        );
      }
      return;
    }

    final sourceDir = options['source-dir'];
    if (sourceDir != null) {
      await _verifyPinnedCheckout(Directory(sourceDir));
    }
    final runner = R08RepDbAcquisitionRunner(plan);
    final report = await runner.acquire(
      outputDirectory: Directory(outputPath),
      strict: !options.containsKey('no-strict'),
      fetch: sourceDir == null
          ? _downloadFromPinnedSource
          : (item) => readR08RepDbCheckoutFile(Directory(sourceDir), item),
    );
    stdout.writeln('Acquisition complete: $report');
  } on Object catch (error) {
    stderr.writeln('R08-0.3 RepDB acquisition failed: $error');
    exitCode = 1;
  }
}

void _requireManagedOutput(String outputPath) {
  final requested = _withoutTrailingSeparators(
    Directory(outputPath).absolute.path,
  );
  final managed = _withoutTrailingSeparators(
    Directory(kR08RepDbGeneratedRoot).absolute.path,
  );
  if (requested != managed) {
    throw StateError(
      'RepDB acquisition output must be the managed generated directory '
      '$kR08RepDbGeneratedRoot; refusing $outputPath.',
    );
  }
}

String _withoutTrailingSeparators(String path) =>
    path.replaceFirst(RegExp(r'[/\\]+$'), '');

Future<void> _verifyPinnedCheckout(Directory checkout) async {
  if (!checkout.existsSync()) {
    throw StateError('RepDB checkout does not exist: ${checkout.path}');
  }
  final result = await Process.run('git', [
    '-C',
    checkout.path,
    'rev-parse',
    'HEAD',
  ]);
  if (result.exitCode != 0) {
    throw StateError('Unable to read RepDB checkout commit: ${result.stderr}');
  }
  final commit = '${result.stdout}'.trim();
  if (commit != kR08RepDbPinnedCommit) {
    throw StateError(
      'RepDB checkout is at $commit; expected $kR08RepDbPinnedCommit.',
    );
  }
}

Future<List<int>> _downloadFromPinnedSource(
  R08RepDbAcquisitionItem item,
) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(item.rawUri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw StateError(
        'Pinned RepDB source returned HTTP ${response.statusCode} for '
        '${item.asset.sourceRelativePath}.',
      );
    }
    return response.fold<List<int>>(<int>[], (bytes, chunk) {
      bytes.addAll(chunk);
      return bytes;
    });
  } finally {
    client.close(force: true);
  }
}

Map<String, String> _options(List<String> arguments) {
  final options = <String, String>{};
  for (final argument in arguments) {
    if (argument == '--dry-run') {
      options['dry-run'] = '';
    } else if (argument == '--no-strict') {
      options['no-strict'] = '';
    } else if (argument == '--help' || argument == '-h') {
      options['help'] = '';
    } else if (argument.startsWith('--') && argument.contains('=')) {
      final split = argument.substring(2).split('=');
      options[split.first] = split.sublist(1).join('=');
    } else {
      throw FormatException('Unknown argument: $argument');
    }
  }
  return options;
}
