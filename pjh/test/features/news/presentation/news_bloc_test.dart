import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/news/domain/entities/news_article.dart';
import 'package:meong_nyang_diary/features/news/domain/usecases/get_published_news.dart';
import 'package:meong_nyang_diary/features/news/presentation/bloc/news_bloc.dart';

class MockGetPublishedNews extends Mock implements GetPublishedNews {}

class _FakeParams extends Fake implements GetPublishedNewsParams {}

NewsArticle _article(int i) => NewsArticle(
      id: 'a-$i',
      title: '뉴스 $i',
      link: 'https://example.com/$i',
      sourceName: '데일리벳',
      publishedAt: DateTime(2026, 6, 8),
    );

// pageSize(20)개 → hasMore=true 판정용
final _fullPage = List.generate(NewsBloc.pageSize, _article);

void main() {
  setUpAll(() => registerFallbackValue(_FakeParams()));

  late MockGetPublishedNews getPublishedNews;

  setUp(() => getPublishedNews = MockGetPublishedNews());

  NewsBloc build() => NewsBloc(getPublishedNews: getPublishedNews);

  group('LoadNews', () {
    blocTest<NewsBloc, NewsState>(
      '성공 → [Loading, Loaded] (가득 차면 hasMore=true)',
      build: () {
        when(() => getPublishedNews(any()))
            .thenAnswer((_) async => Right(_fullPage));
        return build();
      },
      act: (b) => b.add(const LoadNews()),
      expect: () => [
        const NewsLoading(),
        NewsLoaded(articles: _fullPage, hasMore: true),
      ],
    );

    blocTest<NewsBloc, NewsState>(
      '결과가 pageSize 미만이면 hasMore=false',
      build: () {
        when(() => getPublishedNews(any()))
            .thenAnswer((_) async => Right([_article(1)]));
        return build();
      },
      act: (b) => b.add(const LoadNews()),
      expect: () => [
        const NewsLoading(),
        NewsLoaded(articles: [_article(1)], hasMore: false),
      ],
    );

    blocTest<NewsBloc, NewsState>(
      '실패 → [Loading, Error]',
      build: () {
        when(() => getPublishedNews(any())).thenAnswer(
            (_) async => const Left(NetworkFailure(message: '네트워크 오류')));
        return build();
      },
      act: (b) => b.add(const LoadNews()),
      expect: () => [
        const NewsLoading(),
        const NewsError('네트워크 오류'),
      ],
    );
  });

  group('LoadMoreNews', () {
    blocTest<NewsBloc, NewsState>(
      '다음 페이지를 기존 목록에 이어붙임',
      build: () {
        // 첫 호출(LoadNews): 가득 찬 페이지, 둘째 호출(LoadMore): 1건
        final responses = <Either<Failure, List<NewsArticle>>>[
          Right(_fullPage),
          Right([_article(100)]),
        ];
        var call = 0;
        when(() => getPublishedNews(any()))
            .thenAnswer((_) async => responses[call++]);
        return build();
      },
      act: (b) async {
        b.add(const LoadNews());
        await Future<void>.delayed(Duration.zero);
        b.add(const LoadMoreNews());
      },
      skip: 2, // Loading, 첫 Loaded 건너뛰고 LoadMore 결과만 검증
      expect: () => [
        // isLoadingMore=true 중간 상태
        NewsLoaded(articles: _fullPage, hasMore: true, isLoadingMore: true),
        // 이어붙인 최종 상태 (1건이라 hasMore=false)
        NewsLoaded(
          articles: [..._fullPage, _article(100)],
          hasMore: false,
          isLoadingMore: false,
        ),
      ],
    );

    blocTest<NewsBloc, NewsState>(
      'hasMore=false 면 추가 로드하지 않음',
      build: () {
        when(() => getPublishedNews(any()))
            .thenAnswer((_) async => Right([_article(1)])); // 미만 → hasMore=false
        return build();
      },
      act: (b) async {
        b.add(const LoadNews());
        await Future<void>.delayed(Duration.zero);
        b.add(const LoadMoreNews());
      },
      expect: () => [
        const NewsLoading(),
        NewsLoaded(articles: [_article(1)], hasMore: false),
        // LoadMore 는 무시되어 추가 상태 없음
      ],
    );
  });
}
