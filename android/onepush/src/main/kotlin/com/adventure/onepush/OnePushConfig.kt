package com.adventure.onepush

const val ONE_PUSH_SDK_VERSION = "0.1.0"

/** Gönderimde seçilebilen hedef ortam; SDK ortamı KENDİSİ bildirir (K16/K26). */
enum class OnePushEnvironment(val wire: String) {
    AUTO("auto"), DEBUG("debug"), TEST("test"), PRODUCTION("production");
}

/**
 * Başlatma ayarları. appKey gizli değildir (APK'dan okunur); güvenlik sunucudaki
 * paket adı eşlemesi ve hız sınırındadır (K15).
 */
data class OnePushConfig(
    val appKey: String,
    val endpoint: String = "https://one.adventuredigital.com/push/v1",
    val environment: OnePushEnvironment = OnePushEnvironment.AUTO,
    /** Misafir modu (K12): kendi FirebaseMessagingService'imizi bildirmeyiz. */
    val guestMode: Boolean = true,
    /** track() hangi push'a bağlanır: son açılıştan bu yana geçen süre. */
    val attributionWindowMs: Long = 72L * 3600 * 1000,
    val batchSize: Int = 50,
    val logger: ((String) -> Unit)? = null,
)
