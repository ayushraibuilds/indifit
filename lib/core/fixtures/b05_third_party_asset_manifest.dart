import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'b05_foundation_registry.dart';

/// R08-0.1's single checked-in provenance authority.
///
/// Later B05 runtime media manifests must be generated from, or validated
/// against, this contract. They must not become a second independently edited
/// source of licensing, approval, or canonical-exercise bindings.
const int kB05ThirdPartyAssetManifestVersion = 2;

const Set<String> kB05ThirdPartyUsageClassifications = {
  'production_candidate',
  'reference_qa_only',
  'prohibited_production_content',
};

const Set<String> kB05ThirdPartyPinStatuses = {
  'pinned',
  'unavailable_at_acquisition',
};

const Set<String> kB05ThirdPartyLicenseStatuses = {
  'verified',
  'unverified',
  'not_applicable',
};

const Set<String> kB05ThirdPartyMediaRoles = {
  'start',
  'peak',
  'main',
  'geometry',
  'icon',
};

const Set<String> kB05ThirdPartyModificationStates = {
  'none',
  'resized',
  'cropped',
  'recolored',
  'converted',
};

const Set<String> kB05ThirdPartyAssetApprovalStatuses = {
  'candidate',
  'approved',
  'production',
  'rejected',
};

const Set<String> kB05ThirdPartyTechniqueDisclosureStatuses = {
  'underlying_movement_only',
};

final RegExp _immutableCommitPattern = RegExp(r'^[0-9a-f]{40}$');
final RegExp _sha256Pattern = RegExp(r'^sha256:[0-9a-f]{64}$');

class B05ThirdPartyLicenseScope {
  final String scope;
  final String name;
  final String version;
  final String status;
  final String? licenseFile;
  final String? licenseSha256;
  final String notes;

  const B05ThirdPartyLicenseScope({
    required this.scope,
    required this.name,
    required this.version,
    required this.status,
    required this.licenseFile,
    required this.licenseSha256,
    required this.notes,
  });

  factory B05ThirdPartyLicenseScope.fromJson(Object? raw) {
    final map = _object(raw, 'third_party_license');
    _keys(map, {
      'scope',
      'name',
      'version',
      'status',
      'license_file',
      'license_sha256',
      'notes',
    }, 'third_party_license');
    final status = _string(map, 'status');
    if (!kB05ThirdPartyLicenseStatuses.contains(status)) {
      throw B05RegistryValidationException(
        'third_party_license_status',
        'Unknown third-party license status: $status.',
      );
    }
    final licenseFile = _optionalString(map, 'license_file');
    final rawChecksum = _optionalString(map, 'license_sha256');
    if (licenseFile != null && rawChecksum == null) {
      throw B05RegistryValidationException(
        'third_party_license_missing_checksum',
        'License record with license_file $licenseFile requires a license_sha256 checksum.',
      );
    }
    if (licenseFile == null && rawChecksum != null) {
      throw B05RegistryValidationException(
        'third_party_license_unneeded_checksum',
        'License record without license_file must not specify license_sha256.',
      );
    }
    final checksum = rawChecksum?.toLowerCase();
    if (checksum != null && !_sha256Pattern.hasMatch(checksum)) {
      throw B05RegistryValidationException(
        'third_party_license_checksum_format',
        'License SHA-256 must use sha256:<64 lowercase hexadecimal characters>.',
      );
    }
    return B05ThirdPartyLicenseScope(
      scope: _string(map, 'scope'),
      name: _string(map, 'name'),
      version: _string(map, 'version'),
      status: status,
      licenseFile: licenseFile,
      licenseSha256: checksum,
      notes: _string(map, 'notes'),
    );
  }
}

class B05ThirdPartyAttributionContract {
  final bool required;
  final String text;
  final String? url;

  const B05ThirdPartyAttributionContract({
    required this.required,
    required this.text,
    required this.url,
  });

  factory B05ThirdPartyAttributionContract.fromJson(Object? raw) {
    final map = _object(raw, 'third_party_attribution');
    _keys(map, {'required', 'text', 'url'}, 'third_party_attribution');
    final required = map['required'];
    if (required is! bool) {
      throw B05RegistryValidationException(
        'third_party_attribution_required',
        'Attribution required must be a boolean.',
      );
    }
    final text = _string(map, 'text', allowEmpty: !required);
    final url = _optionalString(map, 'url');
    if (required && (text.isEmpty || !_isHttpsUrl(url))) {
      throw B05RegistryValidationException(
        'third_party_attribution_contract',
        'Required attribution needs exact text and an HTTPS URL.',
      );
    }
    return B05ThirdPartyAttributionContract(
      required: required,
      text: text,
      url: url,
    );
  }
}

