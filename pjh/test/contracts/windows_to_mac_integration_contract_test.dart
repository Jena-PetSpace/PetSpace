import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS Kakao map readiness and failure callbacks stay compatible', () {
    final swift = File(
      'packages/kakao_maps_flutter/ios/kakao_maps_flutter/Sources/'
      'kakao_maps_flutter/KakaoMapController.swift',
    ).readAsStringSync();
    final dart = File(
      'packages/kakao_maps_flutter/lib/src/platform/kakao_map_controller/'
      'method_channel/method_channel_kakao_map_controller.dart',
    ).readAsStringSync();
    final hospitalMap = File(
      'lib/features/home/presentation/pages/hospital_search_page_map.dart',
    ).readAsStringSync();
    final locationPicker = File(
      'lib/features/social/presentation/pages/location_picker_page.dart',
    ).readAsStringSync();

    expect(swift, contains('private var isMapReady = false'));
    expect(swift, contains('case "isMapReady":'));
    expect(swift, contains('result(isMapReady)'));
    expect(swift, contains('isMapReady = true'));
    expect(swift, contains('func authenticationFailed('));
    expect(swift, contains('"map_authentication_failed"'));
    expect(dart, contains("call.method == 'onMapFailed'"));
    expect(dart, isNot(contains('throw UnimplementedError')));
    expect(
      hospitalMap,
      contains(
        'controller.ready.timeout(const Duration(seconds: 12))',
      ),
    );
    expect(hospitalMap, contains('key: ValueKey<int>(_mapViewGeneration)'));
    expect(hospitalMap, contains('onPressed: _recreateMapView'));
    expect(
      locationPicker,
      contains('ctrl.ready.timeout(const Duration(seconds: 12))'),
    );
    expect(locationPicker, contains('key: ValueKey<int>(_mapViewGeneration)'));
    expect(locationPicker, contains('onPressed: _recreateMapView'));
  });

  test('new AI history failures do not expose backend exception text', () {
    final repository = File(
      'lib/features/emotion/data/repositories/emotion_repository_impl.dart',
    ).readAsStringSync();

    final methodRanges = <String, String>{
      'getHealthAnalysisById': 'updateAnalysisMemo',
      'updateAnalysisMemo': 'getAiHistoryPage',
      'getAiHistoryPage': 'deleteAnalysis',
      'canAccessOwnedPet': 'saveHealthAnalysis',
    };

    for (final entry in methodRanges.entries) {
      final start = repository.indexOf(entry.key);
      final end = repository.indexOf(entry.value, start + entry.key.length);
      expect(start, greaterThanOrEqualTo(0), reason: entry.key);
      expect(end, greaterThan(start), reason: entry.key);
      final body = repository.substring(start, end);
      expect(body, isNot(contains(r'$e')), reason: entry.key);
      expect(body, contains('_logRepositoryFailure'), reason: entry.key);
    }
  });
}
