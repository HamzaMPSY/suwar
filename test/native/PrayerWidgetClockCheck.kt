package com.suwar.suwar

import java.time.Instant
import java.util.TimeZone

fun main() {
    val cutoff = Instant.parse("2026-09-20T01:00:00Z").toEpochMilli()
    for (zone in listOf("Africa/Casablanca", "Africa/El_Aaiun")) {
        check(PrayerWidgetClock.timeZone(cutoff - 1, zone).getOffset(cutoff - 1) == 3600000)
        check(PrayerWidgetClock.timeZone(cutoff, zone).getOffset(cutoff) == 0)
        for (date in listOf("2026-10-19T23:30:00Z", "2027-07-01T12:00:00Z", "2030-02-01T12:00:00Z")) {
            val instant = Instant.parse(date).toEpochMilli()
            check(PrayerWidgetClock.timeZone(instant, zone).getOffset(instant) == 0)
        }
        check(PrayerWidgetClock.format(cutoff - 1, zone, "HH:mm:ss") == "01:59:59")
        check(PrayerWidgetClock.format(cutoff, zone, "HH:mm:ss") == "01:00:00")
        val historical = Instant.parse("2026-07-01T12:00:00Z").toEpochMilli()
        check(PrayerWidgetClock.format(historical, zone, "HH:mm") == "13:00")
        val ramadan = Instant.parse("2026-03-01T12:00:00Z").toEpochMilli()
        check(PrayerWidgetClock.format(ramadan, zone, "HH:mm") == "12:00")
    }
    val now = Instant.parse("2026-10-19T23:30:00Z").toEpochMilli()
    check(PrayerWidgetClock.format(now, "Africa/Casablanca", "dd/MM HH:mm") == "19/10 23:30")
    check(PrayerWidgetClock.timeZone(now, "Asia/Tokyo").getOffset(now) == TimeZone.getTimeZone("Asia/Tokyo").getOffset(now))
    println("Native widget clock: transition/history/current/future/Western digits passed")
}
