import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/news/data/models/news_article_model.dart';
import 'package:meong_nyang_diary/features/news/domain/entities/news_article.dart';

void main() {
  group('NewsArticleModel.fromJson', () {
    test('전체 필드 매핑 (published_at 포함)', () {
      final json = {
        'id': 'a-1',
        'title': '강아지 산책 가이드',
        'link': 'https://example.com/news/1',
        'source_name': '데일리벳',
        'published_at': '2026-06-08T02:24:13+00:00',
        // 앱이 쓰지 않는 검수/운영 컬럼이 섞여 와도 무시되어야 함
        'status': 'published',
        'collected_at': '2026-06-08T03:00:00+00:00',
      };

      final model = NewsArticleModel.fromJson(json);

      expect(model, isA<NewsArticle>());
      expect(model.id, 'a-1');
      expect(model.title, '강아지 산책 가이드');
      expect(model.link, 'https://example.com/news/1');
      expect(model.sourceName, '데일리벳');
      expect(model.publishedAt,
          DateTime.parse('2026-06-08T02:24:13+00:00'));
    });

    test('published_at 이 null 이면 publishedAt 도 null', () {
      final json = {
        'id': 'a-2',
        'title': '고양이 발톱 관리',
        'link': 'https://example.com/news/2',
        'source_name': '뉴스펫',
        'published_at': null,
      };

      final model = NewsArticleModel.fromJson(json);

      expect(model.publishedAt, isNull);
    });

    test('파싱 불가능한 published_at 은 null 로 안전 처리', () {
      final json = {
        'id': 'a-3',
        'title': '반려동물 건강검진',
        'link': 'https://example.com/news/3',
        'source_name': '구글뉴스',
        'published_at': 'not-a-date',
      };

      final model = NewsArticleModel.fromJson(json);

      expect(model.publishedAt, isNull);
    });
  });
}