class B05ThirdPartySourceContract {
  final String sourceKey;
  final String name;
  final String repository;
  final String? immutableCommit;
  final String? tag;
  final String pinStatus;
  final DateTime acquisitionDateUtc;
  final String usageClassification;
  final String approvalStatus;
  final B05ThirdPartyLicenseScope sourceCodeLicense;
  final List<B05ThirdPartyLicenseScope> contentLicenses;
  final B05ThirdPartyAttributionContract attribution;
  final List<String> permittedUse;
  final List<String> prohibitedUse;
  final List<String> redistributionConstraints;
  final List<String> modificationConstraints;
  final String intendedIndifitUsage;
  final List<String> openQuestions;

  const B05ThirdPartySourceContract({
    required this.sourceKey,
    required this.name,
    required this.repository,
    required this.immutableCommit,
    required this.tag,
    required this.pinStatus,
    required this.acquisitionDateUtc,
    required this.usageClassification,
    required this.approvalStatus,
    required this.sourceCodeLicense,
    required this.contentLicenses,
    required this.attribution,
    required this.permittedUse,
    required this.prohibitedUse,
    required this.redistributionConstraints,
    required this.modificationConstraints,
    required this.intendedIndifitUsage,
    required this.openQuestions,
  });

  bool get isPinned =>
      pinStatus == 'pinned' &&
      immutableCommit != null &&
      _immutableCommitPattern.hasMatch(immutableCommit!);

  factory B05ThirdPartySourceContract.fromJson(Object? raw) {
    final map = _object(raw, 'third_party_source');
    _keys(map, {
      'source_key',
      'name',
      'repository',
      'immutable_commit',
      'tag',
      'pin_status',
      'acquisition_date_utc',
      'usage_classification',
      'approval_status',
      'source_code_license',
      'content_licenses',
      'attribution',
      'permitted_use',
      'prohibited_use',
      'redistribution_constraints',
      'modification_constraints',
      'intended_indifit_usage',
      'open_questions',
    }, 'third_party_source');
    final repository = _string(map, 'repository');
    if (!_isHttpsUrl(repository)) {
      throw B05RegistryValidationException(
        'third_party_repository',
        'Third-party repository must be an absolute HTTPS URL.',
      );
    }
    final pinStatus = _string(map, 'pin_status');
    if (!kB05ThirdPartyPinStatuses.contains(pinStatus)) {
      throw B05RegistryValidationException(
        'third_party_pin_status',
        'Unknown source pin status: $pinStatus.',
      );
    }
    final commit = _optionalString(map, 'immutable_commit');
    if (pinStatus == 'pinned' &&
        (commit == null || !_immutableCommitPattern.hasMatch(commit))) {
      throw B05RegistryValidationException(
        'third_party_floating_revision',
        'Pinned sources require a full lowercase 40-character commit hash.',
      );
    }
    if (pinStatus != 'pinned' && commit != null) {
      throw B05RegistryValidationException(
        'third_party_pin_inconsistent',
        'Unavailable sources cannot declare an immutable commit.',
      );
    }
    final acquired = DateTime.tryParse(_string(map, 'acquisition_date_utc'));
    if (acquired == null || !acquired.isUtc) {
      throw B05RegistryValidationException(
        'third_party_acquisition_date',
        'Acquisition date must be a valid UTC timestamp.',
      );
    }
    final classification = _string(map, 'usage_classification');
    if (!kB05ThirdPartyUsageClassifications.contains(classification)) {
      throw B05RegistryValidationException(
        'third_party_usage_classification',
        'Unknown third-party usage classification: $classification.',
      );
    }
    final rawLicenses = map['content_licenses'];
    if (rawLicenses is! List || rawLicenses.isEmpty) {
      throw B05RegistryValidationException(
        'third_party_content_license',
        'Every source requires at least one content/data/media license record.',
      );
    }
    final source = B05ThirdPartySourceContract(
      sourceKey: _string(map, 'source_key'),
      name: _string(map, 'name'),
      repository: repository,
      immutableCommit: commit,
      tag: _optionalString(map, 'tag'),
      pinStatus: pinStatus,
      acquisitionDateUtc: acquired,
      usageClassification: classification,
      approvalStatus: _string(map, 'approval_status'),
      sourceCodeLicense: B05ThirdPartyLicenseScope.fromJson(
        map['source_code_license'],
      ),
      contentLicenses: List.unmodifiable(
        rawLicenses.map(B05ThirdPartyLicenseScope.fromJson),
      ),
      attribution: B05ThirdPartyAttributionContract.fromJson(
        map['attribution'],
      ),
      permittedUse: _stringList(map, 'permitted_use'),
      prohibitedUse: _stringList(map, 'prohibited_use'),
      redistributionConstraints: _stringList(map, 'redistribution_constraints'),
      modificationConstraints: _stringList(map, 'modification_constraints'),
      intendedIndifitUsage: _string(map, 'intended_indifit_usage'),
      openQuestions: _stringList(map, 'open_questions', allowEmpty: true),
    );
    if (classification == 'production_candidate' && !source.isPinned) {
      throw B05RegistryValidationException(
        'third_party_production_source_unpinned',
        'Production candidate sources must use immutable commits.',
      );
    }
    return source;
  }
}

