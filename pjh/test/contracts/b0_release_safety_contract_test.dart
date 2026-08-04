import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

Iterable<File> _dartFiles(String root) => Directory(root)
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'));

void main() {
  test('FCM과 realtime release 로그에 payload·record·식별자를 남기지 않는다', () {
    final fcm = _read('lib/core/services/fcm_service.dart');
    final realtime = _read('lib/core/services/realtime_service.dart');

    const forbiddenFcm = [
      r"라우팅: ${message.data}",
      r"Title: ${message.notification?.title}",
      r"Body: ${message.notification?.body}",
      r"Data: ${message.data}",
      'error: e',
      'stackTrace: stackTrace',
    ];
    const forbiddenRealtime = [
      r"${payload.newRecord}",
      r"${payload.oldRecord}",
      r"for user: $userId",
      r"for post: $postId",
      r"channel: $channelName",
      'error: e',
      'stackTrace: stackTrace',
    ];

    for (final pattern in forbiddenFcm) {
      expect(fcm, isNot(contains(pattern)), reason: pattern);
    }
    for (final pattern in forbiddenRealtime) {
      expect(realtime, isNot(contains(pattern)), reason: pattern);
    }

    final sensitiveLogLines = _dartFiles('lib')
        .expand((file) => file.readAsLinesSync())
        .where((line) => line.contains('log(') || line.contains('print('))
        .where((line) => RegExp(
              r'(message\.data|notification\?\.(title|body)|payload\.(newRecord|oldRecord)|deviceToken|fcm.?token)',
              caseSensitive: false,
            ).hasMatch(line))
        .toList();
    expect(sensitiveLogLines, isEmpty);
  });

  test('로그 제거 후 알림 라우팅과 realtime event 전달 분기는 유지한다', () {
    final fcm = _read('lib/core/services/fcm_service.dart');
    final realtime = _read('lib/core/services/realtime_service.dart');
    final local = _read('lib/core/services/local_notification_service.dart');
    final main = _read('lib/main.dart');

    expect(main, contains('firebaseMessagingBackgroundHandler'));
    expect(fcm, contains('_routeFromData(message.data)'));
    expect(fcm, contains('LocalNotificationService.buildPayload'));
    expect(local, contains('_parsePayload(payload)'));
    expect(realtime, contains("'data': payload.newRecord"));
    expect(realtime, contains("'data': payload.oldRecord"));

    final crashSinkCount = <String>[fcm, realtime]
        .where((source) => RegExp(
              r'(recordError|recordFlutterError|recordFlutterFatalError|breadcrumb)',
              caseSensitive: false,
            ).hasMatch(source))
        .length;
    expect(crashSinkCount, 0);
  });

  test('Android release는 debug signing fallback 없이 release task만 차단한다', () {
    final gradle = _read('android/app/build.gradle.kts');
    final rootIgnore = _read('../.gitignore');
    final androidIgnore = _read('android/.gitignore');

    expect(gradle, contains('gradle.taskGraph.whenReady'));
    expect(gradle, contains('releaseTaskRequested'));
    expect(gradle, contains('!releaseSigningReady'));
    expect(gradle, contains('PetSpace release signing is not configured'));
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
    expect(rootIgnore, contains('android/key.properties'));
    expect(androidIgnore, contains('key.properties'));
  });
}
