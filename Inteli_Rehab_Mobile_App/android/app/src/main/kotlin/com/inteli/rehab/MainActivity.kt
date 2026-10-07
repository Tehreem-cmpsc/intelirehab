package com.inteli.rehab

import android.content.Context
import android.os.BatteryManager
import android.speech.tts.TextToSpeech
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/// Tiny device lookups the app needs, done here instead of pulling in
/// plugins (see lib/core/platform/device_services.dart):
///   phoneBattery -> the phone's own battery %, for the low-battery warning
///                   before Start Exercise (separate from the wearable's)
///   filesDir     -> durable app storage for the session journal, which must
///                   survive process death (cache dirs can be cleared)
///   keepScreenOn -> stops the screen dimming/locking mid-set, when the
///                   patient is moving their arm, not touching the phone
///   getReminder / setReminder / cancelReminder / setReminderInterval / markSessionDone
///                -> the daily exercise reminder (see Reminders.kt)
///   speak / stopSpeaking -> spoken cues during a session (rep count, "slow
///                   down", "stop"), through the phone's own text-to-speech
class MainActivity : FlutterActivity() {
    private var tts: TextToSpeech? = null
    private var ttsReady = false

    private fun speech(): TextToSpeech {
        tts?.let { return it }
        val engine = TextToSpeech(applicationContext) { status ->
            if (status == TextToSpeech.SUCCESS) {
                tts?.language = Locale.getDefault()
                ttsReady = true
            }
        }
        tts = engine
        return engine
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "inteli_rehab/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "phoneBattery" -> {
                        val manager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                        val level = manager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                        result.success(if (level in 0..100) level else null)
                    }
                    "filesDir" -> result.success(filesDir.absolutePath)
                    "keepScreenOn" -> {
                        val on = call.arguments as? Boolean ?: false
                        runOnUiThread {
                            if (on) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    }
                    "speak" -> {
                        val text = call.arguments as? String
                        val engine = speech()
                        // Until the engine has finished starting there is nothing to say it with; a
                        // cue that arrives that early is simply dropped.
                        if (text != null && ttsReady) engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "cue")
                        result.success(null)
                    }
                    "stopSpeaking" -> {
                        tts?.stop()
                        result.success(null)
                    }
                    "getReminder" -> result.success(Reminders.read(applicationContext))
                    "setReminder" -> {
                        val args = call.arguments as? Map<*, *>
                        Reminders.set(
                            applicationContext,
                            (args?.get("hour") as? Int) ?: 18,
                            (args?.get("minute") as? Int) ?: 0,
                            (args?.get("intervalDays") as? Int) ?: 1,
                        )
                        result.success(null)
                    }
                    "cancelReminder" -> {
                        Reminders.cancel(applicationContext)
                        result.success(null)
                    }
                    "setReminderInterval" -> {
                        Reminders.setIntervalDays(applicationContext, (call.arguments as? Int) ?: 1)
                        result.success(null)
                    }
                    "markSessionDone" -> {
                        Reminders.markSessionDone(applicationContext)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        tts = null
        super.onDestroy()
    }
}
