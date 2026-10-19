package com.suwar.suwar

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** IANA 2026e Morocco correction, including snapshots saved by older app builds. */
object PrayerWidgetClock {
    // 2026-09-20 02:00 local +01 becomes 01:00 UTC/local +00.
    private const val moroccoTransitionMs = 1789866000000L

    fun timeZone(instant: Long, name: String): TimeZone =
        if (name in setOf("Africa/Casablanca", "Africa/El_Aaiun") &&
            instant >= moroccoTransitionMs) {
            TimeZone.getTimeZone("UTC")
        } else TimeZone.getTimeZone(name)

    fun format(instant: Long, zone: String, pattern: String): String {
        // Arabic labels stay Arabic; numeric clock/date output is Western.
        val formatter = SimpleDateFormat(pattern, Locale.US)
        formatter.timeZone = timeZone(instant, zone)
        return formatter.format(Date(instant))
    }
}
