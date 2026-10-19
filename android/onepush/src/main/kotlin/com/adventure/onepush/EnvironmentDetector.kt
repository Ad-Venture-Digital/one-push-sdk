package com.adventure.onepush

/**
 * Ortam tespiti; saf fonksiyon, JVM'de test edilir.
 *  - debuggable: ApplicationInfo.FLAG_DEBUGGABLE
 *  - installer: PackageManager.getInstallSourceInfo(...).installingPackageName
 * Sınır (yazılı): Play dahili test / kapalı test sürümü de "com.android.vending"
 * ile kurulur, yani mağaza sürümünden AYIRT EDİLEMEZ; o sürümler panelde test
 * cihazı adıyla ya da `environment` ezmesiyle işaretlenir.
 */
object EnvironmentDetector {
    const val PLAY_STORE = "com.android.vending"

    fun detect(debuggable: Boolean, installer: String?): OnePushEnvironment = when {
        debuggable -> OnePushEnvironment.DEBUG
        installer == null || installer != PLAY_STORE -> OnePushEnvironment.TEST   // yan yükleme, App Distribution, ADB
        else -> OnePushEnvironment.PRODUCTION
    }
}
