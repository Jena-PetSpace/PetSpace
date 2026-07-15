import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:meong_nyang_diary/core/network/network_info.dart';
import 'package:meong_nyang_diary/features/social/data/datasources/social_remote_data_source.dart';
import 'package:meong_nyang_diary/features/social/data/repositories/social_repository_impl.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/saved_posts_page.dart';

class _MockRemote extends Mock implements SocialRemoteDataSource {}

class _MockNetwork extends Mock implements NetworkInfo {}

void main() {
  late _MockRemote remote;
  late SocialRepositoryImpl repository;

  setUp(() {
    remote = _MockRemote();
    final network = _MockNetwork();
    when(() => network.isConnected).thenAnswer((_) async => true);
    repository = SocialRepositoryImpl(
      remoteDataSource: remote,
      networkInfo: network,
    );
  });

  test('limit+1 원본을 trim하고 마지막 행으로 2열 커서를 만든다', () async {
    Map<String, dynamic> row(int index) => {
          'id': 'saved-$index',
          'post_id': 'post-$index',
          'collection_id': null,
          'created_at': '2026-07-15T00:00:0${2 - index}Z',
          'posts': {
            'id': 'post-$index',
            'author_id': 'author',
            'post_type': 'photo',
            'created_at': '2026-07-14T00:00:00Z',
            'updated_at': '2026-07-14T00:00:00Z',
            'users': {'display_name': '보호자', 'photo_url': null},
          },
        };
    when(() => remote.getSavedPostsPageRaw(
          userId: 'u1',
          scope: const SavedPostsScope.all(),
          cursor: null,
          limit: 2,
        )).thenAnswer((_) async => [row(0), row(1), row(2)]);

    final result = await repository.getSavedPostsPage(
      userId: 'u1',
      scope: const SavedPostsScope.all(),
      limit: 2,
    );
    result.fold((failure) => fail(failure.message), (page) {
      expect(page.items.length, 2);
      expect(page.hasMore, isTrue);
      expect(page.nextCursor?.savedPostId, 'saved-1');
      expect(
          page.items.every((item) => item.post.isSavedByCurrentUser), isTrue);
    });
  });

  test('손상된 저장 행은 빈 목록으로 숨기지 않고 Failure를 반환한다', () async {
    when(() => remote.getSavedPostsPageRaw(
          userId: 'u1',
          scope: const SavedPostsScope.all(),
          cursor: null,
          limit: 30,
        )).thenAnswer((_) async => [
          {'id': 'saved-1', 'created_at': 'broken', 'posts': null}
        ]);
    final result = await repository.getSavedPostsPage(
      userId: 'u1',
      scope: const SavedPostsScope.all(),
    );
    expect(result.isLeft(), isTrue);
    result.fold(
      (failure) => expect(failure.message, isNot(contains('broken'))),
      (_) => fail('Failure expected'),
    );
  });

  test('컬렉션 삭제에 소유자 id를 전달한다', () async {
    when(() => remote.deleteBookmarkCollection(
          collectionId: 'c1',
          userId: 'u1',
        )).thenAnswer((_) async {});
    final result = await repository.deleteBookmarkCollection(
      collectionId: 'c1',
      userId: 'u1',
    );
    expect(result, const Right(null));
    verify(() => remote.deleteBookmarkCollection(
          collectionId: 'c1',
          userId: 'u1',
        )).called(1);
  });

  test('다른 소유자의 컬렉션으로 이동은 update 전에 거부한다', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('[]', 200,
            headers: {'content-type': 'application/json'});
      }),
    );
    final source = SocialRemoteDataSourceImpl(supabaseClient: client);
    await expectLater(
      source.updateSavedPostCollection(
        postId: 'post-1',
        userId: 'owner-1',
        collectionId: 'foreign-collection',
      ),
      throwsException,
    );
    expect(requests, hasLength(1));
    expect(requests.single.method, 'GET');
    expect(requests.single.url.query, contains('user_id=eq.owner-1'));
  });

  test('저장 이동 update가 0행이면 성공으로 처리하지 않는다', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: MockClient((request) async => http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
          )),
    );
    final source = SocialRemoteDataSourceImpl(supabaseClient: client);
    await expectLater(
      source.updateSavedPostCollection(
        postId: 'missing-post',
        userId: 'owner-1',
      ),
      throwsException,
    );
  });

  test('컬렉션 delete가 0행이면 성공으로 처리하지 않는다', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: MockClient((request) async => http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
          )),
    );
    final source = SocialRemoteDataSourceImpl(supabaseClient: client);
    await expectLater(
      source.deleteBookmarkCollection(
        collectionId: 'missing-collection',
        userId: 'owner-1',
      ),
      throwsException,
    );
  });
}
