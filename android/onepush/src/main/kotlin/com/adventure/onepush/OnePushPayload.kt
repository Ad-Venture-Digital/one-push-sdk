package com.adventure.onepush

/**
 * Bizim push'umuzun data alanları. Yönlendirme işareti `one_push_id`: taşıyorsa
 * One'ındır, taşımıyorsa öteki sağlayıcınındır (K12). FCM `RemoteMessage.data`
 * ya da açılış Intent'inin extras'ından Map<String, String> olarak gelir.
 */
data class OnePushPayload(
    val pushId: String,
    val pushType: String?,
    val campaignId: String?,
    val deepLink: String?,
    val imageUrl: String?,
    val title: String?,
    val body: String?,
) {
    companion object {
        const val ID = "one_push_id"
        const val TYPE = "one_push_turu"
        const val CAMPAIGN = "one_kampanya_id"
        const val DEEP_LINK = "one_deeplink"
        const val IMAGE = "one_image"
        const val TITLE = "one_baslik"
        const val BODY = "one_metin"

        fun from(data: Map<String, String?>?): OnePushPayload? {
            val id = data?.get(ID)?.takeIf { it.isNotBlank() } ?: return null
            return OnePushPayload(
                pushId = id, pushType = data[TYPE], campaignId = data[CAMPAIGN],
                deepLink = data[DEEP_LINK], imageUrl = data[IMAGE],
                title = data[TITLE], body = data[BODY],
            )
        }

        fun isOnePush(data: Map<String, String?>?): Boolean = from(data) != null
    }
}
