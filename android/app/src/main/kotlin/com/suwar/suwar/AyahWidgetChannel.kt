package com.suwar.suwar

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class AyahWidgetChannel(private val activity: MainActivity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "suwar/ayah_widget")
    private var pending: String? = null
    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getState" -> result.success(AyahWidgetStore.state(activity))
                    "setTopic" -> {
                        AyahWidgetStore.setTopic(activity, call.arguments as String)
                        AyahWidgetRenderer.updateAll(activity)
                        result.success(AyahWidgetStore.state(activity))
                    }
                    "next" -> {
                        AyahWidgetStore.next(activity)
                        AyahWidgetRenderer.updateAll(activity)
                        result.success(AyahWidgetStore.state(activity))
                    }
                    "requestPin" -> {
                        val manager = AppWidgetManager.getInstance(activity)
                        result.success(Build.VERSION.SDK_INT >= 26 && manager.isRequestPinAppWidgetSupported &&
                            manager.requestPinAppWidget(ComponentName(activity, AyahWidgetProvider::class.java), null, null))
                    }
                    "consumeAyahLaunch" -> { val value = pending; pending = null; result.success(value) }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) { result.error("ayah_widget_error", error.message, null) }
        }
    }
    fun handleIntent(intent: Intent?) {
        if (intent?.action != AyahWidgetProvider.openAction) return
        val id = intent.getStringExtra("ayahId")
        if (AyahWidgetStore.catalog(activity).none { it.id == id }) return
        pending = id
        intent.action = Intent.ACTION_MAIN
        channel.invokeMethod("openAyah", null)
    }
}
