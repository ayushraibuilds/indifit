import 'package:flutter/material.dart';
import '../errors/app_failure.dart';
import '../presentation/product_failure_presentation.dart';
import '../theme/colors.dart';

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

  Color _getColorForType(AppFailureType type) {
    return switch (type) {
      AppFailureType.offlinePolicyBlocked => Colors.cyan,
      AppFailureType.permissionDenied => Colors.amber,
      AppFailureType.validation => Colors.orange,
      AppFailureType.network => Colors.deepOrangeAccent,
      AppFailureType.server => AppColors.danger,
      AppFailureType.unsupportedPlatform => Colors.grey,
      AppFailureType.corruptedBackup => AppColors.danger,
      AppFailureType.unknown => AppColors.danger,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = _getColorForType(failure.type);
    final icon = _getIconForType(failure.type);
    final presentation = ProductFailurePresentation.fromAppFailure(failure);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
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
              style: theme.textTheme.bodyMedium?.copyWith(
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
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(retryLabel ?? 'Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
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
      ),
    );
  }
}
