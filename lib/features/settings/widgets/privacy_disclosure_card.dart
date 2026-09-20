import 'package:flutter/material.dart';

import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';

/// A factual explanation of the app's local-first and opt-in network
/// behaviour. The controls themselves live beside this explanation so there
/// is one owner for each persisted privacy preference.
class PrivacyDisclosureCard extends StatelessWidget {
  final bool offlineOnly;
  final bool crashReportingEnabled;

  const PrivacyDisclosureCard({
    super.key,
    this.offlineOnly = false,
    this.crashReportingEnabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final offlineCopy = offlineOnly
        ? 'Offline mode is on, so app-initiated online requests are blocked.'
        : 'Offline mode is off, so online features can be used when you choose them.';
    final crashCopy = crashReportingEnabled
        ? 'Crash diagnostics are currently enabled.'
        : 'Crash diagnostics are currently off.';

    return B05Surface(
      padding: const EdgeInsets.all(B05Layout.space16),
      showBorder: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.privacy_tip_outlined,
                color: colors.info.indicator,
                size: B05Layout.iconMedium,
              ),
              const SizedBox(width: B05Layout.space8),
              Expanded(
                child: Text(
                  'How your data is handled',
                  style: B05Typography.title(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: B05Layout.space8),
          Text(
            'Most IndiFit data is stored on this device. A backup or food and workout summary leaves the app only when you choose to share or copy it.',
            style: B05Typography.body(context),
          ),
          const SizedBox(height: B05Layout.space12),
          Text(
            'IndiFit stores your logs on this device. Connected features like nutrition label scanning process photos ephemerally and never retain them. Online food search sends only the search or barcode request needed for that feature. Crash diagnostics are optional and off by default.',
            style: B05Typography.body(context),
          ),
          const SizedBox(height: B05Layout.space12),
          B05StatusMessage(status: B05SemanticStatus.info, label: offlineCopy),
          const SizedBox(height: B05Layout.space8),
          B05StatusMessage(status: B05SemanticStatus.info, label: crashCopy),
        ],
      ),
    );
  }
}