class B05ThirdPartyAssetModification {
  final String state;
  final String details;

  const B05ThirdPartyAssetModification({
    required this.state,
    required this.details,
  });

  factory B05ThirdPartyAssetModification.fromJson(Object? raw) {
    final map = _object(raw, 'third_party_asset_modification');
    _keys(map, {'state', 'details'}, 'third_party_asset_modification');
    final state = _string(map, 'state');
    if (!kB05ThirdPartyModificationStates.contains(state)) {
      throw B05RegistryValidationException(
        'third_party_modification_state',
        'Unknown asset modification state: $state.',
      );
    }
    return B05ThirdPartyAssetModification(
      state: state,
      details: _string(map, 'details'),
    );
  }
}

class B05ThirdPartyTechniqueDisclosure {
  final String status;
  final String text;

  const B05ThirdPartyTechniqueDisclosure({
    required this.status,
    required this.text,
  });

  factory B05ThirdPartyTechniqueDisclosure.fromJson(Object? raw) {
    final map = _object(raw, 'third_party_technique_disclosure');
    _keys(map, {'status', 'text'}, 'third_party_technique_disclosure');
    final status = _string(map, 'status');
    if (!kB05ThirdPartyTechniqueDisclosureStatuses.contains(status)) {
      throw B05RegistryValidationException(
        'third_party_technique_disclosure_status',
        'Unknown technique disclosure status: $status.',
      );
    }
    return B05ThirdPartyTechniqueDisclosure(
      status: status,
      text: _string(map, 'text'),
    );
  }
}

class B05ThirdPartyAssetContract {
  final String assetKey;
  final String? assetSetId;
  final String sourceKey;
  final String sourceAssetId;
  final String? pinnedExternalExerciseId;
  final String sourceRelativePath;
  final String localDestination;
  final String checksum;
  final String mediaRole;
  final B05ThirdPartyAssetModification modification;
  final String approvalStatus;
  final String? approvalRecordId;
  final List<String> canonicalExerciseUuids;
  final B05ThirdPartyTechniqueDisclosure? techniqueDisclosure;

  const B05ThirdPartyAssetContract({
    required this.assetKey,
    required this.assetSetId,
    required this.sourceKey,
    required this.sourceAssetId,
    required this.pinnedExternalExerciseId,
    required this.sourceRelativePath,
    required this.localDestination,
    required this.checksum,
    required this.mediaRole,
    required this.modification,
    required this.approvalStatus,
    required this.approvalRecordId,
    required this.canonicalExerciseUuids,
    required this.techniqueDisclosure,
  });

