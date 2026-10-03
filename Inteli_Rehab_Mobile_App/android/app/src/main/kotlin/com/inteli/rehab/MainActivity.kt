package com.inteli.rehab

import android.content.Context
import android.os.BatteryManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Two tiny device lookups the app needs, done here instead of pulling in
/// plugins (see lib/core/platform/device_services.dart):
///   phoneBattery -> the phone's own battery %, for the low-battery warning
///                   before Start Exercise (separate from the wearable's)
///   filesDir     -> durable app storage for the session journal, which must
///                   survive process death (cache dirs can be cleared)
class MainActivity : FlutterActivity() {
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
                    else -> result.notImplemented()
                }
            }
    }
}
