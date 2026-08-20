/// B05-01 packaged contract types. These values describe the shape and safety
/// rules for later B05 registries; they do not contain the final licensed
/// media assets or provider catalogue.
const int kB05FoundationContractVersion = 1;
const int kB05MediaManifestContractVersion = 1;

const Set<String> kB05RequiredLessonTopics = {
  'rpe',
  'progressive_overload',
  'protein',
  'energy_balance',
  'recovery',
};

class B05RegistryValidationException extends FormatException {
  final String code;

  B05RegistryValidationException(this.code, String message) : super(message);
}

/// A descriptor is a packaged identity and presentation contract, never a
/// persisted widget name or executable configuration.
class B05DashboardModuleDescriptor {
  final String id;
  final int defaultOrdinal;
  final bool defaultVisible;
  final bool defaultCollapsed;
  final bool collapsible;
  final String label;

  const B05DashboardModuleDescriptor({
    required this.id,
    required this.defaultOrdinal,
    this.defaultVisible = true,
    this.defaultCollapsed = false,
    this.collapsible = true,
    required this.label,
  });

  factory B05DashboardModuleDescriptor.fromJson(Object? raw) {
    if (raw is! Map) {
      throw B05RegistryValidationException(
        'dashboard_descriptor_shape',
        'Dashboard descriptor must be an object.',
      );
    }
    final map = Map<String, dynamic>.from(raw);
    _rejectUnknownKeys(map, {
      'id',
      'default_ordinal',
      'default_visible',
      'default_collapsed',
      'collapsible',
      'label',
    }, 'dashboard_descriptor');
    final ordinal = map['default_ordinal'];
    if (ordinal is! int) {
      throw B05RegistryValidationException(
        'dashboard_descriptor_ordinal',
        'Dashboard descriptor default_ordinal must be an integer.',
      );
    }
    for (final key in const [
      'default_visible',
      'default_collapsed',
      'collapsible',
    ]) {
      final value = map[key];
      if (value != null && value is! bool) {
        throw B05RegistryValidationException(
          'dashboard_descriptor_boolean',
          'Dashboard descriptor $key must be a boolean when present.',
        );
      }
    }
    return B05DashboardModuleDescriptor(
      id: _requiredString(map, 'id'),
      defaultOrdinal: ordinal,
      defaultVisible: map['default_visible'] as bool? ?? true,
      defaultCollapsed: map['default_collapsed'] as bool? ?? false,
      collapsible: map['collapsible'] as bool? ?? true,
      label: _requiredString(map, 'label'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'default_ordinal': defaultOrdinal,
    'default_visible': defaultVisible,
    'default_collapsed': defaultCollapsed,
    'collapsible': collapsible,
    'label': label,
  };
}

class B05DashboardModulePreferenceValue {
  final String moduleId;
  final int ordinal;
  final bool isVisible;
  final bool isCollapsed;

  const B05DashboardModulePreferenceValue({
    required this.moduleId,
    required this.ordinal,
    required this.isVisible,
    required this.isCollapsed,
  });

  B05DashboardModulePreferenceValue copyWith({
    String? moduleId,
    int? ordinal,
    bool? isVisible,
    bool? isCollapsed,
  }) => B05DashboardModulePreferenceValue(
    moduleId: moduleId ?? this.moduleId,
    ordinal: ordinal ?? this.ordinal,
    isVisible: isVisible ?? this.isVisible,
    isCollapsed: isCollapsed ?? this.isCollapsed,
  );
}

/// One deterministic normalization authority for dashboard preferences.
class B05DashboardModuleRegistry {
  final List<B05DashboardModuleDescriptor> descriptors;
  final Map<String, B05DashboardModuleDescriptor> _byId;

  B05DashboardModuleRegistry(Iterable<B05DashboardModuleDescriptor> entries)
    : this._fromList(List<B05DashboardModuleDescriptor>.of(entries));

  B05DashboardModuleRegistry._fromList(
    List<B05DashboardModuleDescriptor> entries,
  ) : descriptors = List.unmodifiable(entries),
      _byId = _indexDashboardDescriptors(entries);

  factory B05DashboardModuleRegistry.fromJson(Object? raw) {
    if (raw is! Map || raw['modules'] is! List) {
      throw B05RegistryValidationException(
        'dashboard_registry_shape',
        'Dashboard registry must contain a modules list.',
      );
    }
    final map = Map<String, dynamic>.from(raw);
    _rejectUnknownKeys(map, {
      'contract_version',
      'modules',
    }, 'dashboard_registry');
    _validateContractVersion(
      map['contract_version'],
      'dashboard_registry',
      kB05FoundationContractVersion,
    );
    return B05DashboardModuleRegistry(
      (map['modules'] as List).map(B05DashboardModuleDescriptor.fromJson),
    );
  }

  Map<String, dynamic> toJson() => {
    'contract_version': kB05FoundationContractVersion,
    'modules': descriptors.map((descriptor) => descriptor.toJson()).toList(),
  };

  List<B05DashboardModulePreferenceValue> normalize(
    Iterable<B05DashboardModulePreferenceValue> stored,
  ) {
    final firstById = <String, B05DashboardModulePreferenceValue>{};
    for (final value in stored) {
      if (value.ordinal < 0 ||
          !_byId.containsKey(value.moduleId) ||
          firstById.containsKey(value.moduleId)) {
        continue;
      }
      final descriptor = _byId[value.moduleId]!;
      firstById[value.moduleId] = value.copyWith(
        isCollapsed: descriptor.collapsible ? value.isCollapsed : false,
      );
    }
    final normalized = firstById.values.toList()
      ..sort((a, b) {
        final ordinal = a.ordinal.compareTo(b.ordinal);
        return ordinal == 0 ? a.moduleId.compareTo(b.moduleId) : ordinal;
      });
    for (final descriptor in descriptors) {
      if (firstById.containsKey(descriptor.id)) continue;
      normalized.add(
        B05DashboardModulePreferenceValue(
          moduleId: descriptor.id,
          ordinal: descriptor.defaultOrdinal,
          isVisible: descriptor.defaultVisible,
          isCollapsed: descriptor.collapsible
              ? descriptor.defaultCollapsed
              : false,
        ),
      );
    }
    return List.unmodifiable(normalized);
  }
}

Map<String, B05DashboardModuleDescriptor> _indexDashboardDescriptors(
  Iterable<B05DashboardModuleDescriptor> entries,
) {
  final result = <String, B05DashboardModuleDescriptor>{};
  for (final entry in entries) {
    if (entry.id.trim().isEmpty ||
        entry.label.trim().isEmpty ||
        entry.defaultOrdinal < 0 ||
        result.containsKey(entry.id)) {
      throw B05RegistryValidationException(
        'dashboard_descriptor',
        'Dashboard descriptors must have unique non-empty IDs and labels.',
      );
    }
    result[entry.id] = entry;
  }
  return Map.unmodifiable(result);
}

class B05EducationContentDescriptor {
  final String contentId;
  final String version;
  final String topic;
  final String body;
  final Set<String> relevanceTags;
  final String completionPolicy;
  final String? exerciseId;

  const B05EducationContentDescriptor({
    required this.contentId,
    required this.version,
    required this.topic,
    required this.body,
    required this.relevanceTags,
    this.completionPolicy = 'revisit',
    this.exerciseId,
  });

  factory B05EducationContentDescriptor.fromJson(Object? raw) {
    if (raw is! Map) {
      throw B05RegistryValidationException(
        'education_descriptor_shape',
        'Education descriptor must be an object.',
      );
    }
    final map = Map<String, dynamic>.from(raw);
    _rejectUnknownKeys(map, {
      'content_id',
      'version',
      'topic',
      'body',
      'relevance_tags',
      'completion_policy',
      'exercise_id',
    }, 'education_descriptor');
    final tags = map['relevance_tags'];
    if (tags is! List) {
      throw B05RegistryValidationException(
        'education_relevance_tags',
        'Education relevance_tags must be a list.',
      );
    }
    return B05EducationContentDescriptor(
      contentId: _requiredString(map, 'content_id'),
      version: _requiredString(map, 'version'),
      topic: _requiredString(map, 'topic'),
      body: _requiredString(map, 'body'),
      relevanceTags: _stringSet(tags, 'relevance_tags'),
      completionPolicy: map['completion_policy'] == null
          ? 'revisit'
          : _requiredString(map, 'completion_policy'),
      exerciseId: map['exercise_id'] == null
          ? null
          : _requiredString(map, 'exercise_id'),
    );
  }

  Map<String, dynamic> toJson() => {
    'content_id': contentId,
    'version': version,
    'topic': topic,
    'body': body,
    'relevance_tags': relevanceTags.toList()..sort(),
    'completion_policy': completionPolicy,
    if (exerciseId != null) 'exercise_id': exerciseId,
  };
}

class B05EducationContentRegistry {
  final List<B05EducationContentDescriptor> lessons;

  B05EducationContentRegistry(Iterable<B05EducationContentDescriptor> entries)
    : lessons = List.unmodifiable(entries) {
    final ids = <String>{};
    for (final lesson in lessons) {
      if (lesson.contentId.trim().isEmpty ||
          lesson.version.trim().isEmpty ||
          lesson.body.trim().isEmpty ||
          !kB05RequiredLessonTopics.contains(lesson.topic) ||
          !ids.add(lesson.contentId)) {
        throw B05RegistryValidationException(
          'education_descriptor',
          'Education descriptors must use unique IDs and a required B05 topic.',
        );
      }
    }
  }

  factory B05EducationContentRegistry.fromJson(Object? raw) {
    if (raw is! Map || raw['lessons'] is! List) {
      throw B05RegistryValidationException(
        'education_registry_shape',
        'Education registry must contain a lessons list.',
      );
    }
    final map = Map<String, dynamic>.from(raw);
    _rejectUnknownKeys(map, {
      'contract_version',
      'lessons',
    }, 'education_registry');
    _validateContractVersion(
      map['contract_version'],
      'education_registry',
      kB05FoundationContractVersion,
    );
    return B05EducationContentRegistry(
      (map['lessons'] as List).map(B05EducationContentDescriptor.fromJson),
    );
  }

  Map<String, dynamic> toJson() => {
    'contract_version': kB05FoundationContractVersion,
    'lessons': lessons.map((lesson) => lesson.toJson()).toList(),
  };

  void requireAllTopics() {
    final topics = lessons.map((lesson) => lesson.topic).toSet();
    if (!topics.containsAll(kB05RequiredLessonTopics)) {
      throw B05RegistryValidationException(
        'education_topics',
        'Education registry must cover RPE, progressive overload, protein, energy balance, and recovery.',
      );
    }
  }
}

class B05MuscleDiagramRegion {
  final String regionId;
  final String muscleId;
  final String label;
  final int textOrder;

  const B05MuscleDiagramRegion({
    required this.regionId,
    required this.muscleId,
    required this.label,
    required this.textOrder,
  });

  factory B05MuscleDiagramRegion.fromJson(Object? raw) {
    if (raw is! Map) {
      throw B05RegistryValidationException(
        'muscle_visual_region_shape',
        'Muscle visual region must be an object.',
      );
    }
    final map = Map<String, dynamic>.from(raw);
    _rejectUnknownKeys(map, {
      'region_id',
      'muscle_id',
      'label',
      'text_order',
    }, 'muscle_visual_region');
    final order = map['text_order'];
    if (order is! int) {
      throw B05RegistryValidationException(
        'muscle_visual_region_order',
        'Muscle visual region text_order must be an integer.',
      );
    }
    return B05MuscleDiagramRegion(
      regionId: _requiredString(map, 'region_id'),
      muscleId: _requiredString(map, 'muscle_id'),
      label: _requiredString(map, 'label'),
      textOrder: order,
    );
  }
}

class B05MuscleVisualRegistry {
  final List<B05MuscleDiagramRegion> regions;

  B05MuscleVisualRegistry(Iterable<B05MuscleDiagramRegion> entries)
    : regions = List.unmodifiable(entries) {
    final regionIds = <String>{};
    for (final region in regions) {
      if (region.regionId.trim().isEmpty ||
          region.muscleId.trim().isEmpty ||
          region.label.trim().isEmpty ||
          region.textOrder < 0 ||
          !regionIds.add(region.regionId)) {
        throw B05RegistryValidationException(
          'muscle_visual_region',
          'Muscle visual regions require unique IDs and canonical muscle IDs.',
        );
      }
    }
  }

  factory B05MuscleVisualRegistry.fromJson(Object? raw) {
    if (raw is! Map || raw['regions'] is! List) {
      throw B05RegistryValidationException(
        'muscle_visual_registry_shape',
        'Muscle visual registry must contain a regions list.',
      );
    }
    final map = Map<String, dynamic>.from(raw);
    _rejectUnknownKeys(map, {
      'contract_version',
      'regions',
    }, 'muscle_visual_registry');
    _validateContractVersion(
      map['contract_version'],
      'muscle_visual_registry',
      kB05FoundationContractVersion,
    );
    return B05MuscleVisualRegistry(
      (map['regions'] as List).map(B05MuscleDiagramRegion.fromJson),
    );
  }

  Map<String, dynamic> toJson() => {
    'contract_version': kB05FoundationContractVersion,
    'regions': [
      for (final region in regions)
        {
          'region_id': region.regionId,
          'muscle_id': region.muscleId,
          'label': region.label,
          'text_order': region.textOrder,
        },
    ],
  };
}

/// A provider-specific playlist reference after validation and normalization.
class B05PlaylistReference {
  final String providerId;
  final String normalizedReference;
  final Uri launchUri;

  const B05PlaylistReference({
    required this.providerId,
    required this.normalizedReference,
    required this.launchUri,
  });
}

/// Provider-specific URL/deep-link policy. A generic URL regex is deliberately
/// not used: each provider supplies its own schemes, hosts and path rules.
class B05PlaylistProviderContract {
  final String id;
  final Set<String> permittedUriSchemes;
  final Set<String> permittedHttpsHosts;
  final RegExp? acceptedPathPattern;
  final int maxReferenceLength;
  final Set<String> disallowedQueryParameters;
  final String? platformFallbackScheme;

  const B05PlaylistProviderContract({
    required this.id,
    required this.permittedUriSchemes,
    required this.permittedHttpsHosts,
    this.acceptedPathPattern,
    this.maxReferenceLength = 512,
    this.disallowedQueryParameters = const {},
    this.platformFallbackScheme,
  });

  B05PlaylistReference normalize(String rawReference) {
    final raw = rawReference.trim();
    if (raw.isEmpty) {
      throw B05RegistryValidationException(
        'empty_playlist_reference',
        'Playlist reference must not be empty.',
      );
    }
    if (raw.length > maxReferenceLength) {
      throw B05RegistryValidationException(
        'playlist_reference_too_long',
        'Playlist reference exceeds the provider limit.',
      );
    }
    if (RegExp(r'[\u0000-\u001f\u007f]').hasMatch(raw)) {
      throw B05RegistryValidationException(
        'playlist_reference_control_character',
        'Playlist reference contains a control character.',
      );
    }

    final parsed = Uri.tryParse(raw);
    if (parsed == null || parsed.scheme.isEmpty) {
      throw B05RegistryValidationException(
        'playlist_reference_uri',
        'Playlist reference is not a provider URI.',
      );
    }
    if (parsed.userInfo.isNotEmpty || parsed.fragment.isNotEmpty) {
      throw B05RegistryValidationException(
        'playlist_reference_credentials_or_fragment',
        'Playlist reference cannot contain credentials or a fragment.',
      );
    }

    final scheme = parsed.scheme.toLowerCase();
    final host = parsed.host.toLowerCase();
    final isAllowedCustomScheme = permittedUriSchemes.contains(scheme);
    final isAllowedHttpsHost =
        scheme == 'https' && permittedHttpsHosts.contains(host);
    if (!isAllowedCustomScheme && !isAllowedHttpsHost) {
      throw B05RegistryValidationException(
        'playlist_provider_route',
        'Playlist reference is not allowed for provider $id.',
      );
    }
    if (acceptedPathPattern != null &&
        !acceptedPathPattern!.hasMatch(parsed.path)) {
      throw B05RegistryValidationException(
        'playlist_reference_shape',
        'Playlist reference path is not accepted by provider $id.',
      );
    }

    final queryParameters = parsed.queryParametersAll;
    if (queryParameters.values.any((values) => values.length > 1)) {
      throw B05RegistryValidationException(
        'playlist_reference_duplicate_query',
        'Playlist reference query parameters must be unique.',
      );
    }
    final queryKeys = queryParameters.keys
        .map((key) => key.toLowerCase())
        .toSet();
    final deniedQueryParameters = disallowedQueryParameters
        .map((key) => key.toLowerCase())
        .toSet();
    if (queryKeys.intersection(deniedQueryParameters).isNotEmpty) {
      throw B05RegistryValidationException(
        'playlist_reference_query',
        'Playlist reference contains a disallowed query parameter.',
      );
    }

    final normalizedUri = Uri(
      scheme: scheme,
      userInfo: '',
      host: isAllowedHttpsHost ? host : parsed.host,
      port: parsed.hasPort ? parsed.port : null,
      path: parsed.path,
      queryParameters: queryParameters.isEmpty
          ? null
          : {
              for (final key in queryParameters.keys.toList()..sort())
                key: queryParameters[key]!.single,
            },
    );
    final normalized = normalizedUri.toString();
    if (normalized.isEmpty) {
      throw B05RegistryValidationException(
        'playlist_reference_normalization',
        'Playlist reference could not be normalized.',
      );
    }
    return B05PlaylistReference(
      providerId: id,
      normalizedReference: normalized,
      launchUri: normalizedUri,
    );
  }

  factory B05PlaylistProviderContract.fromJson(Object? raw) {
    if (raw is! Map) {
      throw B05RegistryValidationException(
        'provider_shape',
        'Playlist provider entry must be an object.',
      );
    }
    final map = Map<String, dynamic>.from(raw);
    _rejectUnknownKeys(map, {
      'id',
      'permitted_uri_schemes',
      'permitted_https_hosts',
      'accepted_path_pattern',
      'max_reference_length',
      'disallowed_query_parameters',
      'platform_fallback_scheme',
    }, 'provider');
    final id = _requiredString(map, 'id');
    final schemes = _stringSet(
      map['permitted_uri_schemes'],
      'permitted_uri_schemes',
    );
    final hosts = _stringSet(
      map['permitted_https_hosts'],
      'permitted_https_hosts',
    );
    final patternValue = map['accepted_path_pattern'];
    final maxLength = map['max_reference_length'];
    if (maxLength != null &&
        (maxLength is! int || maxLength < 1 || maxLength > 4096)) {
      throw B05RegistryValidationException(
        'provider_max_length',
        'Provider max_reference_length must be between 1 and 4096.',
      );
    }
    RegExp? acceptedPathPattern;
    if (patternValue != null) {
      final pattern = _requiredString(map, 'accepted_path_pattern');
      try {
        acceptedPathPattern = RegExp(pattern);
      } on FormatException {
        throw B05RegistryValidationException(
          'provider_path_pattern',
          'Provider accepted_path_pattern must be a valid regular expression.',
        );
      }
    }
    return B05PlaylistProviderContract(
      id: id,
      permittedUriSchemes: schemes,
      permittedHttpsHosts: hosts,
      acceptedPathPattern: acceptedPathPattern,
      maxReferenceLength: maxLength as int? ?? 512,
      disallowedQueryParameters: _stringSet(
        map['disallowed_query_parameters'] ?? const [],
        'disallowed_query_parameters',
      ),
      platformFallbackScheme: map['platform_fallback_scheme'] == null
          ? null
          : _requiredString(map, 'platform_fallback_scheme'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'permitted_uri_schemes': permittedUriSchemes.toList()..sort(),
    'permitted_https_hosts': permittedHttpsHosts.toList()..sort(),
    if (acceptedPathPattern != null)
      'accepted_path_pattern': acceptedPathPattern!.pattern,
    'max_reference_length': maxReferenceLength,
    'disallowed_query_parameters': disallowedQueryParameters.toList()..sort(),
    if (platformFallbackScheme != null)
      'platform_fallback_scheme': platformFallbackScheme,
  };
}

/// Immutable provider allowlist. The final B05 provider entries are supplied
/// by the product owner; this registry only admits validated entries.
class B05PlaylistProviderRegistry {
  final Map<String, B05PlaylistProviderContract> providers;

  B05PlaylistProviderRegistry(Iterable<B05PlaylistProviderContract> entries)
    : providers = _index(entries);

  B05PlaylistReference normalize(String providerId, String rawReference) {
    final provider = providers[providerId];
    if (provider == null) {
      throw B05RegistryValidationException(
        'unknown_playlist_provider',
        'Playlist provider $providerId is not allowlisted.',
      );
    }
    return provider.normalize(rawReference);
  }

  factory B05PlaylistProviderRegistry.fromJson(Object? raw) {
    if (raw is! Map || raw['providers'] is! List) {
      throw B05RegistryValidationException(
        'provider_registry_shape',
        'Provider registry must contain a providers list.',
      );
    }
    final map = Map<String, dynamic>.from(raw);
    _rejectUnknownKeys(map, {
      'contract_version',
      'providers',
    }, 'provider_registry');
    _validateContractVersion(
      map['contract_version'],
      'provider_registry',
      kB05FoundationContractVersion,
    );
    return B05PlaylistProviderRegistry(
      (map['providers'] as List).map(B05PlaylistProviderContract.fromJson),
    );
  }

  Map<String, dynamic> toJson() => {
    'contract_version': kB05FoundationContractVersion,
    'providers': providers.values.map((provider) => provider.toJson()).toList()
      ..sort((a, b) => '${a['id']}'.compareTo('${b['id']}')),
  };

  static Map<String, B05PlaylistProviderContract> _index(
    Iterable<B05PlaylistProviderContract> entries,
  ) {
    final result = <String, B05PlaylistProviderContract>{};
    for (final entry in entries) {
      if (entry.id.trim().isEmpty || result.containsKey(entry.id)) {
        throw B05RegistryValidationException(
          'duplicate_playlist_provider',
          'Playlist provider IDs must be non-empty and unique.',
        );
      }
      if (entry.maxReferenceLength < 1 || entry.maxReferenceLength > 4096) {
        throw B05RegistryValidationException(
          'provider_max_length',
          'Provider max reference length is outside the supported range.',
        );
      }
      if (entry.permittedUriSchemes.isEmpty &&
          entry.permittedHttpsHosts.isEmpty) {
        throw B05RegistryValidationException(
          'provider_routes',
          'Playlist providers must allow at least one URI scheme or HTTPS host.',
        );
      }
      result[entry.id] = entry;
    }
    return Map.unmodifiable(result);
  }
}

/// The B05-01 media contract carries manifest identity and licensing metadata,
/// not a final asset catalogue or any physical file state.
class B05MediaPackContract {
  final String packId;
  final String manifestIdentity;
  final String contentVersion;
  final String checksumAlgorithm;
  final String sourceLicense;
  final String attribution;
  final String distributionRights;
  final String offlineFallbackId;
  final String reducedMotionFallbackId;

  const B05MediaPackContract({
    required this.packId,
    required this.manifestIdentity,
    required this.contentVersion,
    required this.checksumAlgorithm,
    required this.sourceLicense,
    required this.attribution,
    required this.distributionRights,
    required this.offlineFallbackId,
    required this.reducedMotionFallbackId,
  });

  factory B05MediaPackContract.fromJson(Object? raw) {
    if (raw is! Map) {
      throw B05RegistryValidationException(
        'media_contract_shape',
        'Media pack contract must be an object.',
      );
    }
    final map = Map<String, dynamic>.from(raw);
    _rejectUnknownKeys(map, {
      'contract_version',
      'pack_id',
      'manifest_identity',
      'content_version',
      'checksum_algorithm',
      'source_license',
      'attribution',
      'distribution_rights',
      'offline_fallback_id',
      'reduced_motion_fallback_id',
    }, 'media_contract');
    _validateContractVersion(
      map['contract_version'],
      'media_contract',
      kB05MediaManifestContractVersion,
    );
    return B05MediaPackContract(
      packId: _requiredString(map, 'pack_id'),
      manifestIdentity: _requiredString(map, 'manifest_identity'),
      contentVersion: _requiredString(map, 'content_version'),
      checksumAlgorithm: _requiredString(map, 'checksum_algorithm'),
      sourceLicense: _requiredString(map, 'source_license'),
      attribution: _requiredString(map, 'attribution'),
      distributionRights: _requiredString(map, 'distribution_rights'),
      offlineFallbackId: _requiredString(map, 'offline_fallback_id'),
      reducedMotionFallbackId: _requiredString(
        map,
        'reduced_motion_fallback_id',
      ),
    );
  }

  void validateStructure() {
    if (packId.trim().isEmpty ||
        manifestIdentity.trim().isEmpty ||
        contentVersion.trim().isEmpty ||
        checksumAlgorithm != B05MediaAcceptanceTemplate.checksumAlgorithm ||
        sourceLicense.trim().isEmpty ||
        attribution.trim().isEmpty ||
        distributionRights.trim().isEmpty ||
        offlineFallbackId.trim().isEmpty ||
        reducedMotionFallbackId.trim().isEmpty) {
      throw B05RegistryValidationException(
        'media_contract_fields',
        'Media pack contract requires checksum, rights and offline fallback metadata.',
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'contract_version': kB05MediaManifestContractVersion,
    'pack_id': packId,
    'manifest_identity': manifestIdentity,
    'content_version': contentVersion,
    'checksum_algorithm': checksumAlgorithm,
    'source_license': sourceLicense,
    'attribution': attribution,
    'distribution_rights': distributionRights,
    'offline_fallback_id': offlineFallbackId,
    'reduced_motion_fallback_id': reducedMotionFallbackId,
  };
}

class B05MediaAssetContract {
  final String exerciseId;
  final String assetId;
  final String? assetSetId;
  final String? mediaRole;
  final String? sourceRelativePath;
  final String? localDestination;
  final List<String> canonicalExerciseUuids;
  final String? techniqueDisclosure;
  final String checksum;
  final String sourceLicense;
  final String attribution;
  final String distributionRights;
  final String stillFallbackId;
  final String reducedMotionFallbackId;

  const B05MediaAssetContract({
    required this.exerciseId,
    required this.assetId,
    this.assetSetId,
    this.mediaRole,
    this.sourceRelativePath,
    this.localDestination,
    this.canonicalExerciseUuids = const <String>[],
    this.techniqueDisclosure,
    required this.checksum,
    required this.sourceLicense,
    required this.attribution,
    required this.distributionRights,
    required this.stillFallbackId,
    required this.reducedMotionFallbackId,
  });

  factory B05MediaAssetContract.fromJson(Object? raw) {
    if (raw is! Map) {
      throw B05RegistryValidationException(
        'media_asset_shape',
        'Media asset entry must be an object.',
      );
    }
    final map = Map<String, dynamic>.from(raw);
    _rejectUnknownKeys(map, {
      'exercise_id',
      'asset_id',
      'asset_set_id',
      'media_role',
      'source_relative_path',
      'local_destination',
      'canonical_exercise_uuids',
      'technique_disclosure',
      'checksum',
      'source_license',
      'attribution',
      'distribution_rights',
      'still_fallback_id',
      'reduced_motion_fallback_id',
    }, 'media_asset');
    return B05MediaAssetContract(
      exerciseId: _requiredString(map, 'exercise_id'),
      assetId: _requiredString(map, 'asset_id'),
      assetSetId: _optionalString(map, 'asset_set_id'),
      mediaRole: _optionalString(map, 'media_role'),
      sourceRelativePath: _optionalString(map, 'source_relative_path'),
      localDestination: _optionalString(map, 'local_destination'),
      canonicalExerciseUuids: _stringList(
        map,
        'canonical_exercise_uuids',
        allowEmpty: true,
      ),
      techniqueDisclosure: _optionalString(map, 'technique_disclosure'),
      checksum: _requiredString(map, 'checksum'),
      sourceLicense: _requiredString(map, 'source_license'),
      attribution: _requiredString(map, 'attribution'),
      distributionRights: _requiredString(map, 'distribution_rights'),
      stillFallbackId: _requiredString(map, 'still_fallback_id'),
      reducedMotionFallbackId: _requiredString(
        map,
        'reduced_motion_fallback_id',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'exercise_id': exerciseId,
    'asset_id': assetId,
    if (assetSetId != null) 'asset_set_id': assetSetId,
    if (mediaRole != null) 'media_role': mediaRole,
    if (sourceRelativePath != null) 'source_relative_path': sourceRelativePath,
    if (localDestination != null) 'local_destination': localDestination,
    if (canonicalExerciseUuids.isNotEmpty)
      'canonical_exercise_uuids': canonicalExerciseUuids,
    if (techniqueDisclosure != null)
      'technique_disclosure': techniqueDisclosure,
    'checksum': checksum,
    'source_license': sourceLicense,
    'attribution': attribution,
    'distribution_rights': distributionRights,
    'still_fallback_id': stillFallbackId,
    'reduced_motion_fallback_id': reducedMotionFallbackId,
  };
}

/// A reusable presentation set derived from B05 media files. The four
/// canonical exercise UUIDs remain explicit bindings; this set only names the
/// artwork and its presentation roles.
class B05MediaVisualAssetSetContract {
  final String assetSetId;
  final List<String> canonicalExerciseUuids;
  final Map<String, B05MediaAssetContract> mediaByRole;
  final String? techniqueDisclosure;

  const B05MediaVisualAssetSetContract({
    required this.assetSetId,
    required this.canonicalExerciseUuids,
    required this.mediaByRole,
    required this.techniqueDisclosure,
  });

  bool get isPosePair =>
      mediaByRole.length == 2 &&
      mediaByRole.keys.toSet().containsAll({'start', 'peak'});

  bool get isMainOnly =>
      mediaByRole.length == 1 && mediaByRole.containsKey('main');

  B05MediaAssetContract? media(String role) => mediaByRole[role];
}

class B05MediaManifest {
  final B05MediaPackContract pack;
  final List<B05MediaAssetContract> assets;

  const B05MediaManifest({required this.pack, required this.assets});

  List<B05MediaVisualAssetSetContract> get visualAssetSets {
    final grouped = <String, List<B05MediaAssetContract>>{};
    for (final asset in assets) {
      final setId = asset.assetSetId;
      if (setId == null) continue;
      (grouped[setId] ??= <B05MediaAssetContract>[]).add(asset);
    }
    return List.unmodifiable(
      grouped.entries.map((entry) {
        final first = entry.value.first;
        return B05MediaVisualAssetSetContract(
          assetSetId: entry.key,
          canonicalExerciseUuids: first.canonicalExerciseUuids,
          mediaByRole: Map.unmodifiable({
            for (final asset in entry.value)
              if (asset.mediaRole != null) asset.mediaRole!: asset,
          }),
          techniqueDisclosure: first.techniqueDisclosure,
        );
      }),
    );
  }

  factory B05MediaManifest.fromJson(Object? raw) {
    if (raw is! Map || raw['pack'] == null || raw['assets'] is! List) {
      throw B05RegistryValidationException(
        'media_manifest_shape',
        'Media manifest must contain a pack object and assets list.',
      );
    }
    final map = Map<String, dynamic>.from(raw);
    _rejectUnknownKeys(map, {
      'contract_version',
      'pack',
      'assets',
    }, 'media_manifest');
    _validateContractVersion(
      map['contract_version'],
      'media_manifest',
      kB05MediaManifestContractVersion,
    );
    return B05MediaManifest(
      pack: B05MediaPackContract.fromJson(map['pack']),
      assets: (map['assets'] as List)
          .map(B05MediaAssetContract.fromJson)
          .toList(),
    );
  }

  void validateStructure({int? requiredAssetCount}) {
    pack.validateStructure();
    final exerciseIds = <String>{};
    final assetIds = <String>{};
    final visualRoles = <String, Set<String>>{};
    final visualUuidOwners = <String, String>{};
    final visualUuidSets = <String, List<String>>{};
    final visualDisclosures = <String, String>{};
    for (final asset in assets) {
      if (asset.exerciseId.trim().isEmpty ||
          asset.assetId.trim().isEmpty ||
          asset.checksum.trim().isEmpty ||
          !RegExp(r'^sha256:[A-Fa-f0-9]{64}$').hasMatch(asset.checksum) ||
          asset.sourceLicense.trim().isEmpty ||
          asset.attribution.trim().isEmpty ||
          asset.distributionRights.trim().isEmpty ||
          asset.stillFallbackId.trim().isEmpty ||
          asset.reducedMotionFallbackId.trim().isEmpty ||
          !assetIds.add(asset.assetId)) {
        throw B05RegistryValidationException(
          'media_manifest_asset',
          'Media assets require unique stable IDs, checksums, rights and fallbacks.',
        );
      }
      final setId = asset.assetSetId;
      if (setId == null) {
        if (!exerciseIds.add(asset.exerciseId)) {
          throw B05RegistryValidationException(
            'media_manifest_asset',
            'Legacy media assets require unique exercise IDs.',
          );
        }
        continue;
      }
      if (asset.mediaRole == null ||
          !{'start', 'peak', 'main'}.contains(asset.mediaRole) ||
          asset.canonicalExerciseUuids.isEmpty ||
          asset.canonicalExerciseUuids.toSet().length !=
              asset.canonicalExerciseUuids.length ||
          asset.localDestination == null ||
          asset.localDestination!.trim().isEmpty ||
          asset.techniqueDisclosure == null ||
          asset.techniqueDisclosure!.trim().isEmpty) {
        throw B05RegistryValidationException(
          'media_manifest_visual_asset_set',
          'Visual asset-set files require a role, explicit UUID bindings, local destination, and technique disclosure.',
        );
      }
      final role = asset.mediaRole!;
      final roles = visualRoles.putIfAbsent(setId, () => <String>{});
      if (!roles.add(role)) {
        throw B05RegistryValidationException(
          'media_manifest_visual_asset_role_duplicate',
          'Visual asset set $setId contains duplicate media role $role.',
        );
      }
      final previousUuids = visualUuidSets[setId];
      if (previousUuids != null &&
          !_sameStringSet(previousUuids, asset.canonicalExerciseUuids)) {
        throw B05RegistryValidationException(
          'media_manifest_visual_asset_bindings',
          'Visual asset set $setId contains inconsistent UUID bindings.',
        );
      }
      visualUuidSets[setId] = asset.canonicalExerciseUuids;
      final previousDisclosure = visualDisclosures[setId];
      if (previousDisclosure != null &&
          previousDisclosure != asset.techniqueDisclosure) {
        throw B05RegistryValidationException(
          'media_manifest_visual_asset_disclosure',
          'Visual asset set $setId contains inconsistent technique disclosure.',
        );
      }
      visualDisclosures[setId] = asset.techniqueDisclosure!;
      for (final uuid in asset.canonicalExerciseUuids) {
        final previousOwner = visualUuidOwners[uuid];
        if (previousOwner != null && previousOwner != setId) {
          throw B05RegistryValidationException(
            'media_manifest_visual_uuid_duplicate',
            'Canonical UUID $uuid is bound to multiple visual asset sets.',
          );
        }
        visualUuidOwners[uuid] = setId;
      }
    }
    for (final set in visualAssetSets) {
      if (!(set.isPosePair || set.isMainOnly)) {
        throw B05RegistryValidationException(
          'media_manifest_visual_asset_roles',
          'Visual asset sets must contain START/PEAK or MAIN media only.',
        );
      }
    }
    if (requiredAssetCount != null && assets.length != requiredAssetCount) {
      throw B05RegistryValidationException(
        'media_manifest_count',
        'Media manifest must contain exactly $requiredAssetCount approved assets.',
      );
    }
  }

  Map<String, dynamic> toJson() {
    validateStructure();
    return {
      'contract_version': kB05MediaManifestContractVersion,
      'pack': pack.toJson(),
      'assets': assets.map((asset) => asset.toJson()).toList(),
    };
  }
}

bool _sameStringSet(Iterable<String> left, Iterable<String> right) {
  final leftSet = left.toSet();
  final rightSet = right.toSet();
  return leftSet.length == rightSet.length && leftSet.containsAll(rightSet);
}

/// The task-level acceptance template is deliberately metadata-only. It is a
/// gate for B05-08's product-approved packet, not a claim that assets exist.
class B05MediaAcceptanceTemplate {
  /// Retained for legacy playlist/media packet tests. R08-0.3 visual
  /// asset-set validation is no longer fixed to a top-20 count.
  @Deprecated('Use explicit approved IDs or visual asset-set bindings.')
  static const int requiredExerciseCount = 20;
  static const String checksumAlgorithm = 'sha256';
  static const String checksumFormat = 'sha256:<64 hexadecimal characters>';
  static const String attributionFormat =
      'source-license-attribution-distribution-rights';
  static const int maxBundledPackageBytes = 50 * 1024 * 1024;
  static const String requiredOfflineFallback = 'still-or-text';
  static const String requiredRightsEvidence =
      'source-license-attribution-distribution-rights';

  const B05MediaAcceptanceTemplate();
}

enum B05MediaAvailabilityState { available, absent, invalid }

class B05MediaReconciliation {
  final String packId;
  final String manifestIdentity;
  final B05MediaAvailabilityState state;

  const B05MediaReconciliation({
    required this.packId,
    required this.manifestIdentity,
    required this.state,
  });
}

enum B05MediaAssetCheckResult { available, absent, invalid }

typedef B05MediaAssetProbe =
    Future<B05MediaAssetCheckResult> Function(B05MediaAssetContract asset);

/// Derives physical availability from a device-local probe. The probe owns
/// file access; no path, byte state, or availability is persisted or backed up.
class B05MediaPackReconciler {
  const B05MediaPackReconciler();

  Future<B05MediaReconciliation> reconcile(
    B05MediaManifest manifest, {
    required B05MediaAssetProbe probe,
  }) async {
    manifest.validateStructure();
    if (manifest.assets.isEmpty) {
      return B05MediaReconciliation(
        packId: manifest.pack.packId,
        manifestIdentity: manifest.pack.manifestIdentity,
        state: B05MediaAvailabilityState.absent,
      );
    }
    var hasAbsent = false;
    for (final asset in manifest.assets) {
      final result = await probe(asset);
      if (result == B05MediaAssetCheckResult.invalid) {
        return B05MediaReconciliation(
          packId: manifest.pack.packId,
          manifestIdentity: manifest.pack.manifestIdentity,
          state: B05MediaAvailabilityState.invalid,
        );
      }
      if (result == B05MediaAssetCheckResult.absent) hasAbsent = true;
    }
    return B05MediaReconciliation(
      packId: manifest.pack.packId,
      manifestIdentity: manifest.pack.manifestIdentity,
      state: hasAbsent
          ? B05MediaAvailabilityState.absent
          : B05MediaAvailabilityState.available,
    );
  }
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw B05RegistryValidationException(
      'required_registry_string',
      '$key must be a non-empty string.',
    );
  }
  return value.trim();
}

String? _optionalString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw B05RegistryValidationException(
      'optional_registry_string',
      '$key must be null or a non-empty string.',
    );
  }
  return value.trim();
}

List<String> _stringList(
  Map<String, dynamic> map,
  String key, {
  required bool allowEmpty,
}) {
  final value = map[key];
  if (value == null && allowEmpty) return const <String>[];
  if (value is! List || (!allowEmpty && value.isEmpty)) {
    throw B05RegistryValidationException(
      'registry_string_list',
      '$key must be ${allowEmpty ? 'a' : 'a non-empty'} string list.',
    );
  }
  final result = <String>[];
  for (final entry in value) {
    if (entry is! String || entry.trim().isEmpty) {
      throw B05RegistryValidationException(
        'registry_string_list_entry',
        '$key contains an empty or non-string value.',
      );
    }
    result.add(entry.trim());
  }
  return List.unmodifiable(result);
}

void _rejectUnknownKeys(
  Map<String, dynamic> map,
  Set<String> allowed,
  String context,
) {
  if (map.keys.any((key) => !allowed.contains(key))) {
    throw B05RegistryValidationException(
      'unknown_$context',
      '$context contains an unknown or non-portable field.',
    );
  }
}

void _validateContractVersion(Object? raw, String context, int expected) {
  if (raw == null) return;
  if (raw is! int || raw != expected) {
    throw B05RegistryValidationException(
      'unsupported_$context',
      '$context contract_version must be $expected.',
    );
  }
}

Set<String> _stringSet(Object? raw, String key) {
  if (raw is! List ||
      raw.any((value) => value is! String || value.trim().isEmpty)) {
    throw B05RegistryValidationException(
      'registry_string_list',
      '$key must be a list of non-empty strings.',
    );
  }
  final values = raw
      .cast<String>()
      .map((value) => value.trim().toLowerCase())
      .toSet();
  if (values.length != raw.length) {
    throw B05RegistryValidationException(
      'duplicate_registry_value',
      '$key must not contain duplicates.',
    );
  }
  return Set.unmodifiable(values);
}
