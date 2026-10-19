package com.adventure.onepush

import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.Executor
import java.util.concurrent.Executors

/**
 * Çekirdek durum makinesi; Android'den bağımsız (JVM'de test edilir). `OnePush`
 * nesnesi bunun üstündeki ince kabuktur. Ağ işleri `executor`da koşar
 * (Android ana iş parçacığında ağ yasak); testler doğrudan çalıştıran executor verir.
 */
class OnePushClient(
    val config: OnePushConfig,
    private val transport: OnePushTransport,
    storageDir: File,
    private val device: DeviceInfo,
    val environment: OnePushEnvironment,
    private val bundleId: String,
    private val now: () -> Long = { System.currentTimeMillis() },
    private val executor: Executor = Executors.newSingleThreadExecutor { r -> Thread(r, "onepush").apply { isDaemon = true } },
) {
    data class State(
        var token: String? = null,
        var appInstanceId: String? = null,
        var userId: String? = null,
        var attributes: MutableMap<String, String> = LinkedHashMap(),
        var tags: MutableList<String> = ArrayList(),
        var consent: Boolean = true,
        var permission: String = "unknown",
        var lastOpenedPushId: String? = null,
        var lastOpenedAtMs: Long? = null,
        var registrationPending: Boolean = false,
    )

    private val stateFile = File(storageDir.apply { mkdirs() }, "state.json")
    internal val queue = EventQueue(storageDir)
    internal val inbox = InboxStore(storageDir)
    private val lock = Any()
    private var state: State = loadState()

    /** GA4 köprüsü: açılışta one_push_open{push_id, push_turu, kampanya_id}. Firebase adaptörü bağlar. */
    var analyticsLogger: ((String, Map<String, String>) -> Unit)? = null

    // ---- kimlik ve özellikler
    fun setPushToken(token: String) = mutate { it.token = token }
    fun setAppInstanceId(id: String) = mutate { it.appInstanceId = id }
    fun setUserId(id: String?) = mutate { it.userId = id }
    fun setUserAttribute(key: String, value: String?) = mutate { if (value == null) it.attributes.remove(key) else it.attributes[key] = value }
    fun addTag(tag: String) = mutate { if (!it.tags.contains(tag)) it.tags.add(tag) }
    fun removeTag(tag: String) = mutate { it.tags.remove(tag) }
    fun setPermission(status: String) = mutate { it.permission = status }

    /** KVKK onayı. Kapatılınca kayıt sunucudan SİLİNİR, olay gönderilmez (K7). */
    fun setConsent(granted: Boolean) {
        val token = synchronized(lock) { state.token }
        if (!granted && token != null) {
            synchronized(lock) { state.consent = false; state.registrationPending = false; persistLocked() }
            queue.removeAll()
            executor.execute { transport.send("register", "DELETE", JSONObject().put("token", token), headers()) }
            return
        }
        mutate { it.consent = granted }
    }

    private fun mutate(change: (State) -> Unit) {
        val changed = synchronized(lock) {
            val before = snapshotJson()
            change(state)
            val after = snapshotJson()
            if (before != after) { state.registrationPending = true; persistLocked(); true } else false
        }
        if (changed) flush()
    }

    // ---- push olayları
    /** Bizimse işler ve true döner; değilse DOKUNMAZ ve false döner (misafir modu). */
    fun handle(data: Map<String, String?>?, opened: Boolean): Boolean {
        val p = OnePushPayload.from(data) ?: return false
        if (!synchronized(lock) { state.consent }) return true
        val t = now()
        if (opened) {
            synchronized(lock) { state.lastOpenedPushId = p.pushId; state.lastOpenedAtMs = t; persistLocked() }
            inbox.upsert(p, t, read = true)
            queue.append(PushEvent(EventKind.OPENED, p.pushId, null, null, t, environment))
            val params = LinkedHashMap<String, String>()
            params["push_id"] = p.pushId
            p.pushType?.let { params["push_turu"] = it }
            p.campaignId?.let { params["kampanya_id"] = it }
            analyticsLogger?.invoke("one_push_open", params)
        } else {
            inbox.upsert(p, t, read = false)
            queue.append(PushEvent(EventKind.DELIVERED, p.pushId, null, null, t, environment))
        }
        flush()
        return true
    }

    /** Dönüşüm kancası: son açılıştan attributionWindow içindeyse o push'a bağlanır. */
    fun track(event: String, params: Map<String, String> = emptyMap()) {
        if (!synchronized(lock) { state.consent }) return
        val t = now()
        val pid = synchronized(lock) {
            val at = state.lastOpenedAtMs
            if (at != null && t - at <= config.attributionWindowMs) state.lastOpenedPushId else null
        }
        queue.append(PushEvent(EventKind.TRACK, pid, event, params.ifEmpty { null }, t, environment))
        flush()
    }

    fun inboxItems(limit: Int = 50): List<InboxItem> = inbox.list(limit)
    fun markInboxRead(pushId: String) = inbox.markRead(pushId)

    // ---- gönderim
    /** Kayıt dışındaki her çağrıda cihaz token'ı başlıkta: sunucu olayı aboneliğe böyle bağlar. */
    internal fun headers(): Map<String, String> {
        val h = linkedMapOf("X-One-App-Key" to config.appKey, "X-One-Bundle-Id" to bundleId,
            "X-One-SDK" to "android/$ONE_PUSH_SDK_VERSION")
        synchronized(lock) { state.token }?.let { h["X-One-Device-Token"] = it }
        return h
    }

    internal fun registrationPayload(): RegistrationPayload? = synchronized(lock) {
        val t = state.token ?: return null
        RegistrationPayload(t, state.appInstanceId, state.userId, LinkedHashMap(state.attributes), ArrayList(state.tags),
            device, environment, state.consent, state.permission)
    }

    /** Önce bekleyen kayıt, sonra olay partileri; başarısız parti kuyrukta kalır. */
    fun flush() = executor.execute { flushNow() }

    internal fun flushNow() {
        val pending = synchronized(lock) { state.registrationPending }
        if (pending) {
            val payload = registrationPayload()
            if (payload != null) {
                when (transport.send("register", "POST", payload.toJson(), headers())) {
                    is TransportResult.Success -> synchronized(lock) { state.registrationPending = false; persistLocked() }
                    is TransportResult.Failure -> config.logger?.invoke("One Push: kayıt gönderilemedi, yeniden denenecek")
                }
            }
        }
        while (true) {
            val batch = queue.peek(config.batchSize)
            if (batch.isEmpty()) return
            val body = JSONObject().put("events", JSONArray().apply { batch.forEach { put(it.toJson()) } })
            when (transport.send("event", "POST", body, headers())) {
                is TransportResult.Success -> queue.commit(batch.size)
                is TransportResult.Failure -> { config.logger?.invoke("One Push: ${batch.size} olay gönderilemedi, kuyrukta"); return }
            }
        }
    }

    // ---- durum
    internal val snapshot: State get() = synchronized(lock) { state.copy(attributes = LinkedHashMap(state.attributes), tags = ArrayList(state.tags)) }

    private fun snapshotJson(): String = JSONObject().apply {
        put("token", state.token); put("app_instance_id", state.appInstanceId); put("user_id", state.userId)
        put("attributes", JSONObject(state.attributes as Map<*, *>)); put("tags", JSONArray(state.tags))
        put("consent", state.consent); put("permission", state.permission)
        put("last_opened_push_id", state.lastOpenedPushId); put("last_opened_at", state.lastOpenedAtMs)
        put("registration_pending", state.registrationPending)
    }.toString()

    private fun persistLocked() {
        val tmp = File(stateFile.parentFile, stateFile.name + ".tmp")
        tmp.writeText(snapshotJson()); tmp.renameTo(stateFile)
    }

    private fun loadState(): State = runCatching {
        if (!stateFile.exists()) return State()
        val o = JSONObject(stateFile.readText())
        State(
            token = o.nullStr("token"),
            appInstanceId = o.nullStr("app_instance_id"),
            userId = o.nullStr("user_id"),
            attributes = o.optJSONObject("attributes")?.let { a -> a.keys().asSequence().associateWithTo(LinkedHashMap()) { a.getString(it) } } ?: LinkedHashMap(),
            tags = o.optJSONArray("tags")?.let { a -> MutableList(a.length()) { a.getString(it) } } ?: ArrayList(),
            consent = o.optBoolean("consent", true),
            permission = o.optString("permission", "unknown"),
            lastOpenedPushId = o.nullStr("last_opened_push_id"),
            lastOpenedAtMs = if (o.isNull("last_opened_at")) null else o.getLong("last_opened_at"),
            registrationPending = o.optBoolean("registration_pending", false),
        )
    }.getOrElse { State() }
}
