import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/core/network/network_info.dart';
import 'package:meong_nyang_diary/features/news/data/datasources/news_remote_data_source.dart';
import 'package:meong_nyang_diary/features/news/data/models/news_article_model.dart';
import 'package:meong_nyang_diary/features/news/data/repositories/news_repository_impl.dart';

class MockNewsRemoteDataSource extends Mock implements NewsRemoteDataSource {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

final _tArticles = [
  const NewsArticleModel(
    id: 'a-1',
    title: '강아지 산책 가이드',
    link: 'https://example.com/news/1',
    sourceName: '데일리벳',
  ),
];

void main() {
  late MockNewsRemoteDataSource remote;
  late MockNetworkInfo network;
  late NewsRepositoryImpl repo;

  setUp(() {
    remote = MockNewsRemoteDataSource();
    network = MockNetworkInfo();
    repo = NewsRepositoryImpl(remoteDataSource: remote, networkInfo: network);
  });

  group('getPublishedArticles', () {
    test('네트워크 연결 없으면 → Left(NetworkFailure), 데이터소스 호출 안 함', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);

      final result = await repo.getPublishedArticles();

      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<NetworkFailure>()), (_) => fail('Right'));
      verifyNever(() => remote.getPublishedArticles(
          offset: any(named: 'offset'), limit: any(named: 'limit')));
    });

    test('성공 → Right(List<NewsArticle>) (데이터소스 결과 그대로 매핑)', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(() => remote.getPublishedArticles(
              offset: any(named: 'offset'), limit: any(named: 'limit')))
          .thenAnswer((_) async => _tArticles);

      final result = await repo.getPublishedArticles(offset: 0, limit: 20);

      expect(result, Right(_tArticles));
      verify(() => remote.getPublishedArticles(offset: 0, limit: 20)).called(1);
    });

    test('PostgrestException → Left(DatabaseFailure)', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(() => remote.getPublishedArticles(
              offset: any(named: 'offset'), limit: any(named: 'limit')))
          .thenThrow(const PostgrestException(message: 'boom'));

      final result = await repo.getPublishedArticles();

      expect(result.isLeft(), true);
      result.fold(
          (f) => expect(f, isA<DatabaseFailure>()), (_) => fail('Right'));
    });

    test('기타 예외 → Left(GeneralFailure)', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(() => remote.getPublishedArticles(
              offset: any(named: 'offset'), limit: any(named: 'limit')))
          .thenThrow(Exception('unexpected'));

      final result = await repo.getPublishedArticles();

      expect(result.isLeft(), true);
      result.fold(
          (f) => expect(f, isA<GeneralFailure>()), (_) => fail('Right'));
    });
  });
}
