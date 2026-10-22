import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/firebase_ai_gateway.dart';
import '../../core/ai/gemini_requests.dart';
import '../../core/config/app_links.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import 'natural_language_meal_service.dart';

/// Where a reviewed AI item's numbers come from (U-4): the catalogue food it
/// matched, or the AI's own estimate.
String aiItemSourceLabel(DecomposedFoodItem item) {
  final matched = item.matchedCatalogOption;
  return matched == null
      ? 'Estimated by AI'
      : 'Matched: ${matched.displayName}';
}

/// The model the AI tools use, as Remote Config sets it.
final aiModelIdProvider = Provider<String>((ref) {
  try {
    if (Firebase.apps.isEmpty) return GeminiRequests.defaultModel;
    final configured = FirebaseRemoteConfig.instance
        .getString(AiRemoteConfigKeys.model)
        .trim();
    return configured.isEmpty ? GeminiRequests.defaultModel : configured;
  } catch (_) {
    return GeminiRequests.defaultModel;
  }
});

/// One reviewed item in a report: what the AI named it, and the catalogue
/// food it matched, if any.
typedef AiReportItem = ({String name, String? matchedName});

/// The "Report a problem with this result" mail (N14-09, Play's AI content
/// policy). It carries only item names, matched catalogue names, the model
/// id and the app version: no images, no typed text, no targets.
Uri aiResultReportEmail({
  required String feature,
  required List<AiReportItem> items,
  required String modelId,
  required String? appVersion,
}) {
  final version = appVersion == null || appVersion.trim().isEmpty
      ? 'unknown'
      : appVersion.trim();
  final body = [
    'Something was wrong with this AI result:',
    '',
    '',
    'Feature: $feature',
    'Items:',
    for (final item in items)
      '- ${item.name} → '
          '${item.matchedName == null ? 'no catalogue match' : item.matchedName!}',
    'Model: $modelId',
    'App version: $version',
  ].join('\n');
  // mailto wants %20, not the + that Uri's queryParameters writes.
  String encode(String value) => Uri.encodeComponent(value);
  return Uri.parse(
    'mailto:${AppLinks.supportEmail}'
    '?subject=${encode('Problem with an AI result')}&body=${encode(body)}',
  );
}

/// The report row shown under each AI review (describe, photo, label).
class AiResultReportRow extends ConsumerWidget {
  const AiResultReportRow({
    super.key,
    required this.feature,
    required this.items,
  });

  final String feature;
  final List<AiReportItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      key: const ValueKey('ai_result_report_row'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.flag_outlined),
      title: const Text('Report a problem with this result'),
      subtitle: Text(
        'Emails the item names only',
        style: B05Typography.caption(context),
      ),
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        final version = await ref.read(appVersionLabelProvider.future);
        final opened = await AppLinks.open(
          aiResultReportEmail(
            feature: feature,
            items: items,
            modelId: ref.read(aiModelIdProvider),
            appVersion: version,
          ),
        );
        if (!opened) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'No mail app found. Write to ${AppLinks.supportEmail}.',
              ),
            ),
          );
        }
      },
    );
  }
}