  factory B05ThirdPartyAssetContract.fromJson(Object? raw) {
    final map = _object(raw, 'third_party_asset');
    _keys(map, {
      'asset_key',
      'asset_set_id',
      'source_key',
      'source_asset_id',
      'pinned_external_exercise_id',
      'source_relative_path',
      'local_destination',
      'sha256',
      'media_role',
      'modification',
      'approval_status',
      'approval_record_id',
      'canonical_exercise_uuids',
      'technique_disclosure',
    }, 'third_party_asset');
    final role = _string(map, 'media_role');
    if (!kB05ThirdPartyMediaRoles.contains(role)) {
      throw B05RegistryValidationException(
        'third_party_media_role',
        'Unknown third-party media role: $role.',
      );
    }
    final checksum = _string(map, 'sha256').toLowerCase();
    if (!_sha256Pattern.hasMatch(checksum)) {
      throw B05RegistryValidationException(
        'third_party_checksum_format',
        'Asset SHA-256 must use sha256:<64 lowercase hexadecimal characters>.',
      );
    }
    final approval = _string(map, 'approval_status');
    if (!kB05ThirdPartyAssetApprovalStatuses.contains(approval)) {
      throw B05RegistryValidationException(
        'third_party_asset_approval',
        'Unknown asset approval status: $approval.',
      );
    }
    final sourcePath = _relativePath(map, 'source_relative_path');
    final localPath = _relativePath(map, 'local_destination');
    return B05ThirdPartyAssetContract(
      assetKey: _string(map, 'asset_key'),
      assetSetId: _optionalString(map, 'asset_set_id'),
      sourceKey: _string(map, 'source_key'),
      sourceAssetId: _string(map, 'source_asset_id'),
      pinnedExternalExerciseId: _optionalString(
        map,
        'pinned_external_exercise_id',
      ),
      sourceRelativePath: sourcePath,
      localDestination: localPath,
      checksum: checksum,
      mediaRole: role,
      modification: B05ThirdPartyAssetModification.fromJson(
        map['modification'],
      ),
      approvalStatus: approval,
      approvalRecordId: _optionalString(map, 'approval_record_id'),
      canonicalExerciseUuids: _stringList(
        map,
        'canonical_exercise_uuids',
        allowEmpty: true,
      ),
      techniqueDisclosure: map['technique_disclosure'] == null
          ? null
          : B05ThirdPartyTechniqueDisclosure.fromJson(
              map['technique_disclosure'],
            ),
    );
  }
}

/// A reusable approved artwork set. It is derived from the file-level entries
/// in the single provenance manifest; it is not a second editable manifest.
class B05ThirdPartyVisualAssetSet {
  final String assetSetId;
  final String sourceKey;
  final String pinnedExternalExerciseId;
  final String? approvalRecordId;
  final List<String> canonicalExerciseUuids;
  final Map<String, B05ThirdPartyAssetContract> mediaByRole;
  final B05ThirdPartyTechniqueDisclosure techniqueDisclosure;

  const B05ThirdPartyVisualAssetSet({
    required this.assetSetId,
    required this.sourceKey,
    required this.pinnedExternalExerciseId,
    required this.approvalRecordId,
    required this.canonicalExerciseUuids,
    required this.mediaByRole,
    required this.techniqueDisclosure,
  });

  bool get isPosePair =>
      mediaByRole.keys.toSet().containsAll({'start', 'peak'}) &&
      mediaByRole.length == 2;

  bool get isMainOnly =>
      mediaByRole.length == 1 && mediaByRole.containsKey('main');

  B05ThirdPartyAssetContract? media(String role) => mediaByRole[role];
}

class B05ThirdPartyAssetManifest {
  final String manifestId;
  final List<String> managedProductionRoots;
  final List<B05ThirdPartySourceContract> sources;
  final List<B05ThirdPartyAssetContract> assets;

  const B05ThirdPartyAssetManifest({
    required this.manifestId,
    required this.managedProductionRoots,
    required this.sources,
    required this.assets,
  });

  List<B05ThirdPartyVisualAssetSet> get visualAssetSets {
    final grouped = <String, List<B05ThirdPartyAssetContract>>{};
    for (final asset in assets) {
      final setId = asset.assetSetId;
      if (setId == null) continue;
      (grouped[setId] ??= <B05ThirdPartyAssetContract>[]).add(asset);
    }
    return List.unmodifiable(
      grouped.entries.map((entry) {
        final files = entry.value;
        final first = files.first;
        return B05ThirdPartyVisualAssetSet(
          assetSetId: entry.key,
          sourceKey: first.sourceKey,
          pinnedExternalExerciseId:
              first.pinnedExternalExerciseId ?? first.sourceAssetId,
          approvalRecordId: first.approvalRecordId,
          canonicalExerciseUuids: List.unmodifiable(
            first.canonicalExerciseUuids,
          ),
          mediaByRole: Map.unmodifiable({
            for (final asset in files) asset.mediaRole: asset,
          }),
          techniqueDisclosure: first.techniqueDisclosure!,
        );
      }),
    );
  }

