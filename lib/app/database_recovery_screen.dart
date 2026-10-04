import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/utils/app_logger.dart';
import 'database_readiness.dart';

/// Shown while the database opens (migrations can take a few seconds after an
/// update). Deliberately has no timeout or error state of its own.
class DatabasePreparingScreen extends StatelessWidget {
  const DatabasePreparingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Getting your data ready…', style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

/// Shown when the database can't be opened. Uses no providers and never
/// touches the database, so it works whatever state the data is in. It never
/// offers to delete anything: the files on the device may be the only copy.
class DatabaseRecoveryScreen extends StatefulWidget {
  const DatabaseRecoveryScreen({
    super.key,
    required this.error,
    required this.onRetry,
    this.exportFiles = _shareDatabaseFiles,
    this.contactSupport = _emailSupport,
  });

  final Object error;
  final VoidCallback onRetry;

  /// Shares the database files; returns false if there was nothing to share.
  final Future<bool> Function() exportFiles;
  final Future<void> Function(String errorType) contactSupport;

  static const supportEmail = 'privacy@indifit.app';

  @override
  State<DatabaseRecoveryScreen> createState() => _DatabaseRecoveryScreenState();
}

class _DatabaseRecoveryScreenState extends State<DatabaseRecoveryScreen> {
  var _exporting = false;
  String? _exportMessage;

  Future<void> _export() async {
    setState(() {
      _exporting = true;
      _exportMessage = null;
    });
    String? message;
    try {
      final shared = await widget.exportFiles();
      if (!shared) message = 'No data files were found on this device.';
    } on Object catch (error, stackTrace) {
      AppLogger.error('Database file export failed', error, stackTrace);
      message = "The files couldn't be shared. Please try again.";
    }
    if (!mounted) return;
    setState(() {
      _exporting = false;
      _exportMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storageFull =
        classifyDatabaseOpenFailure(widget.error) ==
        DatabaseOpenFailure.storageFull;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            Icon(
              Icons.storage_rounded,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              storageFull
                  ? 'Your phone is out of storage'
                  : "IndiFit couldn't open your data",
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              storageFull
                  ? 'IndiFit needs a little free space to open your data. '
                        'Free up some space, then tap Try again. '
                        'Nothing has been deleted.'
                  : 'Your data has not been deleted. Tap Try again. If this '
                        'keeps happening, save a copy of your data files and '
                        'contact us.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: widget.onRetry,
              child: const Text('Try again'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _exporting ? null : _export,
              child: Text(
                _exporting ? 'Preparing files…' : 'Save a copy of my data',
              ),
            ),
            if (_exportMessage != null) ...[
              const SizedBox(height: 8),
              Text(_exportMessage!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  widget.contactSupport(widget.error.runtimeType.toString()),
              child: const Text('Contact support'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> _shareDatabaseFiles() async {
  final files = await existingDatabaseFiles();
  if (files.isEmpty) return false;
  await Share.shareXFiles([
    for (final File file in files) XFile(file.path),
  ], subject: 'IndiFit data files');
  return true;
}

/// Sends only the error *type*: messages can contain user data.
Future<void> _emailSupport(String errorType) async {
  final uri = supportEmailUri(errorType);
  if (!await launchUrl(uri)) {
    AppLogger.warning('No email app to contact support', 'DatabaseRecovery');
  }
}

/// The support email. Built by hand: `Uri(queryParameters:)` encodes spaces
/// as `+`, which mail apps show literally.
Uri supportEmailUri(String errorType) {
  String encode(String value) => Uri.encodeComponent(value);
  final subject = encode("IndiFit couldn't open my data");
  final body = encode(
    'Error type: $errorType\nPlatform: ${Platform.operatingSystem}',
  );
  return Uri.parse(
    'mailto:${DatabaseRecoveryScreen.supportEmail}?subject=$subject&body=$body',
  );
}
