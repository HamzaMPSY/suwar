package com.suwar.suwar

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle

class AyahWidgetProvider : AppWidgetProvider() {
    companion object {
        const val openAction = "com.suwar.suwar.widget.OPEN_AYAH"
        const val nextAction = "com.suwar.suwar.widget.NEXT_AYAH"
    }
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) = AyahWidgetRenderer.updateAll(context)
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) = AyahWidgetRenderer.updateAll(context)
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == nextAction) {
            AyahWidgetStore.next(context)
            AyahWidgetRenderer.updateAll(context)
        } else if (intent.action in setOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_DATE_CHANGED, Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED)) {
            AyahWidgetRenderer.updateAll(context)
        }
    }
}
