import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/constants/capture_guide_content.dart';

void main() {
  group('CaptureGuideType.fromArea', () {
    test('isEmotion=true면 area와 무관하게 emotion', () {
      expect(
        CaptureGuideType.fromArea(isEmotion: true, area: '눈·귀'),
        CaptureGuideType.emotion,
      );
      expect(
        CaptureGuideType.fromArea(isEmotion: true, area: null),
        CaptureGuideType.emotion,
      );
    });

    test('건강 6부위 한글 문자열(health_area_chips 실측값) 매핑', () {
      const cases = {
        '눈·귀': CaptureGuideType.eyeEar,
        '코·입': CaptureGuideType.noseMouth,
        '피부·털': CaptureGuideType.skinFur,
        '체형(BCS)': CaptureGuideType.bodyBcs,
        '자세·체형 대칭': CaptureGuideType.posture,
        '종합(전체)': CaptureGuideType.fullBody,
      };
      cases.forEach((area, expected) {
        expect(
          CaptureGuideType.fromArea(isEmotion: false, area: area),
          expected,
          reason: 'area "$area" 매핑 불일치',
        );
      });
    });

    test('알 수 없는 부위는 디버그에서 assert로 즉시 발견', () {
      expect(
        () => CaptureGuideType.fromArea(isEmotion: false, area: '꼬리'),
        throwsAssertionError,
      );
    });
  });

  group('CaptureGuideContent.of', () {
    test('7종 전부 콘텐츠가 존재하고 필수 구성 충족', () {
      for (final type in CaptureGuideType.values) {
        final content = CaptureGuideContent.of(type);
        expect(content.type, type);
        expect(content.title, isNotEmpty);
        expect(content.subtitle, isNotEmpty);
        expect(content.goodExamples.length, inInclusiveRange(1, 2),
            reason: '$type 좋은 예는 1~2장');
        expect(content.badExamples.length, inInclusiveRange(2, 3),
            reason: '$type 나쁜 예는 2~3장');
        expect(content.checklist.length, inInclusiveRange(3, 4),
            reason: '$type 체크리스트는 3~4개');
      }
    });

    test('에셋 경로는 고정 파일명 계약(good_N/bad_N.jpg)을 따른다', () {
      final goodPattern =
          RegExp(r'^assets/images/capture_guide/[a-z_]+/good_\d\.jpg$');
      final badPattern =
          RegExp(r'^assets/images/capture_guide/[a-z_]+/bad_\d\.jpg$');
      for (final type in CaptureGuideType.values) {
        final content = CaptureGuideContent.of(type);
        for (final e in content.goodExamples) {
          expect(goodPattern.hasMatch(e.assetPath), isTrue,
              reason: '${e.assetPath} 형식 위반');
        }
        for (final e in content.badExamples) {
          expect(badPattern.hasMatch(e.assetPath), isTrue,
              reason: '${e.assetPath} 형식 위반');
        }
      }
    });
  });
}
