import 'package:flutter/foundation.dart';

/// 촬영가이드 7종 (감정 1 + 건강 6).
/// 건강 부위 한글 표기는 health_area_chips.dart의 드롭다운 문자열과
/// 글자 단위로 일치해야 한다 — [CaptureGuideType.fromArea] 참조.
enum CaptureGuideType {
  emotion,
  eyeEar,
  noseMouth,
  skinFur,
  bodyBcs,
  posture,
  fullBody;

  /// 가이드 페이지가 받는 (isEmotion, area 한글 문자열) → 타입 매핑.
  /// case 문자열은 HealthArea.displayName(health_analysis.dart) 실측값 기준.
  static CaptureGuideType fromArea({required bool isEmotion, String? area}) {
    if (isEmotion) return CaptureGuideType.emotion;
    switch (area) {
      case '눈·귀':
        return CaptureGuideType.eyeEar;
      case '코·입':
        return CaptureGuideType.noseMouth;
      case '피부·털':
        return CaptureGuideType.skinFur;
      case '체형(BCS)':
        return CaptureGuideType.bodyBcs;
      case '자세·체형 대칭':
        return CaptureGuideType.posture;
      case '종합(전체)':
        return CaptureGuideType.fullBody;
      default:
        assert(false, 'CaptureGuideType 매핑 실패: $area');
        debugPrint('CaptureGuideType.fromArea: 알 수 없는 부위 "$area" → fullBody 폴백');
        return CaptureGuideType.fullBody;
    }
  }
}

/// 좋은 예/나쁜 예 사진 1장. caption은 좋은 예=조건 설명, 나쁜 예=실패 원인 한 줄.
class GuideExample {
  final String assetPath;
  final String caption;

  const GuideExample({required this.assetPath, required this.caption});
}

/// 가이드 1종의 정적 콘텐츠. 에셋 파일명 계약(good_N/bad_N.jpg)에 의존하므로
/// 파일명 변경 금지 — 실사진 교체는 파일 내용만 갈아끼운다.
class CaptureGuideContent {
  final CaptureGuideType type;
  final String title;
  final String subtitle;
  final List<GuideExample> goodExamples;
  final List<GuideExample> badExamples;
  final List<String> checklist;

  const CaptureGuideContent({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.goodExamples,
    required this.badExamples,
    required this.checklist,
  });

  static CaptureGuideContent of(CaptureGuideType type) => _contents[type]!;

  static const String _base = 'assets/images/capture_guide';

