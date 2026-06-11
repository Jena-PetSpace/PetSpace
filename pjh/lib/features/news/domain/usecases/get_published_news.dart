import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/news_article.dart';
import '../repositories/news_repository.dart';

class GetPublishedNews
    implements UseCase<List<NewsArticle>, GetPublishedNewsParams> {
  final NewsRepository repository;

  GetPublishedNews(this.repository);

  @override
  Future<Either<Failure, List<NewsArticle>>> call(
      GetPublishedNewsParams params) {
    return repository.getPublishedArticles(
      offset: params.offset,
      limit: params.limit,
    );
  }
}

class GetPublishedNewsParams extends Equatable {
  final int offset;
  final int limit;

  const GetPublishedNewsParams({
    this.offset = 0,
    this.limit = 20,
  });

  @override
  List<Object?> get props => [offset, limit];
}
