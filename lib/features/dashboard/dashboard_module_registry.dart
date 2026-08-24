import '../../core/fixtures/b05_foundation_registry.dart';

/// The known dashboard areas that a presentation adapter may make available.
///
/// This is deliberately a packaged capability hint, not an evaluation of a
/// workout, nutrition, progress, or coaching fact. B05-04 supplies the
/// corresponding read adapters from the existing B01–B04 authorities.
enum DashboardModuleEligibility {
  workout,
  nutrition,
  activity,
  progress,
  nextAction,
}

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
  final String customizationDescription;
  final bool showInCustomizeToday;
  final DashboardModuleEligibility eligibility;

  const DashboardModuleDescriptor({
    required this.id,
    required this.defaultOrdinal,
    required this.label,
    required this.customizationLabel,
    required this.eligibility,
    this.customizationDescription = '',
    this.showInCustomizeToday = false,
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
        id: 'today.next_action',
        defaultOrdinal: 0,
        label: 'Next up',
        customizationLabel: 'Next up',
        customizationDescription: 'See the most useful next step for today.',
        showInCustomizeToday: true,
        eligibility: DashboardModuleEligibility.nextAction,
        collapsible: false,
      ),
      const DashboardModuleDescriptor(
        id: 'today.meals',
        defaultOrdinal: 1,
        label: 'Nutrition',
        customizationLabel: 'Nutrition',
        customizationDescription: 'Keep your daily nutrition summary close.',
        showInCustomizeToday: true,
        eligibility: DashboardModuleEligibility.nutrition,
      ),
      const DashboardModuleDescriptor(
        id: 'today.meal_rows',
        defaultOrdinal: 2,
        label: 'Meals',
        customizationLabel: 'Meals',
        customizationDescription: "Log and review today's meals.",
        showInCustomizeToday: true,
        eligibility: DashboardModuleEligibility.nutrition,
      ),
      const DashboardModuleDescriptor(
        id: 'today.workout',
        defaultOrdinal: 3,
        label: 'Workout',
        customizationLabel: 'Workout',
        customizationDescription: "Keep today's workout within reach.",
        showInCustomizeToday: true,
        eligibility: DashboardModuleEligibility.workout,
        defaultVisible: false,
      ),
      const DashboardModuleDescriptor(
        id: 'today.activity',
        defaultOrdinal: 4,
        label: 'Activity',
        customizationLabel: 'Activity',
        customizationDescription: 'See your activity and recovery details.',
        showInCustomizeToday: true,
        eligibility: DashboardModuleEligibility.activity,
        defaultVisible: false,
      ),
      const DashboardModuleDescriptor(
        id: 'today.progress',
        defaultOrdinal: 5,
        label: 'Progress',
        customizationLabel: 'Progress',
        customizationDescription: 'Check your progress for the day.',
        showInCustomizeToday: true,
        eligibility: DashboardModuleEligibility.progress,
        defaultVisible: false,
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
