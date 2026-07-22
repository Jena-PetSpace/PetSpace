import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/core/utils/public_ai_text.dart';

void main() {
  test('legacy emotion captions do not expose confidence percentages', () {
    expect(
      publicAiText('불편함 30% 🐾 AI 감정 분석 결과를 공유합니다'),
      '불편함 🐾 AI 감정 분석 결과를 공유합니다',
    );
    expect(
      publicAiText('공포 40% AI 감정 분석 결과를 공유합니다'),
      '공포 AI 감정 분석 결과를 공유합니다',
    );
  });

  test('ordinary user-authored percentages stay unchanged', () {
    expect(publicAiText('오늘 간식 30% 할인'), '오늘 간식 30% 할인');
  });
}