  factory B05ThirdPartyAssetManifest.fromJson(Object? raw) {
    final map = _object(raw, 'third_party_asset_manifest');
    _keys(map, {
      'contract_version',
      'manifest_id',
      'managed_production_roots',
      'sources',
      'assets',
    }, 'third_party_asset_manifest');
    final version = map['contract_version'];
    if (version != kB05ThirdPartyAssetManifestVersion) {
      throw B05RegistryValidationException(
        'third_party_manifest_version',
        'Unsupported third-party asset manifest version: $version.',
      );
    }
    final rawSources = map['sources'];
    final rawAssets = map['assets'];
    if (rawSources is! List || rawSources.isEmpty || rawAssets is! List) {
      throw B05RegistryValidationException(
        'third_party_manifest_shape',
        'Manifest requires non-empty sources and an assets list.',
      );
    }
    final manifest = B05ThirdPartyAssetManifest(
      manifestId: _string(map, 'manifest_id'),
      managedProductionRoots: _stringList(
        map,
        'managed_production_roots',
      ).map(_normalizeRoot).toList(growable: false),
      sources: List.unmodifiable(
        rawSources.map(B05ThirdPartySourceContract.fromJson),
      ),
      assets: List.unmodifiable(
        rawAssets.map(B05ThirdPartyAssetContract.fromJson),
      ),
    );
    manifest.validateStructure();
    return manifest;
  }

  factory B05ThirdPartyAssetManifest.fromJsonString(String raw) =>
      B05ThirdPartyAssetManifest.fromJson(jsonDecode(raw));

  void validateStructure() {
    final sourceKeys = <String>{};
    for (final source in sources) {
      if (!sourceKeys.add(source.sourceKey)) {
        throw B05RegistryValidationException(
          'third_party_duplicate_source',
          'Duplicate third-party source key: ${source.sourceKey}.',
        );
      }
    }
    if (managedProductionRoots.toSet().length !=
        managedProductionRoots.length) {
      throw B05RegistryValidationException(
        'third_party_duplicate_root',
        'Managed production roots must be unique.',
      );
    }
    final assetKeys = <String>{};
    final destinations = <String>{};
    final bindingOwners = <String, String>{};
    for (final asset in assets) {
      if (!assetKeys.add(asset.assetKey)) {
        throw B05RegistryValidationException(
          'third_party_duplicate_asset',
          'Duplicate third-party asset key: ${asset.assetKey}.',
        );
      }
      if (!destinations.add(asset.localDestination)) {
        throw B05RegistryValidationException(
          'third_party_duplicate_destination',
          'Duplicate third-party local destination: ${asset.localDestination}.',
        );
      }
      if (!sourceKeys.contains(asset.sourceKey)) {
        throw B05RegistryValidationException(
          'third_party_missing_source',
          'Asset ${asset.assetKey} references unknown source ${asset.sourceKey}.',
        );
      }
      final setId = asset.assetSetId;
      if (setId == null) continue;
      if (setId.trim().isEmpty) {
        throw B05RegistryValidationException(
          'third_party_asset_set_id',
          'Asset-set IDs must be non-empty.',
        );
      }
      if (asset.pinnedExternalExerciseId == null ||
          asset.pinnedExternalExerciseId != asset.sourceAssetId ||
          asset.techniqueDisclosure == null ||
          asset.canonicalExerciseUuids.isEmpty) {
        throw B05RegistryValidationException(
          'third_party_asset_set_fields',
          'Asset-set files require pinned external ID, UUID bindings, and technique disclosure.',
        );
      }
      for (final uuid in asset.canonicalExerciseUuids) {
        final previousOwner = bindingOwners[uuid];
        if (previousOwner != null && previousOwner != setId) {
          throw B05RegistryValidationException(
            'third_party_duplicate_visual_binding',
            'Canonical UUID $uuid is bound to multiple visual asset sets.',
          );
        }
        bindingOwners[uuid] = setId;
      }
    }
    for (final set in visualAssetSets) {
      final roles = set.mediaByRole.keys.toSet();
      if (!(set.isPosePair || set.isMainOnly)) {
        throw B05RegistryValidationException(
          'third_party_asset_set_roles',
          'Visual asset set ${set.assetSetId} must contain START/PEAK or MAIN media only.',
        );
      }
      if (set.approvalRecordId == null ||
          set.techniqueDisclosure.status != 'underlying_movement_only' ||
          set.mediaByRole.values.any(
            (asset) =>
                asset.sourceKey != set.sourceKey ||
                asset.sourceAssetId != set.pinnedExternalExerciseId ||
                asset.pinnedExternalExerciseId !=
                    set.pinnedExternalExerciseId ||
                asset.approvalRecordId != set.approvalRecordId ||
                !_sameStringSet(
                  asset.canonicalExerciseUuids,
                  set.canonicalExerciseUuids,
                ) ||
                asset.approvalStatus != 'production' ||
                asset.techniqueDisclosure?.status !=
                    set.techniqueDisclosure.status ||
                asset.techniqueDisclosure?.text != set.techniqueDisclosure.text,
          )) {
        throw B05RegistryValidationException(
          'third_party_asset_set_consistency',
          'Visual asset set ${set.assetSetId} has inconsistent approval or binding metadata.',
        );
      }
      if (roles.contains('main') && roles.length != 1) {
        throw B05RegistryValidationException(
          'third_party_main_role_exclusivity',
          'MAIN media cannot be combined with START or PEAK media.',
        );
      }
    }
  }
}

