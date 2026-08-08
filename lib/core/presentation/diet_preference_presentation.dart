import 'package:flutter/material.dart';

/// The consumer-facing choices for the persisted diet preference.
///
/// The application has historically persisted both `non-veg` and `non_veg`.
/// This adapter deliberately keeps those identities as accepted aliases while
/// exposing one stable value to widgets. It does not migrate or rewrite stored
/// data by itself.
class DietPreferenceOption {
  const DietPreferenceOption({
    required this.uiValue,
    required this.preferredPersistedValue,
    required this.label,
    required this.description,
    required this.icon,
    required this.persistedAliases,
  });

  final String uiValue;
  final String preferredPersistedValue;
  final String label;
  final String description;
  final IconData icon;
  final Set<String> persistedAliases;

  bool accepts(String? rawValue) {
    final value = rawValue?.trim().toLowerCase();
    return value != null && persistedAliases.contains(value);
  }
}

abstract final class DietPreferencePresentation {
  static const options = <DietPreferenceOption>[
    DietPreferenceOption(
      uiValue: 'veg',
      preferredPersistedValue: 'veg',
      label: 'Vegetarian (Paneer, Curd, Dals)',
      description: 'Pure veg, dairy products allowed',
      icon: Icons.eco,
      persistedAliases: {'veg'},
    ),
    DietPreferenceOption(
      uiValue: 'non_veg',
      preferredPersistedValue: 'non-veg',
      label: 'Non-Vegetarian (Chicken, Eggs, Fish)',
      description: 'Chicken, fish, eggs, meat included',
      icon: Icons.restaurant,
      persistedAliases: {'non-veg', 'non_veg'},
    ),
    DietPreferenceOption(
      uiValue: 'vegan',
      preferredPersistedValue: 'vegan',
      label: 'Vegan (Plant-based, Tofu, Soya)',
      description: '100% plant-based, no animal products',
      icon: Icons.spa,
      persistedAliases: {'vegan'},
    ),
  ];

  /// Returns the one widget value represented by a persisted/legacy value.
  /// Unknown and null values intentionally return null rather than guessing.
  static String? uiValueFor(String? persistedValue) {
    for (final option in options) {
      if (option.accepts(persistedValue)) return option.uiValue;
    }
    return null;
  }

  static DietPreferenceOption? optionForUiValue(String? uiValue) {
    for (final option in options) {
      if (option.uiValue == uiValue) return option;
    }
    return null;
  }

  /// Returns the source value when it already represents [uiValue]. This
  /// preserves historical identities until a user explicitly changes a value.
  static String persistedValueFor({
    required String? originalValue,
    required String uiValue,
    bool userChanged = false,
  }) {
    final option = optionForUiValue(uiValue);
    if (option == null) return originalValue ?? 'veg';
    if (!userChanged && originalValue != null) return originalValue.trim();
    if (option.accepts(originalValue)) return originalValue!.trim();
    return option.preferredPersistedValue;
  }

  /// The existing onboarding draft convention uses the hyphenated alias.
  static String normalizeForOnboarding(String? persistedValue) {
    final uiValue = uiValueFor(persistedValue) ?? 'veg';
    return optionForUiValue(uiValue)!.preferredPersistedValue;
  }
}

/// A dropdown that can safely consume a raw persisted diet value.
class DietPreferenceDropdown extends StatelessWidget {
  const DietPreferenceDropdown({
    super.key,
    this.persistedValue,
    this.selectedUiValue,
    required this.onChanged,
    this.decoration = const InputDecoration(
      labelText: 'Diet Choice',
      prefixIcon: Icon(Icons.restaurant_rounded),
    ),
  });

  final String? persistedValue;
  final String? selectedUiValue;
  final ValueChanged<String?>? onChanged;
  final InputDecoration decoration;

  @override
  Widget build(BuildContext context) {
    final selected =
        selectedUiValue ??
        DietPreferencePresentation.uiValueFor(persistedValue);
    final safeSelected = DietPreferencePresentation.optionForUiValue(
      selected,
    )?.uiValue;

    return DropdownButtonFormField<String>(
      initialValue: safeSelected,
      isExpanded: true,
      decoration: decoration,
      items: [
        for (final option in DietPreferencePresentation.options)
          DropdownMenuItem<String>(
            value: option.uiValue,
            child: Text(option.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
