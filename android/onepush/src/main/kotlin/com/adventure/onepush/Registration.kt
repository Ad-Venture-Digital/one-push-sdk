package com.adventure.onepush

import org.json.JSONArray
import org.json.JSONObject

/** Cihaz ve uygulama bilgisi; Android tarafı `DeviceInfo.fromContext`, testte elle. */
data class DeviceInfo(
    val appVersion: String,
    val osVersion: String,
    val deviceModel: String,
    val locale: String,
    val timeZone: String,
)

/** Kayıt gövdesi (`POST /push/v1/register`). */
data class RegistrationPayload(
    val token: String,
    val appInstanceId: String?,
    val userId: String?,
    val attributes: Map<String, String>,
    val tags: List<String>,
    val device: DeviceInfo,
    val environment: OnePushEnvironment,
    val consent: Boolean,
    val permission: String,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("token", token); put("platform", "android")
        appInstanceId?.let { put("app_instance_id", it) }
        userId?.let { put("user_id", it) }
        put("attributes", JSONObject(attributes))
        put("tags", JSONArray(tags.sorted()))
        put("locale", device.locale); put("tz", device.timeZone)
        put("app_version", device.appVersion); put("os_version", device.osVersion)
        put("device_model", device.deviceModel)
        put("environment", environment.wire); put("consent", consent)
        put("permission", permission); put("sdk_version", ONE_PUSH_SDK_VERSION)
    }
}
