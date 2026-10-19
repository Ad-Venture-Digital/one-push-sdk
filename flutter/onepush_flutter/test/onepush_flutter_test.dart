import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onepush_flutter/onepush_flutter.dart';

/// Köprü testi: kanal çağrılarının adı ve gövdesi (gerçeğin yüzeyi), yönlendirme
/// kararının natife gitmeden verilmesi. Flutter SDK ile `flutter test` koşar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(OnePush.channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'handle':
        case 'didOpen':
          return true;
        case 'inbox':
          return [
            {'push_id': 'p1', 'title': 'B', 'body': 'M', 'deep_link': null, 'received_at': 1800000000000, 'read': false}
          ];
        case 'requestPermission':
          return true;
      }
      return null;
    });
  });

  test('start gövdesi', () async {
    await OnePush.start('app_abc', environment: 'test');
    expect(calls.single.method, 'start');
    expect(calls.single.arguments, {'appKey': 'app_abc', 'environment': 'test', 'guestMode': true});
  });

  test('yönlendirme kararı natife gitmez', () async {
    expect(OnePush.isOnePushMessage({'custom': 'x'}), false);
    expect(await OnePush.handle({'custom': 'x'}), false);
    expect(calls, isEmpty);
    expect(await OnePush.didOpen({'one_push_id': 'p1', 'one_push_turu': 'promosyon'}), true);
    expect(calls.single.method, 'didOpen');
    expect(calls.single.arguments['data'], {'one_push_id': 'p1', 'one_push_turu': 'promosyon'});
  });

  test('kutu okunur', () async {
    final items = await OnePush.inbox();
    expect(items.single.pushId, 'p1');
    expect(items.single.read, false);
  });

  test('track parametreleri', () async {
    await OnePush.track('purchase', {'value': '199'});
    expect(calls.single.arguments, {'event': 'purchase', 'params': {'value': '199'}});
  });
}
