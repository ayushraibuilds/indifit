import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../core/fixtures/b05_third_party_asset_manifest.dart';

const String kR08RepDbRepositoryUrl =
    'https://github.com/RepDB/exercise-dataset';
const String kR08RepDbPinnedCommit = '045845b61e4aefd9e684fa84518b84c665ea3cd3';
const String kR08RepDbGeneratedRoot = 'assets/generated/repdb/';
// Source-level approval deliberately remains candidate because public-repo
// redistribution is unresolved. File-level `production` rows mean approved
// for this local/private acquisition path only.
const String kR08RepDbSourceApprovalStatus =
    'pinned_candidate_assets_not_approved';
const String kR08RepDbTechniqueDisclosure =
    'This illustration represents the underlying movement and equipment. It is not an exact demonstration of pause duration, tempo, or other IndiFit technique prescriptions. Follow the IndiFit cues and set prescription for technique details.';

class R08RepDbAcquisitionItem {
  final B05ThirdPartyAssetContract asset;

  const R08RepDbAcquisitionItem(this.asset);

  String get relativeOutputPath {
    final destination = asset.localDestination;
    if (!destination.startsWith(kR08RepDbGeneratedRoot)) {
      throw StateError(
        'RepDB asset ${asset.assetKey} has no managed generated destination.',
      );
    }
    return destination.substring(kR08RepDbGeneratedRoot.length);
  }

  Uri get rawUri => Uri.parse(
    'https://raw.githubusercontent.com/RepDB/exercise-dataset/'
    '$kR08RepDbPinnedCommit/${asset.sourceRelativePath}',
  );
}

class R08RepDbAcquisitionPlan {
  final B05ThirdPartySourceContract source;
  final List<R08RepDbAcquisitionItem> items;

  const R08RepDbAcquisitionPlan({required this.source, required this.items});

  int get expectedFileCount => items.length;

  int get expectedAssetSetCount => items
      .map((item) => item.asset.assetSetId)
      .whereType<String>()
      .toSet()
      .length;

  factory R08RepDbAcquisitionPlan.fromManifest(
    B05ThirdPartyAssetManifest manifest,
  ) {
    manifest.validateStructure();
    final source = manifest.sources.singleWhere(
      (candidate) => candidate.sourceKey == 'repdb_free_tier',
      orElse: () => throw StateError('RepDB source is missing from manifest.'),
    );
    if (source.immutableCommit != kR08RepDbPinnedCommit || !source.isPinned) {
      throw StateError(
        'RepDB acquisition requires pinned commit $kR08RepDbPinnedCommit.',
      );
    }
    if (source.repository != kR08RepDbRepositoryUrl ||
        source.usageClassification != 'production_candidate' ||
        source.approvalStatus != kR08RepDbSourceApprovalStatus) {
      throw StateError('RepDB source provenance is not production-eligible.');
    }

    final items = <R08RepDbAcquisitionItem>[];
    for (final asset in manifest.assets) {
      if (asset.sourceKey != source.sourceKey ||
          asset.approvalStatus != 'production') {
        continue;
      }
      final path = asset.sourceRelativePath.replaceAll('\\', '/');
      final lowerPath = path.toLowerCase();
      if (!path.endsWith('.webp') ||
          lowerPath.contains('premium-samples') ||
          lowerPath.contains('premium') ||
          lowerPath.contains('animation') ||
          lowerPath.contains('preview')) {
        throw StateError(
          'RepDB acquisition refuses non-free or non-static source path $path.',
        );
      }
      if (asset.pinnedExternalExerciseId == null ||
          asset.pinnedExternalExerciseId != asset.sourceAssetId ||
          asset.assetSetId == null ||
          asset.approvalRecordId == null ||
          asset.techniqueDisclosure?.text != kR08RepDbTechniqueDisclosure) {
        throw StateError(
          'RepDB asset ${asset.assetKey} is missing approved asset-set provenance.',
        );
      }
      final destination = asset.localDestination;
      if (!destination.startsWith(kR08RepDbGeneratedRoot) ||
          destination.contains('..') ||
          !destination.endsWith('.webp')) {
        throw StateError(
          'RepDB asset ${asset.assetKey} has an unsafe generated destination.',
        );
      }
      items.add(R08RepDbAcquisitionItem(asset));
    }
    if (items.isEmpty) {
      throw StateError(
        'Manifest contains no approved RepDB acquisition items.',
      );
    }
    final destinations = items.map((item) => item.relativeOutputPath).toSet();
    if (destinations.length != items.length) {
      throw StateError(
        'RepDB acquisition plan contains duplicate destinations.',
      );
    }
    return R08RepDbAcquisitionPlan(
      source: source,
      items: List.unmodifiable(items),
    );
  }

