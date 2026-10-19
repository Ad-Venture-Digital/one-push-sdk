package com.adventure.onepush

import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/** Bildirim kutusu kaydı (K16); ilk sürümde yerel. */
data class InboxItem(
    val pushId: String, val title: String?, val body: String?, val deepLink: String?,
    val receivedAtMs: Long, val read: Boolean,
)

class InboxStore(directory: File) {
    companion object { const val CAPACITY = 200 }
    private val file = File(directory.apply { mkdirs() }, "inbox.json")
    private val lock = Any()
    private val items = ArrayList<InboxItem>()

    init {
        runCatching {
            if (file.exists()) {
                val arr = JSONArray(file.readText())
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    items.add(InboxItem(o.getString("push_id"), o.nullStr("title"), o.nullStr("body"),
                        o.nullStr("deep_link"), o.getLong("received_at"), o.getBoolean("read")))
                }
            }
        }
    }

    fun upsert(p: OnePushPayload, atMs: Long, read: Boolean) = synchronized(lock) {
        val i = items.indexOfFirst { it.pushId == p.pushId }
        if (i >= 0) { if (read) items[i] = items[i].copy(read = true) }
        else {
            items.add(0, InboxItem(p.pushId, p.title, p.body, p.deepLink, atMs, read))
            while (items.size > CAPACITY) items.removeAt(items.size - 1)
        }
        persistLocked()
    }

    fun markRead(pushId: String) = synchronized(lock) {
        val i = items.indexOfFirst { it.pushId == pushId }
        if (i >= 0) { items[i] = items[i].copy(read = true); persistLocked() }
    }

    fun list(limit: Int = 50): List<InboxItem> = synchronized(lock) { items.take(limit) }
    fun removeAll() = synchronized(lock) { items.clear(); persistLocked() }

    private fun persistLocked() {
        val arr = JSONArray()
        items.forEach {
            arr.put(JSONObject().apply {
                put("push_id", it.pushId); put("title", it.title); put("body", it.body)
                put("deep_link", it.deepLink); put("received_at", it.receivedAtMs); put("read", it.read)
            })
        }
        val tmp = File(file.parentFile, file.name + ".tmp"); tmp.writeText(arr.toString()); tmp.renameTo(file)
    }
}
