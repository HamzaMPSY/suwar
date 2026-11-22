package com.suwar.suwar

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate

data class RemembranceVerse(val id: String, val surahId: Int, val ayah: Int,
    val topic: String, val surahName: String, val compact: Boolean, val source: String) {
    val lexical: String get() {
        val marker = Regex("\\s+([٠-٩۰-۹0-9]+)$").find(source) ?: return source
        val number = marker.groupValues[1].map { c ->
            when (c) { in '٠'..'٩' -> '0' + (c - '٠'); in '۰'..'۹' -> '0' + (c - '۰'); else -> c }
        }.joinToString("").toIntOrNull()
        return if (number == ayah) source.substring(0, marker.range.first) else source
    }
    val reference: String get() = "$surahName · $ayah · ورش"
}

object AyahWidgetStore {
    private var cached: List<RemembranceVerse>? = null
    val topics = mapOf("all" to "كل المعاني", "comfort" to "طمأنينة", "jannah" to "الجنة", "power" to "قدرة الله")
    private fun preferences(context: Context) = context.getSharedPreferences("suwar_ayah_widget", Context.MODE_PRIVATE)
    fun catalog(context: Context): List<RemembranceVerse> {
        cached?.let { return it }
        fun asset(name: String) = context.assets.open("flutter_assets/assets/quran/$name").bufferedReader().use { it.readText() }
        val rows = JSONArray(asset("warsh-data.json"))
        val source = mutableMapOf<String, String>()
        for (i in 0 until rows.length()) {
            val r = rows.getJSONObject(i)
            source["${r.getInt("sura_no")}:${r.getInt("aya_no")}"] = r.getString("aya_text")
        }
        val catalog = JSONObject(asset("remembrance-catalog.json"))
        require(catalog.getString("source") == "kfgqpc-warsh-v10-6214")
        val entries = catalog.getJSONArray("entries")
        val result = (0 until entries.length()).map { i ->
            val e = entries.getJSONObject(i)
            val id = e.getString("id")
            RemembranceVerse(id, e.getInt("surahId"), e.getInt("ayahNumber"),
                e.getString("topic"), e.getString("surahName"), e.getBoolean("compact"), requireNotNull(source[id]))
        }
        cached = result
        return result
    }
    fun state(context: Context): Map<String, Any> {
        val p = preferences(context)
        val topic = p.getString("topic", "all").takeIf { topics.containsKey(it) } ?: "all"
        return mapOf("topic" to topic, "offset" to p.getInt("offset", 0))
    }
    fun setTopic(context: Context, topic: String) {
        require(topics.containsKey(topic))
        check(preferences(context).edit().putString("topic", topic).putInt("offset", 0).commit())
    }
    fun next(context: Context) {
        val p = preferences(context)
        check(p.edit().putInt("offset", (p.getInt("offset", 0) + 1) % 1000000).commit())
    }
    fun selected(context: Context, compact: Boolean): RemembranceVerse {
        val state = state(context)
        val entries = catalog(context).filter { (state["topic"] == "all" || it.topic == state["topic"]) && (!compact || it.compact) }
        val index = Math.floorMod(LocalDate.now().toEpochDay() + (state["offset"] as Int), entries.size.toLong()).toInt()
        return entries[index]
    }
}