  static R08RepDbAcquisitionPlan fromManifestFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError('Missing provenance manifest $path.');
    }
    return R08RepDbAcquisitionPlan.fromManifest(
      B05ThirdPartyAssetManifest.fromJson(jsonDecode(file.readAsStringSync())),
    );
  }
}

class R08RepDbAcquisitionReport {
  final int fileCount;
  final int totalBytes;
  final int minBytes;
  final int medianBytes;
  final int p95Bytes;
  final int maxBytes;

  const R08RepDbAcquisitionReport({
    required this.fileCount,
    required this.totalBytes,
    required this.minBytes,
    required this.medianBytes,
    required this.p95Bytes,
    required this.maxBytes,
  });

  @override
  String toString() =>
      'files=$fileCount total_bytes=$totalBytes min=$minBytes '
      'median=$medianBytes p95=$p95Bytes max=$maxBytes';
}

typedef R08RepDbBytesFetcher =
    Future<List<int>> Function(R08RepDbAcquisitionItem item);

class R08RepDbAcquisitionRunner {
  final R08RepDbAcquisitionPlan plan;

  const R08RepDbAcquisitionRunner(this.plan);

  Future<R08RepDbAcquisitionReport> acquire({
    required Directory outputDirectory,
    required R08RepDbBytesFetcher fetch,
    bool strict = true,
  }) async {
    if (strict) _rejectUnexpectedFiles(outputDirectory);
    await outputDirectory.create(recursive: true);
    final sizes = <int>[];
    for (final item in plan.items) {
      final bytes = Uint8List.fromList(await fetch(item));
      _verifyChecksum(item, bytes);
      final output = File(
        '${outputDirectory.path}${Platform.pathSeparator}${item.relativeOutputPath}',
      );
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes, flush: true);
      sizes.add(bytes.length);
    }
    return _report(sizes);
  }

  void _rejectUnexpectedFiles(Directory outputDirectory) {
    if (!outputDirectory.existsSync()) return;
    final expected = plan.items.map((item) => item.relativeOutputPath).toSet();
    final unexpected = <String>[];
    for (final entity in outputDirectory.listSync(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final relative = entity.path
          .substring(outputDirectory.path.length)
          .replaceAll('\\', '/')
          .replaceFirst(RegExp(r'^/'), '');
      final extension = relative.toLowerCase().split('.').last;
      if ({
            'webp',
            'png',
            'jpg',
            'jpeg',
            'gif',
            'avif',
            'mp4',
            'webm',
          }.contains(extension) &&
          !expected.contains(relative)) {
        unexpected.add(relative);
      }
    }
    if (unexpected.isNotEmpty) {
      unexpected.sort();
      throw StateError(
        'Unexpected RepDB asset(s) in managed directory: ${unexpected.join(', ')}',
      );
    }
  }

  static void _verifyChecksum(R08RepDbAcquisitionItem item, List<int> bytes) {
    final actual = 'sha256:${sha256.convert(bytes)}';
    if (actual.toLowerCase() != item.asset.checksum.toLowerCase()) {
      throw StateError(
        'SHA-256 mismatch for ${item.asset.assetKey}: expected '
        '${item.asset.checksum}, got $actual.',
      );
    }
  }

  static R08RepDbAcquisitionReport _report(List<int> sizes) {
    if (sizes.isEmpty) throw StateError('Cannot report an empty acquisition.');
    final ordered = [...sizes]..sort();
    final p95Index = math.max(0, (ordered.length * 0.95).ceil() - 1);
    return R08RepDbAcquisitionReport(
      fileCount: ordered.length,
      totalBytes: ordered.fold(0, (total, size) => total + size),
      minBytes: ordered.first,
      medianBytes: ordered[ordered.length ~/ 2],
      p95Bytes: ordered[p95Index],
      maxBytes: ordered.last,
    );
  }
}

Future<List<int>> readR08RepDbCheckoutFile(
  Directory checkout,
  R08RepDbAcquisitionItem item,
) async {
  final path =
      '${checkout.path}${Platform.pathSeparator}'
      '${item.asset.sourceRelativePath.replaceAll('/', Platform.pathSeparator)}';
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError(
      'Missing approved source file ${item.asset.sourceRelativePath}.',
    );
  }
  return file.readAsBytes();
}
