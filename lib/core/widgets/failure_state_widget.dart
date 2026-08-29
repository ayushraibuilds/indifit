import 'package:flutter/material.dart';
import '../errors/app_failure.dart';
import '../presentation/product_failure_presentation.dart';
import '../theme/b05_semantic_colors.dart';
import 'b05_accessibility_primitives.dart';

class FailureStateWidget extends StatelessWidget {
  final AppFailure failure;
  final VoidCallback? onRetry;
  final String? retryLabel;

  const FailureStateWidget({
    super.key,
    required this.failure,
    this.onRetry,
    this.retryLabel,
  });

  IconData _getIconForType(AppFailureType type) {
    return switch (type) {
      AppFailureType.offlinePolicyBlocked => Icons.cloud_off_rounded,
      AppFailureType.permissionDenied => Icons.security_rounded,
      AppFailureType.validation => Icons.edit_attributes_rounded,
      AppFailureType.network => Icons.wifi_off_rounded,
      AppFailureType.server => Icons.dns_rounded,
      AppFailureType.unsupportedPlatform => Icons.phone_disabled_rounded,
      AppFailureType.corruptedBackup => Icons.folder_zip_rounded,
      AppFailureType.unknown => Icons.error_outline_rounded,
    };
  }

  Color _getColorForType(BuildContext context, AppFailureType type) {
    final colors = context.b05Colors;
    return switch (type) {
      AppFailureType.offlinePolicyBlocked => colors.info.indicator,
      AppFailureType.permissionDenied => colors.warning.indicator,
      AppFailureType.validation => colors.warning.indicator,
      AppFailureType.network => colors.warning.indicator,
      AppFailureType.server => colors.danger.indicator,
      AppFailureType.unsupportedPlatform => colors.textDisabled,
      AppFailureType.corruptedBackup => colors.danger.indicator,
      AppFailureType.unknown => colors.danger.indicator,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final iconColor = _getColorForType(context, failure.type);
    final icon = _getIconForType(failure.type);
    final presentation = ProductFailurePresentation.fromAppFailure(failure);

    return B05Surface(
      radius: B05SurfaceRadius.large,
      subtle: true,
      showBorder: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: iconColor.withValues(alpha: 0.15),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            presentation.message,
            textAlign: TextAlign.center,
            style: B05Typography.caption(context).copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              if (onRetry != null)
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(retryLabel ?? 'Retry'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.action,
                    foregroundColor: colors.onAction,
                  ),
                ),
              if (failure.actionLabel != null && failure.onAction != null)
                OutlinedButton.icon(
                  onPressed: failure.onAction,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(failure.actionLabel!),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: iconColor,
                    side: BorderSide(color: iconColor),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
