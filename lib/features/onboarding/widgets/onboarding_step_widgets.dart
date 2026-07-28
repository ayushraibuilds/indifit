import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';

class OnboardingPageContainer extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const OnboardingPageContainer({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              fontFamily: GoogleFonts.outfit().fontFamily,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontFamily: GoogleFonts.outfit().fontFamily,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          Expanded(child: SingleChildScrollView(child: child)),
        ],
      ),
    );
  }
}

class OnboardingSelectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const OnboardingSelectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.04)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : const Color(0x1F223250),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: GoogleFonts.outfit().fontFamily,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontFamily: GoogleFonts.outfit().fontFamily,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

class OnboardingNumberInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String suffix;
  final IconData icon;
  final String? errorText;

  const OnboardingNumberInputField({
    super.key,
    required this.controller,
    required this.label,
    required this.suffix,
    required this.icon,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    final isValid = !hasError && controller.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasError
                  ? AppColors.danger
                  : (isValid ? AppColors.success : AppColors.border),
              width: hasError || isValid ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: hasError ? AppColors.danger : AppColors.textSecondary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: GoogleFonts.outfit().fontFamily,
                  ),
                  decoration: InputDecoration(
                    labelText: label,
                    labelStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (isValid)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 18,
                )
              else if (hasError)
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.danger,
                  size: 18,
                )
              else
                Text(
                  suffix,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: GoogleFonts.outfit().fontFamily,
                  ),
                ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: Text(
              errorText!,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
