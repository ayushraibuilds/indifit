import 'package:flutter/material.dart';

/// Search input bar extracted from `food_search_screen.dart`.
///
/// Encapsulates search text field styling, clear button, and focus dismiss.
class FoodSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final VoidCallback? onClear;
  final ValueChanged<PointerDownEvent>? onTapOutside;
  final String labelText;
  final String hintText;

  const FoodSearchBar({
    super.key,
    required this.controller,
    this.focusNode,
    this.autofocus = false,
    this.onClear,
    this.onTapOutside,
    this.labelText = 'Search foods',
    this.hintText = 'Roti, paneer bhurji, dal, idli…',
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: autofocus,
          textInputAction: TextInputAction.search,
          onTapOutside: onTapOutside ?? (_) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            labelText: labelText,
            hintText: hintText,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: value.text.isNotEmpty
                ? IconButton(
                    tooltip: 'Clear food search',
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: onClear ?? () => controller.clear(),
                  )
                : null,
          ),
        );
      },
    );
  }
}
