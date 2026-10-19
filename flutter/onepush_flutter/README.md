# onepush_flutter

Flutter bridge for Ad Venture One Push. The bridge forwards calls to the native cores (`ios/`, `android/onepush`); it has no Firebase dependency of its own. With `firebase_messaging`:

```dart
await OnePush.start('<app key from the One wizard>');
FirebaseMessaging.instance.getToken().then((t) { if (t != null) OnePush.setPushToken(t); });
FirebaseMessaging.instance.onTokenRefresh.listen(OnePush.setPushToken);
FirebaseMessaging.onMessage.listen((m) => OnePush.handle(m.data));          // received
FirebaseMessaging.onMessageOpenedApp.listen((m) => OnePush.didOpen(m.data)); // tapped
```

Messages that are not One's (`one_push_id` missing) return `false` and are left to your other provider. Status: written 19 Oct 2026, **not yet run** (no Flutter SDK on the build machine); `flutter test` covers the channel contract.
