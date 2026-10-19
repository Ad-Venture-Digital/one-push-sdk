package com.adventure.onepush

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File
import java.util.concurrent.Executor

/** Sahte taşıma: çağrıları kaydeder (path, method, body, headers — gerçeğin yüzeyi). */
class FakeTransport : OnePushTransport {
    data class Call(val path: String, val method: String, val body: JSONObject, val headers: Map<String, String>)
    val calls = ArrayList<Call>()
    var failNext = 0
    override fun send(path: String, method: String, body: JSONObject, headers: Map<String, String>): TransportResult {
        calls.add(Call(path, method, body, headers))
        if (failNext > 0) { failNext--; return TransportResult.Failure(503, "HTTP 503") }
        return TransportResult.Success(JSONObject().put("ok", true))
    }
    fun paths() = calls.map { "${it.method} ${it.path}" }
    fun lastEvents(): List<JSONObject> {
        val arr = calls.last().body.getJSONArray("events")
        return List(arr.length()) { arr.getJSONObject(it) }
    }
}

class OnePushClientTest {
    private lateinit var dir: File
    private lateinit var transport: FakeTransport
    private var clock = 1_800_000_000_000L
    private val direct = Executor { it.run() }

    @Before fun setUp() {
        dir = File(System.getProperty("java.io.tmpdir"), "onepush-test-" + System.nanoTime()).apply { mkdirs() }
        transport = FakeTransport()
    }

    private fun client(env: OnePushEnvironment = OnePushEnvironment.TEST): OnePushClient = OnePushClient(
        config = OnePushConfig(appKey = "app_abc", environment = env, attributionWindowMs = 3_600_000),
        transport = transport, storageDir = dir,
        device = DeviceInfo("1.2 (34)", "14", "Samsung SM-S911B", "tr_TR", "Europe/Istanbul"),
        environment = env, bundleId = "com.lumvio.app", now = { clock }, executor = direct,
    )

    @Test fun payload_isareti_ve_oteki_saglayici() {
        val p = OnePushPayload.from(mapOf("one_push_id" to "p1", "one_push_turu" to "promosyon", "one_baslik" to "B"))!!
        assertEquals("p1", p.pushId); assertEquals("promosyon", p.pushType); assertEquals("B", p.title)
        assertFalse(OnePushPayload.isOnePush(mapOf("custom" to "{\"i\":\"onesignal\"}")))
        assertNull(OnePushPayload.from(mapOf("one_push_id" to " ")))
        assertNull(OnePushPayload.from(null))
    }

    @Test fun ortam_tespiti() {
        assertEquals(OnePushEnvironment.DEBUG, EnvironmentDetector.detect(true, EnvironmentDetector.PLAY_STORE))
        assertEquals(OnePushEnvironment.TEST, EnvironmentDetector.detect(false, null))
        assertEquals(OnePushEnvironment.TEST, EnvironmentDetector.detect(false, "com.google.android.apps.nbu.files"))
        assertEquals(OnePushEnvironment.PRODUCTION, EnvironmentDetector.detect(false, EnvironmentDetector.PLAY_STORE))
        assertEquals("production", OnePushEnvironment.PRODUCTION.wire)
    }

    @Test fun kuyruk_diske_yazar_yeniden_okur() {
        val q = EventQueue(dir)
        q.append(PushEvent(EventKind.DELIVERED, "a", null, null, clock, OnePushEnvironment.PRODUCTION))
        q.append(PushEvent(EventKind.TRACK, null, "purchase", mapOf("v" to "9"), clock, OnePushEnvironment.PRODUCTION))
        val q2 = EventQueue(dir)
        assertEquals(2, q2.count); assertEquals("a", q2.peek(1)[0].pushId)
        assertEquals(mapOf("v" to "9"), q2.peek(2)[1].params)
        q2.commit(1); assertEquals(1, EventQueue(dir).count)
    }

    @Test fun token_gelmeden_kayit_gitmez_gelince_basliklarla_gider() {
        val c = client(); c.setUserId("u1")
        assertTrue(transport.calls.isEmpty())
        c.setPushToken("tok1")
        assertEquals(listOf("POST register"), transport.paths())
        val call = transport.calls[0]
        assertEquals("app_abc", call.headers["X-One-App-Key"]); assertEquals("com.lumvio.app", call.headers["X-One-Bundle-Id"])
        assertEquals("tok1", call.body.getString("token")); assertEquals("u1", call.body.getString("user_id"))
        assertEquals("test", call.body.getString("environment")); assertEquals("android", call.body.getString("platform"))
        assertTrue(call.body.getBoolean("consent")); assertFalse(c.snapshot.registrationPending)
    }

