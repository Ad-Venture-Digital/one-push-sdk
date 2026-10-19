package com.adventure.onepush

import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

sealed class TransportResult {
    data class Success(val body: JSONObject) : TransportResult()
    data class Failure(val httpStatus: Int?, val message: String) : TransportResult()
}

/** Sunucu ucu: `<endpoint>/<path>`. Testler sahtesini verir. */
interface OnePushTransport {
    fun send(path: String, method: String, body: JSONObject, headers: Map<String, String>): TransportResult
}

/** HttpURLConnection ile JSON; ek bağımlılık yok. Çağıran kendi iş parçacığında çağırır. */
class HttpTransport(private val endpoint: String, private val timeoutMs: Int = 20_000) : OnePushTransport {
    override fun send(path: String, method: String, body: JSONObject, headers: Map<String, String>): TransportResult {
        return try {
            val conn = (URL("$endpoint/$path").openConnection() as HttpURLConnection).apply {
                requestMethod = method
                connectTimeout = timeoutMs; readTimeout = timeoutMs
                doOutput = true
                setRequestProperty("Content-Type", "application/json; charset=utf-8")
                headers.forEach { (k, v) -> setRequestProperty(k, v) }
            }
            conn.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            val code = conn.responseCode
            val text = (if (code in 200..299) conn.inputStream else conn.errorStream)?.bufferedReader()?.readText().orEmpty()
            conn.disconnect()
            if (code in 200..299) TransportResult.Success(runCatching { JSONObject(text.ifBlank { "{}" }) }.getOrDefault(JSONObject()))
            else TransportResult.Failure(code, "HTTP $code")
        } catch (e: Exception) {
            TransportResult.Failure(null, e.javaClass.simpleName)
        }
    }
}
