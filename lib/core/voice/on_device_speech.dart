import 'dart:async';

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

/// The first Android API with SpeechRecognizer.createOnDeviceSpeechRecognizer.
const int kAndroidOnDeviceSpeechMinSdk = 31;

/// Whether this Android API level may listen at all: below 31 there is no
/// on-device recognizer, only the network one, so the mic stays hidden.
bool androidAllowsOnDeviceSpeech(int? sdkInt) =>
    sdkInt != null && sdkInt >= kAndroidOnDeviceSpeechMinSdk;

/// On-device speech, never the network recognizer (D2).
///
/// - Android: MainActivity.kt's channel. It only ever creates
///   SpeechRecognizer.createOnDeviceSpeechRecognizer (API 31+) and fails
///   rather than fall back. speech_to_text 7.4.0 is used only for the
///   microphone permission prompt there: its own listen falls back to
///   the network recognizer when the on-device one is missing.
/// - iOS: speech_to_text 7.4.0 with `onDevice: true`, which sets
///   requiresOnDeviceRecognition; AppDelegate.swift's channel answers
///   whether the language is on the device.
class PluginVoiceEngine implements VoiceEngine {
  PluginVoiceEngine({
    SpeechToText? speech,
    MethodChannel? channel,
    EventChannel? androidResults,
    TargetPlatform? platform,
  }) : _speech = speech ?? SpeechToText(),
       _channel = channel ?? const MethodChannel(_channelName),
       _androidResults =
           androidResults ?? const EventChannel('$_channelName/results'),
       _platform = platform ?? (kIsWeb ? null : defaultTargetPlatform);

  static const _channelName = 'com.indifit.indifit/speech_on_device';

  final SpeechToText _speech;
  final MethodChannel _channel;
  final EventChannel _androidResults;
  final TargetPlatform? _platform;
  bool _initialized = false;
  void Function(String error)? _onError;
  StreamSubscription<Object?>? _androidListening;

  bool get _android => _platform == TargetPlatform.android;

  @override
  Future<OnDeviceSpeechSupport> onDeviceSupport(VoiceLocale locale) async {
    if (!(_android || _platform == TargetPlatform.iOS)) {
      return const OnDeviceSpeechSupport.unavailable('unsupported_platform');
    }
    try {
      final reply = await _channel.invokeMapMethod<String, Object?>(
        'onDeviceSupport',
        {'locale': locale.tag},
      );
      // The API gate is checked here too, so the mic never shows below 31
      // whatever the platform side answers.
      if (_android && !androidAllowsOnDeviceSpeech(reply?['sdk'] as int?)) {
        return const OnDeviceSpeechSupport.unavailable('os_too_old');
      }
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
      options: [SpeechToText.androidNoBluetooth],
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
    if (_android) {
      await _androidListening?.cancel();
      _androidListening = _androidResults.receiveBroadcastStream().listen((
        event,
      ) {
        if (event is! Map) return;
        final error = event['error'];
        if (error is String) {
          onError(error);
        } else {
          onWords(event['words'] as String? ?? '', event['final'] == true);
        }
      });
      try {
        await _channel.invokeMethod<void>('listen', {'locale': locale.tag});
      } on PlatformException catch (error) {
        onError(error.code);
      }
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
  Future<void> stop() async {
    if (_android) {
      await _channel.invokeMethod<void>('stop');
      return;
    }
    await _speech.stop();
  }

  @override
  Future<void> cancel() async {
    if (_android) {
      await _channel.invokeMethod<void>('cancel');
      await _androidListening?.cancel();
      _androidListening = null;
      return;
    }
    await _speech.cancel();
  }
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
      "Download English (India) for on-device speech in your phone's settings",
    'unsupported_platform' => 'Voice input needs an Android phone or iPhone',
    _ => "On-device speech isn't available for English (India) here",
  };
}

/// The languages the mic offers. Hindi is held back for now (its
/// transcripts are Devanagari, which most dishes can't match yet); the
/// parser keeps its Devanagari numbers for when it returns.
const List<VoiceLocale> kVoiceLocales = [VoiceLocale.englishIndia];

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
  for (final locale in kVoiceLocales) {
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
