package com.suwar.suwar

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

object PrayerWidgetScheduler {
    private fun pending(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context, 51001,
        Intent(context, PrayerWidgetProvider::class.java).setAction(PrayerWidgetProvider.refreshAction),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    fun cancel(context: Context) {
        context.getSystemService(AlarmManager::class.java).cancel(pending(context))
    }

    fun schedule(context: Context, nextUtcMs: Long?) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        val intent = pending(context)
        alarms.cancel(intent)
        if (nextUtcMs == null || nextUtcMs <= System.currentTimeMillis()) return
        try {
            if (Build.VERSION.SDK_INT < 31 || alarms.canScheduleExactAlarms()) {
                alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextUtcMs, intent)
            } else {
                alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextUtcMs, intent)
            }
        } catch (_: SecurityException) {
            // Permission can change between capability check and scheduling.
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextUtcMs, intent)
        }
    }
}
