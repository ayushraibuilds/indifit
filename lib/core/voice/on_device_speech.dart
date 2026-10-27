import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// The languages voice logging listens in (TF-2 B, UF-7).
enum VoiceLocale {
  englishIndia('en_IN', 'en-IN', 'English (India)'),
  hindi('hi_IN', 'hi-IN', 'हिन्दी');

  const VoiceLocale(this.pluginId, this.tag, this.label);

  /// The id speech_to_text takes.
  final String pluginId;

  /// The BCP 47 tag the on-device check takes.
  final String tag;
  final String label;
}

/// Whether one language can be recognised on the device.
class OnDeviceSpeechSupport {
  const OnDeviceSpeechSupport.available() : available = true, reason = null;
  const OnDeviceSpeechSupport.unavailable(this.reason) : available = false;

  final bool available;

  /// os_too_old, no_on_device_recognizer, language_not_downloaded,
  /// language_not_supported, check_failed or unsupported_platform.
  final String? reason;
}

/// Speech recognition, on the device only (D2). Audio is never stored or
/// sent: the engine hands back words, and only when the platform recognises
/// them locally.
abstract class VoiceEngine {
  Future<OnDeviceSpeechSupport> onDeviceSupport(VoiceLocale locale);

  Future<bool> hasPermission();

  /// Shows the system microphone (and, on iOS, speech) prompts.
  Future<bool> requestPermission();

  Future<void> listen(
    VoiceLocale locale, {
    required void Function(String words, bool isFinal) onWords,
    required void Function(String error) onError,
  });

  Future<void> stop();

  Future<void> cancel();
}

/// speech_to_text 7.4.0 (the newest for Flutter 3.41) with `onDevice: true`:
/// on iOS it sets requiresOnDeviceRecognition. On Android it falls back to
/// the network recognizer when the on-device one is missing, so
/// [onDeviceSupport] asks the platform first through a small channel
/// (MainActivity.kt, AppDelegate.swift), and the app listens only when it
/// says yes.
class PluginVoiceEngine implements VoiceEngine {
  PluginVoiceEngine({SpeechToText? speech, MethodChannel? channel})
    : _speech = speech ?? SpeechToText(),
      _channel =
          channel ??
          const MethodChannel('com.indifit.indifit/speech_on_device');

  final SpeechToText _speech;
  final MethodChannel _channel;
  bool _initialized = false;
  void Function(String error)? _onError;

  @override
  Future<OnDeviceSpeechSupport> onDeviceSupport(VoiceLocale locale) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return const OnDeviceSpeechSupport.unavailable('unsupported_platform');
    }
    try {
      final reply = await _channel.invokeMapMethod<String, Object?>(
        'onDeviceSupport',
        {'locale': locale.tag},
      );
      if (reply?['available'] == true) {
        return const OnDeviceSpeechSupport.available();
      }
      return OnDeviceSpeechSupport.unavailable(
        reply?['reason'] as String? ?? 'check_failed',
      );
    } on PlatformException {
      return const OnDeviceSpeechSupport.unavailable('check_failed');
    } on MissingPluginException {
      return const OnDeviceSpeechSupport.unavailable('unsupported_platform');
    }
  }

  @override
  Future<bool> hasPermission() => _speech.hasPermission;

  @override
  Future<bool> requestPermission() => _initialize();

  Future<bool> _initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: (SpeechRecognitionError error) => _onError?.call(error.errorMsg),
    );
    return _initialized;
  }

  @override
  Future<void> listen(
    VoiceLocale locale, {
    required void Function(String words, bool isFinal) onWords,
    required void Function(String error) onError,
  }) async {
    if (!await _initialize()) {
      onError('permission_denied');
      return;
    }
    _onError = onError;
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) =>
          onWords(result.recognizedWords, result.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: locale.pluginId,
        onDevice: true,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}

/// Which languages voice logging can use on this phone; empty, with a
/// [reason], when neither can be recognised on the device.
class VoiceInputAvailability {
  const VoiceInputAvailability(this.locales, {this.reason});

  final List<VoiceLocale> locales;
  final String? reason;

  bool get isAvailable => locales.isNotEmpty;

  /// For Settings: why the mic is hidden.
  String get summary => isAvailable
      ? 'On this phone only · ${locales.map((l) => l.label).join(', ')}'
      : unavailableText(reason);

  static String unavailableText(String? reason) => switch (reason) {
    'os_too_old' => 'Needs Android 12 or later for on-device speech',
    'no_on_device_recognizer' =>
      'This phone has no on-device speech recognition',
    'language_not_downloaded' =>
      "Download English (India) or Hindi for on-device speech in your phone's settings",
    'unsupported_platform' => 'Voice input needs an Android phone or iPhone',
    _ => "On-device speech isn't available for English (India) or Hindi here",
  };
}

final voiceEngineProvider = Provider<VoiceEngine>((ref) => PluginVoiceEngine());

/// Languages that failed to listen on the device this session: a phone on
/// Android 12 can't list its on-device languages up front.
final voiceLocaleFailuresProvider = StateProvider<Set<VoiceLocale>>(
  (ref) => const {},
);

/// Whether the mic shows. Offline Mode doesn't matter: nothing is sent.
final voiceInputAvailabilityProvider = FutureProvider<VoiceInputAvailability>((
  ref,
) async {
  final engine = ref.watch(voiceEngineProvider);
  final failed = ref.watch(voiceLocaleFailuresProvider);
  final locales = <VoiceLocale>[];
  String? reason;
  for (final locale in VoiceLocale.values) {
    if (failed.contains(locale)) {
      reason ??= 'language_not_supported';
      continue;
    }
    final support = await engine.onDeviceSupport(locale);
    if (support.available) {
      locales.add(locale);
    } else {
      reason ??= support.reason;
    }
  }
  return VoiceInputAvailability(locales, reason: reason);
});
