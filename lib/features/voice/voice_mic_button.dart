import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/voice/on_device_speech.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';

/// The mic for food search and Describe a meal (TF-2 B, UF-7). Build it
/// only when [voiceInputAvailabilityProvider] has a language: with no
/// on-device recognition the mic is hidden and Settings says why.
class VoiceMicButton extends ConsumerWidget {
  const VoiceMicButton({
    super.key,
    required this.locales,
    required this.onTranscript,
  });

  final List<VoiceLocale> locales;
  final ValueChanged<String> onTranscript;

  /// A mic for [onTranscript] when voice input is available, otherwise null.
  static Widget? maybe(
    WidgetRef ref, {
    required ValueChanged<String> onTranscript,
  }) {
    final availability = ref.watch(voiceInputAvailabilityProvider).value;
    if (availability == null || !availability.isAvailable) return null;
    return VoiceMicButton(
      locales: availability.locales,
      onTranscript: onTranscript,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Say what you ate',
      icon: const Icon(Icons.mic_none_rounded),
      onPressed: () async {
        final words = await captureSpeech(context, ref, locales);
        if (words != null && words.trim().isNotEmpty) {
          onTranscript(words.trim());
        }
      },
    );
  }
}

/// Explains, then asks for the microphone, then listens. Null when the user
/// stops, says nothing or declines.
Future<String?> captureSpeech(
  BuildContext context,
  WidgetRef ref,
  List<VoiceLocale> locales,
) async {
  final engine = ref.read(voiceEngineProvider);
  final messenger = ScaffoldMessenger.of(context);
  if (!await engine.hasPermission()) {
    if (!context.mounted) return null;
    // The system prompt comes only after this explanation.
    final allow = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _VoicePermissionSheet(),
    );
    if (allow != true) return null;
    if (!await engine.requestPermission()) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            "The microphone is off. Allow it in your phone's settings to say "
            'what you ate.',
          ),
        ),
      );
      return null;
    }
  }
  if (!context.mounted) return null;
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isDismissible: false,
    builder: (context) => _ListeningSheet(locales: locales),
  );
}

class _VoicePermissionSheet extends StatelessWidget {
  const _VoicePermissionSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          B05Layout.space16,
          0,
          B05Layout.space16,
          B05Layout.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Say what you ate', style: B05Typography.title(context)),
            const SizedBox(height: B05Layout.space12),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.phone_android_rounded),
              title: Text('Recognised on this phone'),
              subtitle: Text(
                'IndiFit turns your words into foods on the device. The audio '
                'is never stored or sent, so it works with Offline Mode on.',
              ),
            ),
            const SizedBox(height: B05Layout.space12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Not now'),
                  ),
                ),
                const SizedBox(width: B05Layout.space12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Allow microphone'),
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

class _ListeningSheet extends ConsumerStatefulWidget {
  const _ListeningSheet({required this.locales});

  final List<VoiceLocale> locales;

  @override
  ConsumerState<_ListeningSheet> createState() => _ListeningSheetState();
}

class _ListeningSheetState extends ConsumerState<_ListeningSheet> {
  late VoiceLocale _locale = widget.locales.first;
  late final VoiceEngine _engine = ref.read(voiceEngineProvider);
  String _words = '';
  String? _error;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  Future<void> _listen() async {
    setState(() {
      _words = '';
      _error = null;
    });
    await _engine.listen(
      _locale,
      onWords: (words, isFinal) {
        if (!mounted || _done) return;
        setState(() => _words = words);
        if (isFinal) _finish();
      },
      onError: (error) {
        if (!mounted || _done) return;
        if (error.contains('language')) {
          // Not on the device after all (Android 12 can't say up front).
          final failed = ref.read(voiceLocaleFailuresProvider.notifier);
          failed.state = {...failed.state, _locale};
        }
        setState(
          () => _error = error.contains('no_match') || error.contains('speech')
              ? "Didn't catch that. Try again."
              : 'Voice input stopped. Type it instead, or try again.',
        );
      },
    );
  }

  void _finish() {
    if (_done) return;
    _done = true;
    Navigator.of(context).pop(_words);
  }

  Future<void> _switch(VoiceLocale locale) async {
    await _engine.cancel();
    if (!mounted) return;
    setState(() => _locale = locale);
    await _listen();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          B05Layout.space16,
          0,
          B05Layout.space16,
          B05Layout.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _error == null ? 'Listening…' : 'Not heard',
              style: B05Typography.title(context),
            ),
            const SizedBox(height: B05Layout.space8),
            Text(
              _error ??
                  (_words.isEmpty ? 'e.g. do roti aur ek katori dal' : _words),
              style: B05Typography.body(context),
            ),
            if (widget.locales.length > 1) ...[
              const SizedBox(height: B05Layout.space12),
              SegmentedButton<VoiceLocale>(
                segments: [
                  for (final locale in widget.locales)
                    ButtonSegment(value: locale, label: Text(locale.label)),
                ],
                selected: {_locale},
                onSelectionChanged: (selection) => _switch(selection.first),
              ),
            ],
            const SizedBox(height: B05Layout.space16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      _done = true;
                      await _engine.cancel();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: B05Layout.space12),
                Expanded(
                  child: _error != null
                      ? FilledButton(
                          onPressed: _listen,
                          child: const Text('Try again'),
                        )
                      : FilledButton(
                          onPressed: _words.isEmpty
                              ? null
                              : () async {
                                  await _engine.stop();
                                  _finish();
                                },
                          child: const Text('Done'),
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