bool _sameStringSet(Iterable<String> left, Iterable<String> right) {
  final leftSet = left.toSet();
  final rightSet = right.toSet();
  return leftSet.length == rightSet.length && leftSet.containsAll(rightSet);
}

class B05ThirdPartyAssetValidationInput {
  final Set<String> canonicalExerciseUuids;
  final Set<String> repositoryFiles;
  final Map<String, List<int>> licenseBytes;
  final Map<String, List<int>> assetBytes;
  final Set<String> managedProductionFiles;

  const B05ThirdPartyAssetValidationInput({
    required this.canonicalExerciseUuids,
    required this.repositoryFiles,
    this.licenseBytes = const {},
    required this.assetBytes,
    required this.managedProductionFiles,
  });
}

class B05ThirdPartyAssetManifestValidator {
  const B05ThirdPartyAssetManifestValidator();

  void validate(
    B05ThirdPartyAssetManifest manifest,
    B05ThirdPartyAssetValidationInput input,
  ) {
    manifest.validateStructure();
    final sources = {
      for (final source in manifest.sources) source.sourceKey: source,
    };

    for (final source in manifest.sources) {
      final licenseScopes = [
        source.sourceCodeLicense,
        ...source.contentLicenses,
      ];
      if (!licenseScopes.any((license) => license.status == 'verified')) {
        throw B05RegistryValidationException(
          'third_party_missing_license',
          'Source ${source.sourceKey} has no verified license record.',
        );
      }
      for (final license in licenseScopes) {
        final file = license.licenseFile;
        if (file != null) {
          if (!input.repositoryFiles.contains(file)) {
            throw B05RegistryValidationException(
              'third_party_missing_license_file',
              'Missing vendored license file $file for ${source.sourceKey}.',
            );
          }
          final bytes = input.licenseBytes[file] ?? input.assetBytes[file];
          if (bytes == null) {
            throw B05RegistryValidationException(
              'third_party_missing_license_file',
              'Missing file bytes for vendored license $file for ${source.sourceKey}.',
            );
          }
          final actual = 'sha256:${sha256.convert(bytes)}';
          if (actual != license.licenseSha256) {
            throw B05RegistryValidationException(
              'third_party_license_checksum_mismatch',
              'License checksum mismatch for $file in ${source.sourceKey}. Expected ${license.licenseSha256}, got $actual.',
            );
          }
        }
      }
    }

    final productionManifestFiles = <String>{};
    for (final asset in manifest.assets) {
      final source = sources[asset.sourceKey]!;
      if (!source.isPinned) {
        throw B05RegistryValidationException(
          'third_party_asset_unpinned_source',
          'Asset ${asset.assetKey} references an unpinned source.',
        );
      }
      for (final uuid in asset.canonicalExerciseUuids) {
        if (!input.canonicalExerciseUuids.contains(uuid)) {
          throw B05RegistryValidationException(
            'third_party_unknown_canonical_uuid',
            'Asset ${asset.assetKey} binds unknown canonical UUID $uuid.',
          );
        }
      }
      if (asset.canonicalExerciseUuids.toSet().length !=
          asset.canonicalExerciseUuids.length) {
        throw B05RegistryValidationException(
          'third_party_duplicate_canonical_uuid',
          'Asset ${asset.assetKey} repeats a canonical UUID binding.',
        );
      }
      final isProductionPath = manifest.managedProductionRoots.any(
        asset.localDestination.startsWith,
      );
      if (isProductionPath) {
        productionManifestFiles.add(asset.localDestination);
        if (asset.approvalStatus != 'production' ||
            asset.approvalRecordId == null) {
          throw B05RegistryValidationException(
            'third_party_unapproved_production_asset',
            'Production asset ${asset.assetKey} lacks production approval.',
          );
        }
        if (source.usageClassification != 'production_candidate') {
          throw B05RegistryValidationException(
            'third_party_prohibited_production_source',
            'Production asset ${asset.assetKey} uses a non-production source.',
          );
        }
      }
      final bytes = input.assetBytes[asset.localDestination];
      if (bytes == null) {
        throw B05RegistryValidationException(
          'third_party_missing_asset_file',
          'Missing manifest asset ${asset.localDestination}.',
        );
      }
      final actual = 'sha256:${sha256.convert(bytes)}';
      if (actual != asset.checksum) {
        throw B05RegistryValidationException(
          'third_party_checksum_mismatch',
          'Checksum mismatch for ${asset.localDestination}.',
        );
      }
    }

    final unmanifested = input.managedProductionFiles.difference(
      productionManifestFiles,
    );
    if (unmanifested.isNotEmpty) {
      throw B05RegistryValidationException(
        'third_party_unmanifested_production_file',
        'Unmanifested production file: ${unmanifested.toList()..sort()}.',
      );
    }
  }
}

