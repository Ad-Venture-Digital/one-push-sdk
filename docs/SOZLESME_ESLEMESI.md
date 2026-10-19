# SDK ↔ sözleşme eşlemesi (docs/ONE_PUSH_PLANI.md bölüm 4–6)

| Sözleşme | iOS | Android | Durum |
|---|---|---|---|
| `start(appKey, options)` | `OnePush.start(OnePushConfig)` | `OnePush.start(context, OnePushConfig)` | var |
| `setUserId / clearUserId` | var | var | var |
| `setUserAttribute(key, value)` | var (string) | var (string) | sayı/bool/tarih değer türleri 0.2 |
| `addTag / removeTag` | var | var | var |
| `requestPermission(softPrompt)` | var (kanca) | `requestPermission(activity)` (ön ekran uygulamada) | ön ekran arayüzü 0.2 |
| `track(event, params)` | var, 72 s atıf penceresi | var | var |
| `setConsent(granted)` | var: kapanınca DELETE register | var | var |
| `inbox.list / markRead` | yerel | yerel | sunucu kutusu 0.2 |
| `handle(remoteMessage \| userInfo)` | `handle` / `didOpen` | `handle(data)` / `didOpen` / `handleIntent` | var |
| `isOnePushMessage` | var | var | var |
| Ortam bildirimi | makbuz + DEBUG | debuggable + yükleyici | var (Android sınırı yazılı) |
| Teslim (delivered) | NSE `OnePushNotificationService.process` | yalnız servis çağrılınca (data mesajı / ön plan) | var |
| GA4 köprüsü `one_push_open` | `analyticsLogger` kancası | `analyticsLogger` kancası | Firebase adaptörü 0.2 |
| Sessiz push ile kaldırma tespiti | — | — | 0.2 (sunucu tarafı) |
| Kayıt gövdesi (`POST register`) | bölüm 5 alanları | bölüm 5 alanları | var |
| Olay gövdesi (`POST event`) | `{events: [...]}` parti | aynı | var |
