package com.suwar.suwar

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class PrayerWidgetChannel(
    private val activity: MainActivity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, "suwar/prayer_widget")
    private var pendingLaunch = false

    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "publishSnapshot" -> {
                        val data = call.arguments as? Map<*, *>
                            ?: throw IllegalArgumentException("Missing widget snapshot")
                        PrayerWidgetStore.save(activity, JSONObject(data))
                        PrayerWidgetRenderer.updateAll(activity)
                        result.success(null)
                    }
                    "requestPin" -> {
                        val manager = AppWidgetManager.getInstance(activity)
                        val started = Build.VERSION.SDK_INT >= 26 &&
                            manager.isRequestPinAppWidgetSupported &&
                            manager.requestPinAppWidget(
                                ComponentName(activity, PrayerWidgetProvider::class.java), null, null)
                        result.success(started)
                    }
                    "consumePrayerLaunch" -> {
                        val pending = pendingLaunch
                        pendingLaunch = false
                        result.success(pending)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("prayer_widget_error", error.message, null)
            }
        }
    }

    fun handleIntent(intent: Intent?) {
        if (intent?.action != PrayerWidgetProvider.openPrayerAction) return
        pendingLaunch = true
        // Keep the flag until Dart acknowledges it; callbacks before bootstrap may be missed.
        intent.action = Intent.ACTION_MAIN
        channel.invokeMethod("openPrayer", null)
    }
}