    @Test fun ozellik_ve_etiket_degisince_yeniden_kayit_ayni_deger_gondermez() {
        val c = client(); c.setPushToken("tok1")
        c.setUserAttribute("plan", "pro"); c.addTag("vip"); c.addTag("vip")
        assertEquals(3, transport.paths().count { it == "POST register" })
        assertEquals("pro", transport.calls.last().body.getJSONObject("attributes").getString("plan"))
        assertEquals("vip", transport.calls.last().body.getJSONArray("tags").getString(0))
        c.removeTag("vip"); c.setUserAttribute("plan", null)
        assertEquals(0, transport.calls.last().body.getJSONArray("tags").length())
        assertEquals(0, transport.calls.last().body.getJSONObject("attributes").length())
    }

    @Test fun kayit_dusunce_bekler_sonraki_flush_yeniden_dener() {
        transport.failNext = 1
        val c = client(); c.setPushToken("tok1")
        assertTrue(c.snapshot.registrationPending)
        c.flush()
        assertFalse(c.snapshot.registrationPending)
        assertEquals(listOf("POST register", "POST register"), transport.paths())
    }

    @Test fun bizim_olmayan_payload_dokunulmaz() {
        val c = client(); c.setPushToken("t"); val n = transport.calls.size
        assertFalse(c.handle(mapOf("custom" to "x"), opened = false))
        assertEquals(n, transport.calls.size); assertTrue(c.inboxItems().isEmpty())
    }

    @Test fun alindi_olayi_kutuya_ve_sunucuya() {
        val c = client(); c.setPushToken("t")
        assertTrue(c.handle(mapOf("one_push_id" to "p9", "one_baslik" to "Kampanya"), opened = false))
        assertEquals("POST event", transport.paths().last())
        assertEquals("t", transport.calls.last().headers["X-One-Device-Token"])
        val e = transport.lastEvents()
        assertEquals(1, e.size); assertEquals("delivered", e[0].getString("type")); assertEquals("p9", e[0].getString("push_id"))
        assertEquals("test", e[0].getString("environment"))
        assertEquals("Kampanya", c.inboxItems()[0].title); assertFalse(c.inboxItems()[0].read)
        assertEquals(0, c.queue.count)
    }

    @Test fun acilis_GA4_koprusu_ve_kutu_okundu() {
        val c = client(); c.setPushToken("t")
        var logged: Pair<String, Map<String, String>>? = null
        c.analyticsLogger = { n, p -> logged = n to p }
        val d = mapOf("one_push_id" to "p1", "one_push_turu" to "geri_kazanim", "one_kampanya_id" to "k7")
        c.handle(d, opened = false); c.handle(d, opened = true)
        assertEquals("one_push_open", logged!!.first)
        assertEquals(mapOf("push_id" to "p1", "push_turu" to "geri_kazanim", "kampanya_id" to "k7"), logged!!.second)
        assertEquals(1, c.inboxItems().size); assertTrue(c.inboxItems()[0].read)
    }

    @Test fun track_pencere_icinde_baglanir_disinda_baglanmaz() {
        val c = client(); c.setPushToken("t")
        c.handle(mapOf("one_push_id" to "p1"), opened = true)
        c.track("purchase", mapOf("value" to "199"))
        var e = transport.lastEvents()[0]
        assertEquals("track", e.getString("type")); assertEquals("p1", e.getString("push_id"))
        assertEquals("199", e.getJSONObject("params").getString("value"))
        clock += 3_600_001
        c.track("purchase")
        e = transport.lastEvents()[0]
        assertFalse(e.has("push_id"))
    }

    @Test fun onay_kapaninca_kayit_silinir_olay_gitmez() {
        val c = client(); c.setPushToken("t")
        c.setConsent(false)
        assertEquals("DELETE register", transport.paths().last()); assertEquals("t", transport.calls.last().body.getString("token"))
        val n = transport.calls.size
        assertTrue(c.handle(mapOf("one_push_id" to "p1"), opened = true)); c.track("purchase")
        assertEquals(n, transport.calls.size); assertEquals(0, c.queue.count)
        c.setConsent(true)
        assertEquals("POST register", transport.paths().last()); assertTrue(transport.calls.last().body.getBoolean("consent"))
    }

    @Test fun gonderim_dusunce_olaylar_kuyrukta_kalir_sonra_bosalir() {
        val c = client(); c.setPushToken("t")
        transport.failNext = 1
        c.handle(mapOf("one_push_id" to "p1"), opened = false)
        assertEquals(1, c.queue.count)
        c.handle(mapOf("one_push_id" to "p2"), opened = false)
        assertEquals(0, c.queue.count)
        assertEquals(listOf("p1", "p2"), transport.lastEvents().map { it.getString("push_id") })
    }

    @Test fun durum_diske_yazilir_yeniden_acilinca_durur() {
        val c = client(); c.setPushToken("t"); c.setUserId("u")
        val c2 = client()
        assertEquals("t", c2.snapshot.token); assertEquals("u", c2.snapshot.userId)
    }
}
