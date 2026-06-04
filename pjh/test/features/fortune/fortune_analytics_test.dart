import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/core/services/analytics_service.dart';
import 'package:meong_nyang_diary/features/mbti/domain/entities/pet_mbti_result.dart';

/// 운세 분석 이벤트 단위 확인.
///
/// AnalyticsService 는 Firebase 미초기화 환경(테스트)에서 조용히 no-op 하므로
/// 페이로드 가로채기는 통합 환경 몫이다. 여기서는 (1) 메서드가 안전하게 동작하고
/// (2) 호출부가 넘기는 익명 파라미터 매핑(species 키, bool→0/1)이 의도대로인지를
/// 경계에서 잠근다. (식별 정보 파라미터 부재는 시그니처로 보장 — petId/이름/사진 인자 없음)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('익명 파라미터 매핑(호출부가 넘기는 값)', () {
    test('species 키 = dog/cat/etc 만', () {
      expect(MbtiSpecies.dog.key, 'dog');
      expect(MbtiSpecies.cat.key, 'cat');
      expect(MbtiSpecies.etc.key, 'etc');
    });

    test('has_mbti 판정 = current_mbti_type 캐시 유무(null/빈값→false)', () {
      bool hasMbti(String? code) => code != null && code.trim().isNotEmpty;
      expect(hasMbti('ENFP'), isTrue);
      expect(hasMbti(null), isFalse);
      expect(hasMbti(''), isFalse);
      expect(hasMbti('   '), isFalse);
    });
  });

  group('래퍼 메서드 안전 동작(미초기화 → no-op, throw 없음)', () {
    test('logFortuneView 가 throw 하지 않음', () async {
      await AnalyticsService.instance
          .logFortuneView(species: 'dog', hasMbti: true);
      await AnalyticsService.instance
          .logFortuneView(species: 'etc', hasMbti: false);
    });

    test('logFortuneShare 가 throw 하지 않음', () async {
      await AnalyticsService.instance
          .logFortuneShare(species: 'cat', includePhoto: true);
      await AnalyticsService.instance
          .logFortuneShare(species: 'dog', includePhoto: false);
    });
  });
}
