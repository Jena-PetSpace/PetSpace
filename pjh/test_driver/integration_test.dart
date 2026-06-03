import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// 통합 테스트 스크린샷 드라이버.
///
/// 실행:
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/06_mbti_test.dart -d windows
///
/// takeScreenshot(name) 호출 시 build/integration_screenshots/<name>.png 로 저장.
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final dir = Directory('build/integration_screenshots');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final file = File('${dir.path}/$name.png');
      file.writeAsBytesSync(bytes);
      return true;
    },
  );
}
