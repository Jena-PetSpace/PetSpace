import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/error_messages.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/news_article.dart';
import '../../domain/repositories/news_repository.dart';
import '../datasources/news_remote_data_source.dart';

class NewsRepositoryImpl implements NewsRepository {
  final NewsRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  NewsRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<NewsArticle>>> getPublishedArticles({
    int offset = 0,
    int limit = 20,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: ErrorMessages.networkError));
    }

    try {
      final articles = await remoteDataSource.getPublishedArticles(
        offset: offset,
        limit: limit,
      );
      return Right(articles);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(message: 'DB 오류: ${e.message}'));
    } catch (e) {
      return const Left(GeneralFailure(message: '뉴스를 불러오지 못했어요.'));
    }
  }
}
