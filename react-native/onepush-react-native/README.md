# @adventure/onepush-react-native

React Native bridge for Ad Venture One Push over the native cores. No Firebase dependency of its own; with `@react-native-firebase/messaging`:

```ts
import OnePush from '@adventure/onepush-react-native';
import messaging from '@react-native-firebase/messaging';

await OnePush.start({ appKey: '<app key from the One wizard>' });
OnePush.setPushToken(await messaging().getToken());
messaging().onTokenRefresh(OnePush.setPushToken);
messaging().onMessage(m => OnePush.handle(m.data));                 // received (foreground)
messaging().onNotificationOpenedApp(m => OnePush.didOpen(m.data));  // tapped
```

Messages without `one_push_id` return `false` and are left to your other provider. Status: written 19 Oct 2026, **not yet built** (no React Native toolchain on the build machine).
