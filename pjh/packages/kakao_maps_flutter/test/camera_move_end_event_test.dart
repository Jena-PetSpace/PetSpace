import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

void main() {
  group('CameraMoveEndEvent', () {
    const baseJson = <String, Object?>{
      'latitude': 37.5665,
      'longitude': 126.978,
      'zoomLevel': 15,
      'tilt': 0,
      'rotation': 0,
    };

    test('keeps compatibility with events that do not contain movedBy', () {
      final event = CameraMoveEndEvent.fromJson(baseJson);

      expect(event.movedBy, isNull);
      expect(event.toJson(), isNot(contains('movedBy')));
    });

    test('parses and serializes a native movement origin', () {
      final event = CameraMoveEndEvent.fromJson(<String, Object?>{
        ...baseJson,
        'movedBy': 'gesture',
      });

      expect(event.movedBy, 'gesture');
      expect(event.toJson()['movedBy'], 'gesture');
    });
  });
}