  static const Map<CaptureGuideType, CaptureGuideContent> _contents = {
    CaptureGuideType.emotion: CaptureGuideContent(
      type: CaptureGuideType.emotion,
      title: '감정 분석 촬영 가이드',
      subtitle: '얼굴이 잘 보여야 감정을 정확히 읽어요',
      goodExamples: [
        GuideExample(
          assetPath: '$_base/emotion/good_1.jpg',
          caption: '정면 얼굴 전체가 화면에, 자연광',
        ),
      ],
      badExamples: [
        GuideExample(
          assetPath: '$_base/emotion/bad_1.jpg',
          caption: '역광 — 얼굴이 어두워요',
        ),
        GuideExample(
          assetPath: '$_base/emotion/bad_2.jpg',
          caption: '얼굴이 안 보여요',
        ),
        GuideExample(
          assetPath: '$_base/emotion/bad_3.jpg',
          caption: '너무 멀어요',
        ),
      ],
      checklist: [
        '얼굴 전체가 화면에 나오게',
        '밝은 곳에서 (역광 피하기)',
        '정면 또는 살짝 측면',
        '필터·보정 없이',
      ],
    ),
    CaptureGuideType.eyeEar: CaptureGuideContent(
      type: CaptureGuideType.eyeEar,
      title: '눈·귀 촬영 가이드',
      subtitle: '가까이, 선명하게 찍을수록 정확해요',
      goodExamples: [
        GuideExample(
          assetPath: '$_base/eye_ear/good_1.jpg',
          caption: '눈 클로즈업 — 눈물자국까지 보이게',
        ),
        GuideExample(
          assetPath: '$_base/eye_ear/good_2.jpg',
          caption: '귓바퀴를 들어 귀 안쪽이 보이게',
        ),
      ],
      badExamples: [
        GuideExample(
          assetPath: '$_base/eye_ear/bad_1.jpg',
          caption: '초점이 흐려요',
        ),
        GuideExample(
          assetPath: '$_base/eye_ear/bad_2.jpg',
          caption: '너무 어두워요',
        ),
        GuideExample(
          assetPath: '$_base/eye_ear/bad_3.jpg',
          caption: '털에 가려졌어요',
        ),
      ],
      checklist: [
        '손으로 털을 살짝 넘겨 부위 노출',
        '10~15cm 거리에서 초점 확인',
        '밝은 조명 아래에서',
        '어두우면 플래시 사용',
      ],
    ),
    CaptureGuideType.noseMouth: CaptureGuideContent(
      type: CaptureGuideType.noseMouth,
      title: '코·입 촬영 가이드',
      subtitle: '코 표면과 잇몸 색이 보이면 충분해요',
      goodExamples: [
        GuideExample(
          assetPath: '$_base/nose_mouth/good_1.jpg',
          caption: '코 정면 클로즈업',
        ),
        GuideExample(
          assetPath: '$_base/nose_mouth/good_2.jpg',
          caption: '입술을 살짝 들어 잇몸이 보이게',
        ),
      ],
      badExamples: [
        GuideExample(
          assetPath: '$_base/nose_mouth/bad_1.jpg',
          caption: '초점이 나갔어요',
        ),
        GuideExample(
          assetPath: '$_base/nose_mouth/bad_2.jpg',
          caption: '그림자가 졌어요',
        ),
      ],
      checklist: [
        '코는 정면에서 가까이',
        '잇몸은 입술을 살짝 들어서',
        '그림자 지지 않게 밝은 곳에서',
      ],
    ),
    CaptureGuideType.skinFur: CaptureGuideContent(
      type: CaptureGuideType.skinFur,
      title: '피부·털 촬영 가이드',
      subtitle: '털을 갈라 피부가 직접 보이게 찍어주세요',
      goodExamples: [
        GuideExample(
          assetPath: '$_base/skin_fur/good_1.jpg',
          caption: '털을 갈라 피부 노출, 10~15cm 근접',
        ),
      ],
      badExamples: [
        GuideExample(
          assetPath: '$_base/skin_fur/bad_1.jpg',
          caption: '털에 가려 피부가 안 보여요',
        ),
        GuideExample(
          assetPath: '$_base/skin_fur/bad_2.jpg',
          caption: '너무 멀어요',
        ),
        GuideExample(
          assetPath: '$_base/skin_fur/bad_3.jpg',
          caption: '너무 어두워요',
        ),
      ],
      checklist: [
        '손으로 털을 갈라 피부 노출',
        '이상 부위 중심으로 근접 촬영',
        '밝은 곳 또는 플래시 사용',
        '물기·이물질은 닦은 후에',
      ],
    ),
    CaptureGuideType.bodyBcs: CaptureGuideContent(
      type: CaptureGuideType.bodyBcs,
      title: '체형(BCS) 촬영 가이드',
      subtitle: '서 있는 옆모습이 체형 평가의 기준이에요',
      goodExamples: [
        GuideExample(
          assetPath: '$_base/body_bcs/good_1.jpg',
          caption: '평지에 서 있는 측면 전신',
        ),
      ],
      badExamples: [
        GuideExample(
          assetPath: '$_base/body_bcs/bad_1.jpg',
          caption: '앉거나 누워 있어요',
        ),
        GuideExample(
          assetPath: '$_base/body_bcs/bad_2.jpg',
          caption: '위에서 내려찍었어요',
        ),
        GuideExample(
          assetPath: '$_base/body_bcs/bad_3.jpg',
          caption: '몸이 잘렸어요',
        ),
      ],
      checklist: [
        '네 발로 서 있는 상태에서',
        '옆에서 수평으로 (내려찍기 금지)',
        '전신이 화면에 다 나오게',
      ],
    ),
    CaptureGuideType.posture: CaptureGuideContent(
      type: CaptureGuideType.posture,
      title: '자세·체형 대칭 촬영 가이드',
      subtitle: '뒷모습 전신으로 다리 정렬을 확인해요',
      goodExamples: [
        GuideExample(
          assetPath: '$_base/posture/good_1.jpg',
          caption: '후면 전신 — 뒷다리 나란히, 꼬리가 몸을 가리지 않게',
        ),
      ],
      badExamples: [
        GuideExample(
          assetPath: '$_base/posture/bad_1.jpg',
          caption: '꼬리가 몸을 가렸어요',
        ),
        GuideExample(
          assetPath: '$_base/posture/bad_2.jpg',
          caption: '다리가 잘렸어요',
        ),
        GuideExample(
          assetPath: '$_base/posture/bad_3.jpg',
          caption: '흔들렸어요',
        ),
      ],
      checklist: [
        '뒷발을 나란히 세우고',
        '꼬리가 몸을 가리지 않게',
        '반려동물 눈높이에서 수평으로',
        '네 다리가 모두 보이게',
      ],
    ),
    CaptureGuideType.fullBody: CaptureGuideContent(
      type: CaptureGuideType.fullBody,
      title: '종합(전체) 촬영 가이드',
      subtitle: '밝은 곳에서 전신 한 장이면 시작할 수 있어요',
      goodExamples: [
        GuideExample(
          assetPath: '$_base/full_body/good_1.jpg',
          caption: '밝은 곳, 정면 전신',
        ),
      ],
      badExamples: [
        GuideExample(
          assetPath: '$_base/full_body/bad_1.jpg',
          caption: '몸 일부만 나왔어요',
        ),
        GuideExample(
          assetPath: '$_base/full_body/bad_2.jpg',
          caption: '너무 어두워요',
        ),
      ],
      checklist: [
        '전신이 화면에 다 나오게',
        '밝은 곳에서',
        '정면 또는 측면에서 수평으로',
      ],
    ),
  };
}
