package com.adventure.onepush

import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

enum class EventKind(val wire: String) { DELIVERED("delivered"), OPENED("opened"), DISMISSED("dismissed"), TRACK("track") }

/** Sunucuya giden olay (docs/ONE_PUSH_PLANI.md bölüm 6). */
data class PushEvent(
    val kind: EventKind,
    val pushId: String?,
    val eventName: String?,
    val params: Map<String, String>?,
    val tsMs: Long,
    val environment: OnePushEnvironment,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("type", kind.wire)
        put("ts", iso8601(tsMs))
        put("environment", environment.wire)
        pushId?.let { put("push_id", it) }
        eventName?.let { put("event_name", it) }
        params?.let { put("params", JSONObject(it)) }
    }

    companion object {
        fun fromJson(o: JSONObject): PushEvent = PushEvent(
            kind = EventKind.values().first { it.wire == o.getString("type") },
            pushId = o.optString("push_id").takeIf { o.has("push_id") },
            eventName = o.optString("event_name").takeIf { o.has("event_name") },
            params = o.optJSONObject("params")?.let { p -> p.keys().asSequence().associateWith { p.getString(it) } },
            tsMs = parseIso8601(o.getString("ts")),
            environment = OnePushEnvironment.values().first { it.wire == o.getString("environment") },
        )

        private fun fmt() = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }
        fun iso8601(ms: Long): String = fmt().format(Date(ms))
        fun parseIso8601(s: String): Long = fmt().parse(s)?.time ?: 0L
    }
}

/**
 * Dosya destekli olay kuyruğu. Çevrimdışı birikir, parti parti boşalır; gönderim
 * düşerse olaylar kuyrukta KALIR (sessiz kayıp yok).
 */
class EventQueue(directory: File) {
    private val file = File(directory.apply { mkdirs() }, "events.json")
    private val lock = Any()
    private val items = ArrayList<PushEvent>()

    init {
        runCatching {
            if (file.exists()) {
                val arr = JSONArray(file.readText())
                for (i in 0 until arr.length()) items.add(PushEvent.fromJson(arr.getJSONObject(i)))
            }
        }
    }

    val count: Int get() = synchronized(lock) { items.size }

    fun append(e: PushEvent) = synchronized(lock) { items.add(e); persistLocked() }

    /** İlk n olay; `commit` çağrılmadıkça kuyruktan düşmez. */
    fun peek(n: Int): List<PushEvent> = synchronized(lock) { items.take(n) }

    fun commit(n: Int) = synchronized(lock) { repeat(minOf(n, items.size)) { items.removeAt(0) }; persistLocked() }

    fun removeAll() = synchronized(lock) { items.clear(); persistLocked() }

    private fun persistLocked() {
        val arr = JSONArray(); items.forEach { arr.put(it.toJson()) }
        val tmp = File(file.parentFile, file.name + ".tmp")
        tmp.writeText(arr.toString()); tmp.renameTo(file)
    }
}

/** `optString(key, null)` Kotlin'de `Nothing?` uyarısı verir; null/eksik alan için tek yardımcı. */
internal fun JSONObject.nullStr(key: String): String? = if (has(key) && !isNull(key)) getString(key) else null
