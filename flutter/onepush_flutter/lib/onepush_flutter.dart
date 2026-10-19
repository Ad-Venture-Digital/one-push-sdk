/// Ad Venture One Push — Flutter köprüsü. Yüzey çekirdekle birebir
/// (docs/ONE_PUSH_PLANI.md bölüm 4); köprü push işi yapmaz, yalnız iletir.
library onepush_flutter;

import 'dart:async';
import 'package:flutter/services.dart';

class OnePushInboxItem {
  final String pushId;
  final String? title;
  final String? body;
  final String? deepLink;
  final DateTime receivedAt;
  final bool read;
  const OnePushInboxItem(this.pushId, this.title, this.body, this.deepLink, this.receivedAt, this.read);

  factory OnePushInboxItem.fromMap(Map<dynamic, dynamic> m) => OnePushInboxItem(
        m['push_id'] as String,
        m['title'] as String?,
        m['body'] as String?,
        m['deep_link'] as String?,
        DateTime.fromMillisecondsSinceEpoch((m['received_at'] as num).toInt(), isUtc: true),
        m['read'] == true,
      );
}

class OnePush {
  OnePush._();
  static const MethodChannel channel = MethodChannel('com.adventure.onepush/flutter');
  static const String payloadIdKey = 'one_push_id';

  /// Uygulama anahtarı One sihirbazından. `environment`: auto | debug | test | production.
  static Future<void> start(String appKey,
          {String? endpoint, String environment = 'auto', bool guestMode = true}) =>
      channel.invokeMethod('start', {
        'appKey': appKey,
        if (endpoint != null) 'endpoint': endpoint,
        'environment': environment,
        'guestMode': guestMode,
      });

  static Future<void> setPushToken(String token) => channel.invokeMethod('setPushToken', {'token': token});
  static Future<void> setAppInstanceId(String id) => channel.invokeMethod('setAppInstanceId', {'id': id});
  static Future<void> setUserId(String id) => channel.invokeMethod('setUserId', {'id': id});
  static Future<void> clearUserId() => channel.invokeMethod('clearUserId');
  static Future<void> setUserAttribute(String key, String? value) =>
      channel.invokeMethod('setUserAttribute', {'key': key, 'value': value});
  static Future<void> addTag(String tag) => channel.invokeMethod('addTag', {'tag': tag});
  static Future<void> removeTag(String tag) => channel.invokeMethod('removeTag', {'tag': tag});
  static Future<void> setConsent(bool granted) => channel.invokeMethod('setConsent', {'granted': granted});
  static Future<void> track(String event, [Map<String, String> params = const {}]) =>
      channel.invokeMethod('track', {'event': event, 'params': params});
  static Future<void> flush() => channel.invokeMethod('flush');

  /// Payload bizim mi? Saf Dart; natife gitmez (yönlendirme kararı ucuz olmalı).
  static bool isOnePushMessage(Map<dynamic, dynamic>? data) {
    final v = data?[payloadIdKey];
    return v is String && v.trim().isNotEmpty;
  }

  /// Bildirim ALINDI (firebase_messaging `RemoteMessage.data`). Bizim değilse false.
  static Future<bool> handle(Map<dynamic, dynamic>? data) async {
    if (!isOnePushMessage(data)) return false;
    return (await channel.invokeMethod<bool>('handle', {'data': _strings(data!)})) ?? false;
  }

  /// Kullanıcı bildirime DOKUNDU. Bizim değilse false.
  static Future<bool> didOpen(Map<dynamic, dynamic>? data) async {
    if (!isOnePushMessage(data)) return false;
    return (await channel.invokeMethod<bool>('didOpen', {'data': _strings(data!)})) ?? false;
  }

  static Future<List<OnePushInboxItem>> inbox({int limit = 50}) async {
    final list = await channel.invokeMethod<List<dynamic>>('inbox', {'limit': limit}) ?? const [];
    return list.map((e) => OnePushInboxItem.fromMap(e as Map)).toList();
  }

  static Future<void> markInboxRead(String pushId) => channel.invokeMethod('markInboxRead', {'pushId': pushId});

  /// iOS: sistem izni; Android 13+: POST_NOTIFICATIONS. Ön ekran uygulamanın kendi UI'sı (K16).
  static Future<bool> requestPermission() async =>
      (await channel.invokeMethod<bool>('requestPermission')) ?? false;
  static Future<void> refreshPermissionStatus() => channel.invokeMethod('refreshPermissionStatus');

  static Map<String, String> _strings(Map<dynamic, dynamic> m) =>
      {for (final e in m.entries) e.key.toString(): e.value?.toString() ?? ''};
}
