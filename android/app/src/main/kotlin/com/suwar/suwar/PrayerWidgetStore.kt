package com.suwar.suwar

import android.content.Context
import org.json.JSONObject
import java.util.TimeZone

data class PrayerWidgetPrayer(val kind: String, val label: String, val timeUtcMs: Long)
data class PrayerWidgetSnapshot(
    val city: String,
    val timeZone: String,
    val generatedUtcMs: Long,
    val validUntilUtcMs: Long,
    val prayers: List<PrayerWidgetPrayer>,
)

object PrayerWidgetStore {
    private const val preferences = "suwar.prayer_widget.v1"
    private const val snapshotKey = "snapshot"
    private val kinds = setOf("fajr", "dhuhr", "asr", "maghrib", "isha")

    fun save(context: Context, raw: JSONObject) {
        val text = raw.toString()
        require(text.length <= 65536) { "Widget snapshot too large" }
        parse(raw)
        check(context.getSharedPreferences(preferences, Context.MODE_PRIVATE)
            .edit().putString(snapshotKey, text).commit()) { "Widget snapshot not saved" }
    }

    fun load(context: Context): PrayerWidgetSnapshot? = try {
        context.getSharedPreferences(preferences, Context.MODE_PRIVATE)
            .getString(snapshotKey, null)?.let { parse(JSONObject(it)) }
    } catch (_: Exception) { null }

    private fun parse(raw: JSONObject): PrayerWidgetSnapshot {
        require(raw.getInt("version") == 1)
        val city = raw.getString("city")
        val zone = raw.getString("timeZone")
        require(city.isNotBlank() && city.length <= 80)
        require(TimeZone.getAvailableIDs().contains(zone))
        require(raw.getString("settingsFingerprint").length in 1..2048)
        val generated = raw.getLong("generatedUtcMs")
        val until = raw.getLong("validUntilUtcMs")
        require(generated > 0 && until > generated)
        require(until - generated <= 32L * 24 * 60 * 60 * 1000)
        val rows = raw.getJSONArray("prayers")
        require(rows.length() in 5..150)
        var previous = 0L
        val prayers = (0 until rows.length()).map { index ->
            val row = rows.getJSONObject(index)
            val kind = row.getString("kind")
            val label = row.getString("label")
            val instant = row.getLong("timeUtcMs")
            require(kind in kinds && label.isNotBlank() && label.length <= 32)
            require(instant > previous && instant <= until)
            require(instant >= generated - 25L * 60 * 60 * 1000)
            previous = instant
            PrayerWidgetPrayer(kind, label, instant)
        }
        require(prayers.last().timeUtcMs == until)
        return PrayerWidgetSnapshot(city, zone, generated, until, prayers)
    }
}
