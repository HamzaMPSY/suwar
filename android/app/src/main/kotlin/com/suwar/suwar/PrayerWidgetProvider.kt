package com.suwar.suwar

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle

class PrayerWidgetProvider : AppWidgetProvider() {
    companion object {
        const val openPrayerAction = "com.suwar.suwar.widget.OPEN_PRAYER"
        const val refreshAction = "com.suwar.suwar.widget.REFRESH"
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        PrayerWidgetRenderer.updateAll(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context, manager: AppWidgetManager, id: Int, options: Bundle,
    ) {
        PrayerWidgetRenderer.updateAll(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action in setOf(refreshAction, Intent.ACTION_BOOT_COMPLETED,
                Intent.ACTION_MY_PACKAGE_REPLACED, Intent.ACTION_TIME_CHANGED,
                Intent.ACTION_TIMEZONE_CHANGED)) {
            PrayerWidgetRenderer.updateAll(context)
        }
    }

    override fun onDisabled(context: Context) {
        PrayerWidgetScheduler.cancel(context)
    }
}
