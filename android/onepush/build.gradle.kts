plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.adventure.onepush"
    compileSdk = 34
    defaultConfig { minSdk = 26 }   // K18: Android 8
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = "17" }
}

dependencies {
    // Çekirdek Firebase'e bağımlı DEĞİL (misafir modu); adaptör modülü ayrı.
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")   // android.jar'daki org.json JVM testinde stub'dur
}
