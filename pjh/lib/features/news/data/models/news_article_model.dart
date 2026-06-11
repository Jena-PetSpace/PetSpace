import '../../domain/entities/news_article.dart';

class NewsArticleModel extends NewsArticle {
  const NewsArticleModel({
    required super.id,
    required super.title,
    required super.link,
    required super.sourceName,
    super.publishedAt,
  });

  /// news_articles 테이블 row → 엔티티.
  /// status/collected_at 등 검수·운영 컬럼은 앱에서 사용하지 않으므로 매핑 제외.
  factory NewsArticleModel.fromJson(Map<String, dynamic> json) {
    return NewsArticleModel(
      id: json['id'] as String,
      title: json['title'] as String,
      link: json['link'] as String,
      sourceName: json['source_name'] as String,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
    );
  }
}
