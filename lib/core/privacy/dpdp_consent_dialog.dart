import 'package:flutter/material.dart';

import '../config/app_links.dart';
import '../theme/b05_semantic_colors.dart';
import '../widgets/b05_accessibility_primitives.dart';
import '../widgets/indi_fit_bottom_sheet.dart';

/// Consent sheet shown before meal text or photos are sent to a third-party
/// AI, as required by India's DPDP Act 2023 and App Store Review Guideline
/// 5.1.2(i): it names the recipient and what is sent, and must stay accurate.
/// Changing what it says requires bumping [DpdpConsentService.currentVersion].
///
/// Only claim what IndiFit itself guarantees. Retention and training terms
/// belong to the provider's plan, so they are not promised here.
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
                  'Use AI to read your meals?',
                  style: B05Typography.title(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: B05Layout.space16),
          Text(
            'To turn a meal description, food photo or nutrition label into '
            'foods you can log, IndiFit sends it to Google\'s Gemini AI '
            '(through Google Firebase). This happens only when you use these '
            'AI features.',
            style: B05Typography.body(context),
          ),
          const SizedBox(height: B05Layout.space16),
          _buildPillarRow(
            context,
            icon: Icons.upload_outlined,
            title: 'What is sent',
            description:
                'Only the text you type or the photo you choose. Nothing else '
                'from your diary, profile or health data.',
          ),
          const SizedBox(height: B05Layout.space12),
          _buildPillarRow(
            context,
            icon: Icons.inventory_2_outlined,
            title: 'What IndiFit keeps',
            description:
                'IndiFit doesn\'t store your photos or descriptions. Only the '
                'foods you confirm are saved, on this device. Google\'s '
                'handling is covered by its terms, linked in our privacy '
                'policy.',
          ),
          const SizedBox(height: B05Layout.space12),
          _buildPillarRow(
            context,
            icon: Icons.tune_rounded,
            title: 'You stay in control',
            description:
                'You review every item before it\'s logged. Withdraw consent '
                'anytime in Settings → Manage your data → AI meal assistance. '
                'Food search works without AI.',
          ),
          const SizedBox(height: B05Layout.space8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('dpdp_consent_privacy_policy_link'),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Privacy policy'),
              onPressed: () => AppLinks.open(AppLinks.privacyPolicy),
            ),
          ),
          const SizedBox(height: B05Layout.space16),
          Row(
            children: [
              Expanded(
                child: B05ActionButton(
                  key: const Key('dpdp_consent_cancel_button'),
                  label: 'Not now',
                  emphasis: B05ActionEmphasis.secondary,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: B05Layout.space12),
              Expanded(
                child: B05ActionButton(
                  key: const Key('dpdp_consent_agree_button'),
                  label: 'Allow AI',
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
                style: B05Typography.label(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: B05Typography.caption(
                  context,
                ).copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
