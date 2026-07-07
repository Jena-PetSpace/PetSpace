import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/constants/camera_overlay_content.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/constants/capture_guide_content.dart';

void main() {
  group('CameraOverlayContent.of', () {
    test('7종 전부 오버레이·안내 문구 존재', () {
      for (final type in CaptureGuideType.values) {
        final content = CameraOverlayContent.of(type);
        expect(content.hint, isNotEmpty, reason: '$type 안내 문구 누락');
        expect(
          content.assetPath,
          matches(RegExp(r'^assets/images/capture_guide/overlay/[a-z_]+\.png$')),
          reason: '${content.assetPath} 경로 계약 위반',
        );
      }
    });

    test('에셋 파일명은 배치된 7장과 일치 (파일명 고정 계약)', () {
      const expected = {
        CaptureGuideType.emotion: 'emotion.png',
        CaptureGuideType.eyeEar: 'eye_ear.png',
        CaptureGuideType.noseMouth: 'nose_mouth.png',
        CaptureGuideType.skinFur: 'skin_fur.png',
        CaptureGuideType.bodyBcs: 'body_bcs.png',
        CaptureGuideType.posture: 'posture.png',
        CaptureGuideType.fullBody: 'full_body.png',
      };
      expected.forEach((type, fileName) {
        expect(
          CameraOverlayContent.of(type).assetPath.endsWith('/$fileName'),
          isTrue,
          reason: '$type → $fileName 불일치',
        );
      });
    });
  });
}