Map<String, dynamic> _object(Object? raw, String context) {
  if (raw is! Map) {
    throw B05RegistryValidationException(
      '${context}_shape',
      '$context must be an object.',
    );
  }
  return Map<String, dynamic>.from(raw);
}

void _keys(Map<String, dynamic> map, Set<String> allowed, String context) {
  final unknown = map.keys.where((key) => !allowed.contains(key)).toList();
  if (unknown.isNotEmpty) {
    throw B05RegistryValidationException(
      '${context}_unknown_key',
      '$context contains unknown keys: $unknown.',
    );
  }
}

String _string(
  Map<String, dynamic> map,
  String key, {
  bool allowEmpty = false,
}) {
  final value = map[key];
  if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
    throw B05RegistryValidationException(
      'third_party_required_string',
      '$key must be ${allowEmpty ? 'a string' : 'a non-empty string'}.',
    );
  }
  return value.trim();
}

String? _optionalString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw B05RegistryValidationException(
      'third_party_optional_string',
      '$key must be null or a non-empty string.',
    );
  }
  return value.trim();
}

List<String> _stringList(
  Map<String, dynamic> map,
  String key, {
  bool allowEmpty = false,
}) {
  final value = map[key];
  if (value is! List || (!allowEmpty && value.isEmpty)) {
    throw B05RegistryValidationException(
      'third_party_string_list',
      '$key must be ${allowEmpty ? 'a' : 'a non-empty'} string list.',
    );
  }
  final result = <String>[];
  for (final entry in value) {
    if (entry is! String || entry.trim().isEmpty) {
      throw B05RegistryValidationException(
        'third_party_string_list_entry',
        '$key contains an empty or non-string value.',
      );
    }
    result.add(entry.trim());
  }
  return List.unmodifiable(result);
}

String _relativePath(Map<String, dynamic> map, String key) {
  final value = _string(map, key).replaceAll('\\', '/');
  if (value.startsWith('/') ||
      value.split('/').contains('..') ||
      Uri.tryParse(value)?.hasScheme == true) {
    throw B05RegistryValidationException(
      'third_party_relative_path',
      '$key must be a repository-relative path.',
    );
  }
  return value;
}

String _normalizeRoot(String value) {
  final normalized = value.replaceAll('\\', '/');
  if (normalized.startsWith('/') || normalized.split('/').contains('..')) {
    throw B05RegistryValidationException(
      'third_party_managed_root',
      'Managed production roots must be repository-relative.',
    );
  }
  return normalized.endsWith('/') ? normalized : '$normalized/';
}

bool _isHttpsUrl(String? value) {
  if (value == null) return false;
  final uri = Uri.tryParse(value);
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
}
