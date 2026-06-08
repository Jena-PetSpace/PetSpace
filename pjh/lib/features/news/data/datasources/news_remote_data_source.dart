import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/news_article_model.dart';

abstract class NewsRemoteDataSource {
  /// status='published' 기사만 발행일 최신순으로 조회.
  /// RLS가 published 외 행을 차단하지만, 명시적으로도 status를 필터한다.
  Future<List<NewsArticleModel>> getPublishedArticles({
    int offset = 0,
    int limit = 20,
  });
}

class NewsRemoteDataSourceImpl implements NewsRemoteDataSource {
  final SupabaseClient supabaseClient;

  NewsRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<List<NewsArticleModel>> getPublishedArticles({
    int offset = 0,
    int limit = 20,
  }) async {
    final response = await supabaseClient
        .from('news_articles')
        .select('id, title, link, source_name, published_at')
        .eq('status', 'published')
        .order('published_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List)
        .map((json) =>
            NewsArticleModel.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }
}
