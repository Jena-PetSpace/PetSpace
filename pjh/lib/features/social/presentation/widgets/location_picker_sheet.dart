// LocationPickerSheet는 LocationPickerPage를 push하는 래퍼입니다.
// 기존 호출부(create_post_page.dart)의 LocationResult 타입 호환을 유지합니다.

import 'package:flutter/material.dart';
import '../pages/location_picker_page.dart';

export '../pages/location_picker_page.dart' show LocationPickResult;

// 기존 코드 호환을 위한 타입 alias
typedef LocationResult = LocationPickResult;

class LocationPickerSheet {
  static Future<LocationResult?> show(BuildContext context) {
    return LocationPickerPage.push(context);
  }
}
