import 'package:package_info_plus/package_info_plus.dart';

/// 앱 빌드 메타데이터를 UI가 플랫폼 플러그인에 직접 의존하지 않고 사용하도록
/// 정규화한 값 객체다.
class AppPackageInfo {
  final String version;
  final String buildNumber;

  const AppPackageInfo({required this.version, required this.buildNumber});

  String get displayVersion =>
      buildNumber.trim().isEmpty ? version : '$version ($buildNumber)';

  static Future<AppPackageInfo> load() async {
    final info = await PackageInfo.fromPlatform();
    return AppPackageInfo(version: info.version, buildNumber: info.buildNumber);
  }
}
