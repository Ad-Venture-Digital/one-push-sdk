# Ad Venture One Push SDK

**English below · Türkçe aşağıda.** Version 0.1.0 (pre-release, 19 Oct 2026). Source of truth for decisions and the API contract: `docs/ONE_PUSH_PLANI.md` in the One repository.

## English

One Push is the push notification SDK for apps managed through [Ad Venture One](https://one.adventuredigital.com). This repository holds **only the SDK sources and documentation**; no keys, no app-specific configuration. The configuration the One wizard generates lives in your app, not here.

### What the SDK does, and what it leaves to tools you already have

| SDK does | Existing tools do |
|---|---|
| Registers the FCM token with One (with app instance id, user id, attributes, tags, locale, time zone, app version, **environment**) | Behavioural analytics: Google Analytics 4 / Adjust |
| Reports delivered / opened / dismissed and the optional `track()` conversion hook | Ad attribution: Adjust |
| Logs `one_push_open{push_id, push_turu, kampanya_id}` to GA4 on open (funnel bridge, via a logger you supply) | Audience definitions: Firebase / GA4 audiences |
| Local notification inbox, consent switch (KVKK/GDPR), permission status | |

The core has **no Firebase dependency**. In **guest mode** (default) your existing Firebase messaging handler forwards the token and the message; the SDK never takes over the notification delegate or messaging service, so it coexists with another push provider during migration. Routing is by payload: a One message carries `one_push_id`; anything else is not ours and is left untouched.

### iOS (Swift Package)

```swift
import OnePush

OnePush.start(OnePushConfig(appKey: "<app key from the One wizard>"))

// guest mode: from your existing Firebase Messaging delegate
func messaging(_ m: Messaging, didReceiveRegistrationToken token: String?) {
    if let t = token { OnePush.setPushToken(t) }
}
// and from UNUserNotificationCenterDelegate
func userNotificationCenter(_ c: UNUserNotificationCenter, willPresent n: UNNotification, ...) {
    if OnePush.handle(n.request.content.userInfo) { /* ours: delivered recorded */ }
}
func userNotificationCenter(_ c: UNUserNotificationCenter, didReceive r: UNNotificationResponse, ...) {
    if OnePush.didOpen(r) { return }   // ours
    // hand over to the other provider
}
```

Notification Service Extension (iOS delivery receipts and rich images): in your single NSE call `OnePushNotificationService.process(request, appKey:..., contentHandler:)`; it returns `false` for messages that are not ours so you can chain the other provider.

Requirements: iOS 15+. Build and test on a machine without Xcode: `cd ios && swift build && swift run OnePushChecks` (the checks target is an XCTest-shaped runner; with Xcode the same file moves to a test target).

### Android (Kotlin)

```kotlin
OnePush.start(context, OnePushConfig(appKey = "<app key from the One wizard>"))

// guest mode: inside your existing FirebaseMessagingService
override fun onNewToken(token: String) { OnePush.setPushToken(token); /* other provider */ }
override fun onMessageReceived(m: RemoteMessage) {
    if (OnePush.handle(m.data)) return      // ours
    /* other provider */
}
// launcher / deep-link Activity
override fun onCreate(b: Bundle?) { super.onCreate(b); OnePush.handleIntent(intent) }
```

Requirements: Android 8 (API 26)+. Module `android/onepush`; unit tests under `src/test` run on the JVM (`./gradlew :onepush:test`).

### Environment and test devices

The SDK reports the build environment itself (`debug` / `test` / `production`): on iOS from the receipt (`sandboxReceipt` = TestFlight), on Android from the installer package. Play internal-test builds look like production on Android; mark those devices as test devices in the One panel. Campaigns in One choose a target environment, so a production audience cannot be hit from a test send by mistake.

### Status (19 Oct 2026)

- iOS core: builds and passes 14 checks on macOS (no Xcode on the build machine yet; device tests pending).
- Android core: compiles with AGP 8.5.2 / Kotlin 1.9.24 / Gradle 8.9 wrapper (JDK 17); 13 JUnit tests pass on the JVM (`./gradlew :onepush:testDebugUnitTest`). No device test yet.
- Not in 0.1: Flutter / React Native bridges, Firebase adapter module (`OnePushFirebase`), server-side inbox, soft permission prompt UI (hook only), Huawei HMS (out of scope by decision K17).

---

## Türkçe

One Push, [Ad Venture One](https://one.adventuredigital.com) üzerinden yönetilen uygulamaların push notification SDK'sıdır. Bu depoda **yalnız SDK kaynakları ve belgeler** vardır; anahtar ve uygulamaya özel yapılandırma yoktur. One sihirbazının ürettiği yapılandırma markanın uygulamasında yaşar.

### SDK ne yapar, neyi elinizdeki araçlara bırakır

| SDK yapar | Mevcut araç yapar |
|---|---|
| FCM token'ını One'a kaydeder (uygulama örneği kimliği, kullanıcı kimliği, özellikler, etiketler, dil, saat dilimi, sürüm, **ortam** ile) | Davranış analitiği: GA4 / Adjust |
| Alındı / açıldı / kapatıldı olaylarını ve isteğe bağlı `track()` dönüşüm kancasını bildirir | Reklam atfı: Adjust |
| Açılışta GA4'e `one_push_open{push_id, push_turu, kampanya_id}` yazar (funnel köprüsü; logger'ı siz verirsiniz) | Kitle tanımı: Firebase / GA4 kitleleri |
| Yerel bildirim kutusu, KVKK onay anahtarı, izin durumu | |

Çekirdek **Firebase'e bağımlı değildir**. **Misafir modunda** (varsayılan) mevcut Firebase işleyiciniz token'ı ve mesajı iletir; SDK bildirim delegesini ya da mesaj servisini ele geçirmez, bu yüzden geçiş döneminde başka bir push sağlayıcısıyla birlikte çalışır. Yönlendirme payload'dan: One mesajı `one_push_id` taşır; taşımayan bizim değildir ve dokunulmaz.

Kurulum örnekleri yukarıdaki İngilizce bölümdedir (kod aynı). Gereksinimler: iOS 15+, Android 8 (API 26)+.

### Ortam ve test cihazları

SDK derleme ortamını kendisi bildirir (`debug` / `test` / `production`): iOS'ta makbuzdan (`sandboxReceipt` = TestFlight), Android'de yükleyici paketinden. Android'de Play dahili test sürümü mağaza sürümünden ayırt edilemez; o cihazlar One panelinde test cihazı olarak adlandırılır. Kampanyalar One'da hedef ortam seçer; test gönderimi yanlışlıkla üretim kitlesine gidemez.

### Durum (19 Eki 2026)

- iOS çekirdeği: macOS'ta derleniyor, 14 doğrulama yeşil (derleme makinesinde Xcode yok; cihaz testleri bekliyor).
- Android çekirdeği: AGP 8.5.2 / Kotlin 1.9.24 / Gradle 8.9 sarmalayıcı (JDK 17) ile derleniyor; 13 JUnit testi JVM'de yeşil (`./gradlew :onepush:testDebugUnitTest`). Cihaz testi henüz yok.
- 0.1'de yok: Flutter / React Native köprüleri, Firebase adaptör modülü, sunucu tarafı kutu, izin ön ekranı arayüzü (yalnız kanca), Huawei HMS (K17 ile kapsam dışı).
