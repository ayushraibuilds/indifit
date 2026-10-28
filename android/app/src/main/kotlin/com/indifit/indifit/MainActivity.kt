package com.indifit.indifit

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var recognizer: SpeechRecognizer? = null
    private var speechEvents: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        EventChannel(messenger, "$SPEECH_CHANNEL/results").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    speechEvents = events
                }

                override fun onCancel(arguments: Any?) {
                    speechEvents = null
                }
            },
        )
        MethodChannel(messenger, SPEECH_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "onDeviceSupport" ->
                    onDeviceSupport(call.argument<String>("locale") ?: "") { result.success(it) }
                "listen" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                        !SpeechRecognizer.isOnDeviceRecognitionAvailable(this)
                    ) {
                        result.error("on_device_unavailable", "No on-device recognizer", null)
                    } else {
                        listenOnDevice(call.argument<String>("locale") ?: "en-IN")
                        result.success(null)
                    }
                }
                "stop" -> {
                    recognizer?.stopListening()
                    result.success(null)
                }
                "cancel" -> {
                    releaseRecognizer()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        releaseRecognizer()
        super.onDestroy()
    }

    private fun releaseRecognizer() {
        recognizer?.cancel()
        recognizer?.destroy()
        recognizer = null
    }

    // Voice logging (TF-2 B, D2): only ever the on-device recognizer. There
    // is no SpeechRecognizer.createSpeechRecognizer in this app, so speech
    // never reaches the network recognizer; below API 31 the mic is hidden.
    @RequiresApi(Build.VERSION_CODES.S)
    private fun listenOnDevice(locale: String) {
        releaseRecognizer()
        val onDevice = SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
        recognizer = onDevice
        onDevice.setRecognitionListener(
            object : RecognitionListener {
                override fun onPartialResults(partialResults: Bundle?) = send(partialResults, false)

                override fun onResults(results: Bundle?) = send(results, true)

                override fun onError(error: Int) {
                    speechEvents?.success(mapOf("error" to errorName(error)))
                }

                override fun onReadyForSpeech(params: Bundle?) {}

                override fun onBeginningOfSpeech() {}

                override fun onRmsChanged(rmsdB: Float) {}

                override fun onBufferReceived(buffer: ByteArray?) {}

                override fun onEndOfSpeech() {}

                override fun onEvent(eventType: Int, params: Bundle?) {}
            },
        )
        onDevice.startListening(
            Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
                .putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true),
        )
    }

    private fun send(bundle: Bundle?, isFinal: Boolean) {
        val words = bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull() ?: ""
        speechEvents?.success(mapOf("words" to words, "final" to isFinal))
    }

    private fun errorName(error: Int): String = when (error) {
        SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED,
        SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "language_unavailable"
        SpeechRecognizer.ERROR_NO_MATCH,
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "no_match"
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "permission_denied"
        else -> "error_$error"
    }

    // Whether the on-device recognizer (API 31+) has this language. The
    // reply always carries the API level; the app hides the mic below 31.
    private fun onDeviceSupport(locale: String, reply: (Map<String, Any>) -> Unit) {
        val sdk = Build.VERSION.SDK_INT
        if (sdk < Build.VERSION_CODES.S) {
            reply(mapOf("available" to false, "reason" to "os_too_old", "sdk" to sdk))
            return
        }
        if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(this)) {
            reply(mapOf("available" to false, "reason" to "no_on_device_recognizer", "sdk" to sdk))
            return
        }
        // Android 12 can't list the on-device languages; a missing one fails
        // when listening starts, on the device, and the app hides the mic.
        if (sdk < Build.VERSION_CODES.TIRAMISU) {
            reply(mapOf("available" to true, "sdk" to sdk))
            return
        }
        val tag = locale.replace('_', '-').lowercase()
        val checker = SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
        checker.checkRecognitionSupport(
            Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH),
            ContextCompat.getMainExecutor(this),
            object : RecognitionSupportCallback {
                override fun onSupportResult(support: RecognitionSupport) {
                    checker.destroy()
                    fun has(languages: List<String>) =
                        languages.any { it.replace('_', '-').lowercase() == tag }
                    reply(
                        when {
                            has(support.installedOnDeviceLanguages) ->
                                mapOf("available" to true, "sdk" to sdk)
                            has(support.supportedOnDeviceLanguages) ->
                                mapOf("available" to false, "reason" to "language_not_downloaded", "sdk" to sdk)
                            else ->
                                mapOf("available" to false, "reason" to "language_not_supported", "sdk" to sdk)
                        },
                    )
                }

                override fun onError(error: Int) {
                    checker.destroy()
                    reply(mapOf("available" to false, "reason" to "check_failed", "sdk" to sdk))
                }
            },
        )
    }

    private companion object {
        const val SPEECH_CHANNEL = "com.indifit.indifit/speech_on_device"
    }
}
