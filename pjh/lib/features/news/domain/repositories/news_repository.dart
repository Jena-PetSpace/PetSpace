import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/news_article.dart';

abstract class NewsRepository {
  /// 발행(published)된 기사를 발행일 최신순으로 조회.
  /// [offset]/[limit]으로 페이지네이션.
  Future<Either<Failure, List<NewsArticle>>> getPublishedArticles({
    int offset = 0,
    int limit = 20,
  });
}
