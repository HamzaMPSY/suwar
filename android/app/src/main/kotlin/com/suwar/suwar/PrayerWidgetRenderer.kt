package com.suwar.suwar

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

object PrayerWidgetRenderer {
    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, PrayerWidgetProvider::class.java))
        if (ids.isEmpty()) {
            PrayerWidgetScheduler.cancel(context)
            return
        }
        val snapshot = PrayerWidgetStore.load(context)
        val now = System.currentTimeMillis()
        val valid = snapshot != null && now >= snapshot.generatedUtcMs - 300000 &&
            now < snapshot.validUntilUtcMs
        val next = if (valid) snapshot?.prayers?.firstOrNull { it.timeUtcMs > now } else null
        val views = RemoteViews(context.packageName, R.layout.prayer_widget)
        views.setTextViewText(R.id.prayer_widget_city,
            snapshot?.let { "${it.city} · الصلاة القادمة" } ?: "سُوَر · الصلاة القادمة")
        views.setTextViewText(R.id.prayer_widget_time,
            if (next != null && snapshot != null) {
                "${next.label} · ${format(next.timeUtcMs, snapshot.timeZone, "HH:mm") }"
            } else "افتح سُوَر لتحديث المواقيت")
        val updated = snapshot?.let {
            "البيانات: ${format(it.generatedUtcMs, it.timeZone, "dd/MM HH:mm") }"
        } ?: "لم تُحفظ مواقيت بعد"
        views.setTextViewText(R.id.prayer_widget_updated,
            "$updated\nقد يتأخر التحديث؛ اضغط لفتح المواقيت")
        views.setOnClickPendingIntent(R.id.prayer_widget_root, openPrayer(context))
        views.setOnClickPendingIntent(R.id.prayer_widget_refresh, refresh(context))
        for (id in ids) manager.updateAppWidget(id, views)
        PrayerWidgetScheduler.schedule(context, next?.timeUtcMs)
    }

    private fun format(instant: Long, zone: String, pattern: String): String =
        PrayerWidgetClock.format(instant, zone, pattern)

    private fun openPrayer(context: Context): PendingIntent = PendingIntent.getActivity(
        context, 51002,
        Intent(context, MainActivity::class.java)
            .setAction(PrayerWidgetProvider.openPrayerAction)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun refresh(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context, 51003,
        Intent(context, PrayerWidgetProvider::class.java)
            .setAction(PrayerWidgetProvider.refreshAction)
            .addFlags(Intent.FLAG_RECEIVER_FOREGROUND),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}
