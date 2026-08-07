import '../../core/fixtures/b05_foundation_registry.dart';

/// The known dashboard areas that a presentation adapter may make available.
///
/// This is deliberately a packaged capability hint, not an evaluation of a
/// workout, nutrition, progress, or coaching fact. B05-04 supplies the
/// corresponding read adapters from the existing B01–B04 authorities.
enum DashboardModuleEligibility { workout, nutrition, progress, nextAction }

/// A packaged dashboard module descriptor. Persisted data can name only the
/// stable [id]; it cannot select a widget, plugin, size, or executable
/// behavior.
class DashboardModuleDescriptor {
  final String id;
  final int defaultOrdinal;
  final bool defaultVisible;
  final bool defaultCollapsed;
  final bool collapsible;
  final String label;
  final String customizationLabel;
  final DashboardModuleEligibility eligibility;

  const DashboardModuleDescriptor({
    required this.id,
    required this.defaultOrdinal,
    required this.label,
    required this.customizationLabel,
    required this.eligibility,
    this.defaultVisible = true,
    this.defaultCollapsed = false,
    this.collapsible = true,
  });

  B05DashboardModuleDescriptor get foundationDescriptor =>
      B05DashboardModuleDescriptor(
        id: id,
        defaultOrdinal: defaultOrdinal,
        defaultVisible: defaultVisible,
        defaultCollapsed: defaultCollapsed,
        collapsible: collapsible,
        label: label,
      );
}

/// A normalized, presentation-safe dashboard preference. The descriptor is
/// always known, so a consumer never has to infer a widget from database data.
class DashboardModuleLayoutItem {
  final DashboardModuleDescriptor descriptor;
  final int ordinal;
  final bool isVisible;
  final bool isCollapsed;

  const DashboardModuleLayoutItem({
    required this.descriptor,
    required this.ordinal,
    required this.isVisible,
    required this.isCollapsed,
  });

  String get moduleId => descriptor.id;

  DashboardModuleLayoutItem copyWith({
    int? ordinal,
    bool? isVisible,
    bool? isCollapsed,
  }) => DashboardModuleLayoutItem(
    descriptor: descriptor,
    ordinal: ordinal ?? this.ordinal,
    isVisible: isVisible ?? this.isVisible,
    isCollapsed: isCollapsed ?? this.isCollapsed,
  );

  B05DashboardModulePreferenceValue toFoundationValue() =>
      B05DashboardModulePreferenceValue(
        moduleId: moduleId,
        ordinal: ordinal,
        isVisible: isVisible,
        isCollapsed: isCollapsed,
      );

  @override
  bool operator ==(Object other) =>
      other is DashboardModuleLayoutItem &&
      other.moduleId == moduleId &&
      other.ordinal == ordinal &&
      other.isVisible == isVisible &&
      other.isCollapsed == isCollapsed;

  @override
  int get hashCode => Object.hash(moduleId, ordinal, isVisible, isCollapsed);
}

/// The single production registry for B05 dashboard personalization.
///
/// Its order is the registry-default order used when a new descriptor is
/// introduced. The B05-01 normalizer owns the exact persisted-preference
/// algorithm so every consumer gets the same unknown/duplicate/tie behavior.
class DashboardModuleRegistry {
  final List<DashboardModuleDescriptor> descriptors;
  final Map<String, DashboardModuleDescriptor> _byId;
  late final B05DashboardModuleRegistry _foundationRegistry;

  DashboardModuleRegistry(Iterable<DashboardModuleDescriptor> descriptors)
    : this._fromList(List<DashboardModuleDescriptor>.of(descriptors));

  DashboardModuleRegistry._fromList(List<DashboardModuleDescriptor> entries)
    : descriptors = List.unmodifiable(entries),
      _byId = _indexDescriptors(entries) {
    _foundationRegistry = B05DashboardModuleRegistry(
      descriptors.map((descriptor) => descriptor.foundationDescriptor),
    );
  }

  bool contains(String moduleId) => _byId.containsKey(moduleId);

  DashboardModuleDescriptor require(String moduleId) {
    final descriptor = _byId[moduleId];
    if (descriptor == null) {
      throw DashboardPersonalizationValidationException(
        'unknown_module',
        'Dashboard module "$moduleId" is not registered.',
      );
    }
    return descriptor;
  }

  /// Applies the exact B05 contract in one place:
  ///
  /// 1. ignore unknown IDs;
  /// 2. retain the first valid duplicate;
  /// 3. sort valid stored values by ordinal, then ID;
  /// 4. append newly introduced descriptors in registry-default order;
  /// 5. apply descriptor defaults for absent values; and
  /// 6. force non-collapsible modules open.
  List<DashboardModuleLayoutItem> normalize(
    Iterable<B05DashboardModulePreferenceValue> stored,
  ) {
    final normalized = _foundationRegistry.normalize(stored);
    return List.unmodifiable([
      for (final preference in normalized)
        DashboardModuleLayoutItem(
          descriptor: require(preference.moduleId),
          ordinal: preference.ordinal,
          isVisible: preference.isVisible,
          isCollapsed: preference.isCollapsed,
        ),
    ]);
  }
}

class DashboardPersonalizationValidationException extends FormatException {
  final String code;

  DashboardPersonalizationValidationException(this.code, String message)
    : super(message);
}

final DashboardModuleRegistry standardDashboardModuleRegistry =
    DashboardModuleRegistry([
      const DashboardModuleDescriptor(
        id: 'today.workout',
        defaultOrdinal: 0,
        label: 'What should I do?',
        customizationLabel: 'Workout and activity',
        eligibility: DashboardModuleEligibility.workout,
      ),
      const DashboardModuleDescriptor(
        id: 'today.meals',
        defaultOrdinal: 1,
        label: 'What should I eat?',
        customizationLabel: 'Meals and nutrition',
        eligibility: DashboardModuleEligibility.nutrition,
      ),
      const DashboardModuleDescriptor(
        id: 'today.progress',
        defaultOrdinal: 2,
        label: 'How am I progressing?',
        customizationLabel: 'Progress',
        eligibility: DashboardModuleEligibility.progress,
      ),
      const DashboardModuleDescriptor(
        id: 'today.next_action',
        defaultOrdinal: 3,
        label: 'What is my next action?',
        customizationLabel: 'Next action',
        eligibility: DashboardModuleEligibility.nextAction,
        collapsible: false,
      ),
    ]);

Map<String, DashboardModuleDescriptor> _indexDescriptors(
  Iterable<DashboardModuleDescriptor> descriptors,
) {
  final result = <String, DashboardModuleDescriptor>{};
  for (final descriptor in descriptors) {
    if (descriptor.id.trim().isEmpty ||
        descriptor.label.trim().isEmpty ||
        descriptor.customizationLabel.trim().isEmpty ||
        descriptor.defaultOrdinal < 0 ||
        result.containsKey(descriptor.id)) {
      throw DashboardPersonalizationValidationException(
        'invalid_descriptor',
        'Dashboard descriptors require unique stable IDs and labels.',
      );
    }
    result[descriptor.id] = descriptor;
  }
  return Map.unmodifiable(result);
}
