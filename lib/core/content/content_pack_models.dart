/// Typed models for signed downloadable content packs (PV1-CONTENT-01A).
///
/// A pack is a versioned bundle of canonical content files (regional foods,
/// exercise metadata, starter plans) wrapped in an authenticity envelope.
/// This file defines shapes only; path validation, signature checks, and
/// activation policy live in `content_pack_validator.dart` and
/// `content_pack_registry.dart`. Pure Dart: no Flutter, database, or network.
library;

/// Content families a pack may carry. Each family has its own schema
/// pre-check; unknown families fail closed.
enum ContentPackKind {
  regionalFoods,
  exerciseMetadata,
  starterPlan,
}

/// A single file inside a pack: exact transfer bytes are hashed, so what is
/// verified is what gets staged — never a re-serialized approximation.
class ContentPackFile {
  final String path;
  final String sha256Hex;
  final int sizeBytes;
  final Object? json;

  const ContentPackFile({
    required this.path,
    required this.sha256Hex,
    required this.sizeBytes,
    this.json,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'sha256': sha256Hex,
        'size_bytes': sizeBytes,
        if (json != null) 'json': json,
      };

  factory ContentPackFile.fromJson(Map<String, dynamic> json) {
    final path = json['path'];
    final sha256Hex = json['sha256'];
    final sizeBytes = json['size_bytes'];
    if (path is! String || path.isEmpty) {
      throw const FormatException('Content pack file is missing path.');
    }
    if (sha256Hex is! String || sha256Hex.isEmpty) {
      throw const FormatException('Content pack file is missing sha256.');
    }
    if (sizeBytes is! int || sizeBytes < 0) {
      throw const FormatException('Content pack file has invalid size_bytes.');
    }
    return ContentPackFile(
      path: path,
      sha256Hex: sha256Hex,
      sizeBytes: sizeBytes,
      json: json['json'],
    );
  }
}

/// Authenticity envelope around a pack manifest.
///
/// `signatureHex` is HMAC-SHA256 over [signedPayload] with the pack-signing
/// key. Key distribution and rotation are an explicit later decision
/// (account-gate track); the validator takes the key as a parameter so no
/// default or embedded key can silently authenticate content.
class ContentPackEnvelope {
  final String packId;
  final ContentPackKind kind;
  final int version;
  final String minAppVersion;
  final DateTime issuedAtUtc;
  final List<ContentPackFile> files;
  final String signatureHex;

  const ContentPackEnvelope({
    required this.packId,
    required this.kind,
    required this.version,
    required this.minAppVersion,
    required this.issuedAtUtc,
    required this.files,
    required this.signatureHex,
  });

  /// Canonical payload covered by the signature: sorted keys, file entries
  /// in listed order, no signature field (which would be self-referential).
  Map<String, dynamic> signedPayload() => {
        'files': [for (final f in files) f.toJson()],
        'issued_at_utc': issuedAtUtc.toIso8601String(),
        'kind': kind.name,
        'min_app_version': minAppVersion,
        'pack_id': packId,
        'version': version,
      };

  Map<String, dynamic> toJson() => {
        ...signedPayload(),
        'signature': signatureHex,
      };

  factory ContentPackEnvelope.fromJson(Map<String, dynamic> json) {
    final packId = json['pack_id'];
    final kindRaw = json['kind'];
    final version = json['version'];
    final minAppVersion = json['min_app_version'];
    final issuedAtRaw = json['issued_at_utc'];
    final filesRaw = json['files'];
    final signatureHex = json['signature'];
    ContentPackKind? kind;
    for (final k in ContentPackKind.values) {
      if (k.name == kindRaw) kind = k;
    }
    if (packId is! String || packId.isEmpty) {
      throw const FormatException('Content pack is missing pack_id.');
    }
    if (kind == null) {
      throw FormatException('Unknown content pack kind: $kindRaw.');
    }
    if (version is! int || version <= 0) {
      throw const FormatException('Content pack has invalid version.');
    }
    if (minAppVersion is! String || minAppVersion.isEmpty) {
      throw const FormatException('Content pack is missing min_app_version.');
    }
    DateTime? issuedAt;
    if (issuedAtRaw is String) issuedAt = DateTime.tryParse(issuedAtRaw);
    if (issuedAt == null) {
      throw const FormatException('Content pack has invalid issued_at_utc.');
    }
    if (filesRaw is! List || filesRaw.isEmpty) {
      throw const FormatException('Content pack has no files.');
    }
    return ContentPackEnvelope(
      packId: packId,
      kind: kind,
      version: version,
      minAppVersion: minAppVersion,
      issuedAtUtc: issuedAt,
      files: [
        for (final entry in filesRaw)
          ContentPackFile.fromJson(
            Map<String, dynamic>.from(entry as Map),
          ),
      ],
      signatureHex: signatureHex is String ? signatureHex : '',
    );
  }
}

/// Compares `major.minor.patch` version strings numerically. Returns <0, 0,
// >0 like compareTo. Malformed segments compare as 0 (fail-open parsing is
/// contained by the caller, which treats incompatibility as rejection).
int compareAppVersions(String a, String b) {
  List<int> parts(String v) => v
      .split('.')
      .map((s) => int.tryParse(s.trim()) ?? 0)
      .toList();
  final pa = parts(a);
  final pb = parts(b);
  for (var i = 0; i < 3; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}
