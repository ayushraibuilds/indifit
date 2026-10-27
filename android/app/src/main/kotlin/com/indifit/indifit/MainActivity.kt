package com.indifit.indifit

import android.content.Intent
import android.os.Build
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.indifit.indifit/speech_on_device",
        ).setMethodCallHandler { call, result ->
            if (call.method != "onDeviceSupport") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            onDeviceSupport(call.argument<String>("locale") ?: "") { result.success(it) }
        }
    }

    // Voice logging (TF-2 B) listens only when the on-device recognizer
    // (API 31+) has this language: speech_to_text falls back to the network
    // recognizer when the on-device one is missing, so the app asks first.
    private fun onDeviceSupport(locale: String, reply: (Map<String, Any>) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            reply(mapOf("available" to false, "reason" to "os_too_old"))
            return
        }
        if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(this)) {
            reply(mapOf("available" to false, "reason" to "no_on_device_recognizer"))
            return
        }
        // Android 12 can't list the on-device languages; a missing one fails
        // when listening starts, on the device, and the app hides the mic.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            reply(mapOf("available" to true))
            return
        }
        val tag = locale.replace('_', '-').lowercase()
        val recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
        recognizer.checkRecognitionSupport(
            Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH),
            ContextCompat.getMainExecutor(this),
            object : RecognitionSupportCallback {
                override fun onSupportResult(support: RecognitionSupport) {
                    recognizer.destroy()
                    fun has(languages: List<String>) =
                        languages.any { it.replace('_', '-').lowercase() == tag }
                    reply(
                        when {
                            has(support.installedOnDeviceLanguages) ->
                                mapOf("available" to true)
                            has(support.supportedOnDeviceLanguages) ->
                                mapOf("available" to false, "reason" to "language_not_downloaded")
                            else ->
                                mapOf("available" to false, "reason" to "language_not_supported")
                        },
                    )
                }

                override fun onError(error: Int) {
                    recognizer.destroy()
                    reply(mapOf("available" to false, "reason" to "check_failed"))
                }
            },
        )
    }
}
