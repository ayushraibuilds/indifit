import 'package:flutter/material.dart';

import '../theme/b05_semantic_colors.dart';
import '../widgets/b05_accessibility_primitives.dart';
import '../widgets/indi_fit_bottom_sheet.dart';

/// One-time consent dialog/sheet required under India's Digital Personal Data
/// Protection (DPDP) Act 2023 and Apple App Store Review Guideline 5.1.1 prior to
/// transmitting photos to cloud AI services (Google Gemini).
class DpdpConsentDialog extends StatelessWidget {
  const DpdpConsentDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showIndiFitBottomSheet<bool>(
      context: context,
      semanticLabel: 'Data privacy and AI consent',
      builder: (ctx) => const DpdpConsentDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;

    return SingleChildScrollView(
      key: const Key('dpdp_consent_sheet'),
      padding: const EdgeInsets.fromLTRB(
        B05Layout.space20,
        B05Layout.space12,
        B05Layout.space20,
        B05Layout.space24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(B05Layout.space8),
                decoration: BoxDecoration(
                  color: colors.info.container,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: colors.info.indicator,
                  size: B05Layout.iconMedium,
                ),
              ),
              const SizedBox(width: B05Layout.space12),
              Expanded(
                child: Text(
                  'Data Privacy & AI Consent',
                  style: B05Typography.title(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: B05Layout.space16),
          Text(
            'Under India\'s Digital Personal Data Protection (DPDP) Act and store guidelines, '
            'IndiFit requires your explicit consent before analyzing food photos with cloud AI services.',
            style: B05Typography.body(context),
          ),
          const SizedBox(height: B05Layout.space16),
          _buildPillarRow(
            context,
            icon: Icons.flash_on_outlined,
            title: 'Ephemeral Processing',
            description:
                'Images are transmitted over encrypted TLS, processed in memory for label OCR, and discarded immediately.',
          ),
          const SizedBox(height: B05Layout.space12),
          _buildPillarRow(
            context,
            icon: Icons.block_flipped,
            title: 'No AI Training',
            description:
                'Your captures are never stored permanently, never reviewed by humans, and never used to train AI models.',
          ),
          const SizedBox(height: B05Layout.space12),
          _buildPillarRow(
            context,
            icon: Icons.lock_outline_rounded,
            title: 'Local Control',
            description:
                'Extracted nutrition facts save to your on-device SQLite database. You can review or edit everything before logging.',
          ),
          const SizedBox(height: B05Layout.space24),
          Row(
            children: [
              Expanded(
                child: B05ActionButton(
                  key: const Key('dpdp_consent_cancel_button'),
                  label: 'Cancel',
                  emphasis: B05ActionEmphasis.secondary,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: B05Layout.space12),
              Expanded(
                child: B05ActionButton(
                  key: const Key('dpdp_consent_agree_button'),
                  label: 'Agree & Continue',
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPillarRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final colors = context.b05Colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: B05Layout.iconSmall, color: colors.info.indicator),
        const SizedBox(width: B05Layout.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: B05Typography.label(context).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: B05Typography.caption(context).copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
