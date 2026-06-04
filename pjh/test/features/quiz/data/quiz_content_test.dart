import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/quiz/data/datasources/quiz_content_data_source.dart';
import 'package:meong_nyang_diary/features/quiz/domain/entities/quiz_content.dart';

/// 번들 콘텐츠 무결성 — 작업 0 검증을 코드로 고정(회귀 방지).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late QuizContent content;

  setUpAll(() async {
    content = await QuizContentDataSourceImpl().loadContent(version: 1);
  });

  group('메타', () {
    test('version=1, dailyCount=4, disclaimer 존재', () {
      expect(content.version, 1);
      expect(content.dailyCount, 4);
      expect(content.disclaimer.isNotEmpty, isTrue);
    });

    test('카테고리 10개', () {
      expect(content.categories.length, 10);
      expect(content.categories.map((c) => c.key).toSet(), {
        'behavior',
        'bodylang',
        'senses',
        'breed',
        'sound',
        'sleep',
        'training',
        'history',
        'trivia',
        'care',
      });
    });
  });

  group('문항 무결성', () {
    test('총 270문항', () {
      expect(content.questions.length, 270);
    });

    test('카테고리별 각 27문항', () {
      final byCat = <String, int>{};
      for (final q in content.questions) {
        byCat[q.category] = (byCat[q.category] ?? 0) + 1;
      }
      for (final c in content.categories) {
        expect(byCat[c.key], 27, reason: '카테고리 ${c.key}');
      }
    });

    test('id 고유', () {
      final ids = content.questions.map((q) => q.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('진술문 고유', () {
      final stmts = content.questions.map((q) => q.statement).toList();
      expect(stmts.toSet().length, stmts.length);
    });

    test('answer 는 O/X 만', () {
      final bad = content.questions.where((q) => q.answer != 'O' && q.answer != 'X');
      expect(bad, isEmpty);
    });

    test('species 는 dog/cat/common 만', () {
      const allowed = {'dog', 'cat', 'common'};
      final bad = content.questions.where((q) => !allowed.contains(q.species));
      expect(bad, isEmpty);
    });

    test('explain 누락 없음', () {
      final bad = content.questions.where((q) => q.explain.isEmpty);
      expect(bad, isEmpty);
    });

    test('id 접두사가 category 와 일치', () {
      final bad =
          content.questions.where((q) => !q.id.startsWith('${q.category}_'));
      expect(bad, isEmpty);
    });

    test('정답 분포 O:X = 60:40 근사(163:107)', () {
      final o = content.questions.where((q) => q.isAnswerO).length;
      final x = content.questions.length - o;
      expect(o, 163);
      expect(x, 107);
    });
  });

  test('labelOfCategory — key→label, 미존재 시 key 폴백', () {
    expect(content.labelOfCategory('behavior'), '행동·습성');
    expect(content.labelOfCategory('___없음'), '___없음');
  });
}
