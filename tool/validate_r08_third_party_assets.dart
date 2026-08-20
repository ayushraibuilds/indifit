import 'dart:io';

import 'package:indifit/core/fixtures/b05_third_party_asset_manifest.dart';
import 'package:indifit/core/fixtures/exercise_identity_fixtures.dart';

const _defaultManifestPath = 'assets/third_party/asset_manifest.json';
const _defaultExercisePath = 'assets/data/exercises.json';

void main(List<String> arguments) {
  final manifestPath = arguments.isEmpty ? _defaultManifestPath : arguments[0];
  final manifestFile = File(manifestPath);
  if (!manifestFile.existsSync()) {
    stderr.writeln('Missing third-party manifest: $manifestPath');
    exitCode = 1;
    return;
  }

  try {
    final manifest = B05ThirdPartyAssetManifest.fromJsonString(
      manifestFile.readAsStringSync(),
    );
    final exerciseManifest = ExerciseCatalogManifest.loadFromAssetFileSync(
      _defaultExercisePath,
    );
    final repositoryFiles = _repositoryFiles(manifest);
    final licenseBytes = <String, List<int>>{};
    for (final path in repositoryFiles) {
      final file = File(path);
      if (file.existsSync()) {
        licenseBytes[path] = file.readAsBytesSync();
      }
    }
    final assetBytes = <String, List<int>>{};
    for (final asset in manifest.assets) {
      final file = File(asset.localDestination);
      if (file.existsSync()) {
        assetBytes[asset.localDestination] = file.readAsBytesSync();
      }
    }
    final productionFiles = <String>{};
    for (final root in manifest.managedProductionRoots) {
      final directory = Directory(root);
      if (!directory.existsSync()) {
        continue;
      }
      for (final entity in directory.listSync(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          productionFiles.add(entity.path.replaceAll('\\', '/'));
        }
      }
    }

    const B05ThirdPartyAssetManifestValidator().validate(
      manifest,
      B05ThirdPartyAssetValidationInput(
        canonicalExerciseUuids: {
          for (final exercise in exerciseManifest.allEntries) exercise.uuid,
        },
        repositoryFiles: repositoryFiles,
        licenseBytes: licenseBytes,
        assetBytes: assetBytes,
        managedProductionFiles: productionFiles,
      ),
    );
    stdout.writeln(
      'Validated ${manifest.sources.length} sources and '
      '${manifest.assets.length} assets in ${manifest.manifestId}.',
    );
  } on Object catch (error) {
    stderr.writeln('Third-party asset manifest validation failed: $error');
    exitCode = 1;
  }
}

Set<String> _repositoryFiles(B05ThirdPartyAssetManifest manifest) {
  final paths = <String>{};
  for (final source in manifest.sources) {
    for (final license in [
      source.sourceCodeLicense,
      ...source.contentLicenses,
    ]) {
      final path = license.licenseFile;
      if (path != null && File(path).existsSync()) paths.add(path);
    }
  }
  return paths;
}
