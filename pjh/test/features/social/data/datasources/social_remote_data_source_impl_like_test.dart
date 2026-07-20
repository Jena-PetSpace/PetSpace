import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:meong_nyang_diary/features/social/data/datasources/social_remote_data_source.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/post_likes_page.dart';

void main() {
  test('uses one joined likes query and one outbound-follow batch query',
      () async {
    final requests = <http.Request>[];
    final rows = [
      {
        'id': 'like-3',
        'user_id': 'viewer',
        'created_at': '2026-07-18T03:00:00Z',
        'users': {
          'id': 'viewer',
          'display_name': 'Viewer',
          'username': 'viewer',
          'photo_url': null,
        },
      },
      {
        'id': 'like-2',
        'user_id': 'user-2',
        'created_at': '2026-07-18T02:00:00Z',
        'users': {
          'id': 'user-2',
          'display_name': 'Mina',
          'username': 'mina',
          'photo_url': 'https://example.com/mina.png',
        },
      },
      {
        'id': 'like-1',
        'user_id': 'user-1',
        'created_at': '2026-07-18T01:00:00Z',
        'users': {
          'id': 'user-1',
          'display_name': 'Joon',
          'username': 'joon',
          'photo_url': null,
        },
      },
    ];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/likes')) {
          return http.Response(
            jsonEncode(rows),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (request.url.path.endsWith('/follows')) {
          return http.Response(
            jsonEncode([
              {'following_id': 'user-2'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    final source = SocialRemoteDataSourceImpl(supabaseClient: client);

    final page = await source.getPostLikesPage(
      postId: 'post-1',
      currentUserId: 'viewer',
      query: '  @mi  ',
      limit: 2,
    );

    expect(requests, hasLength(2));
    expect(requests.first.url.path, endsWith('/likes'));
    expect(requests.first.url.queryParameters['limit'], '3');
    expect(
      requests.first.url.queryParameters['order'],
      'created_at.desc.nullslast,id.desc.nullslast',
    );
    expect(requests.first.url.query, contains('users.or='));
    expect(requests.last.url.path, endsWith('/follows'));
    expect(requests.last.url.query, contains('following_id=in.'));
    expect(page.items, hasLength(2));
    expect(page.hasMore, isTrue);
    expect(page.nextCursor?.likeId, 'like-2');
    expect(page.items.first.relation, PostLikeRelation.self);
    expect(page.items.last.relation, PostLikeRelation.following);
  });

  test('applies the composite cursor and leaves raw failures hidden', () async {
    http.Request? request;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          '{"message":"database-secret"}',
          500,
          headers: {'content-type': 'application/json'},
          request: incoming,
        );
      }),
    );
    final source = SocialRemoteDataSourceImpl(supabaseClient: client);

    await expectLater(
      source.getPostLikesPage(
        postId: 'post-1',
        currentUserId: 'viewer',
        cursor: PostLikesCursor(
          createdAt: DateTime.utc(2026, 7, 18, 2),
          likeId: 'like-2',
        ),
      ),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'safe message',
          isNot(contains('database-secret')),
        ),
      ),
    );

    expect(request?.url.query, contains('or='));
    expect(request?.url.query, contains('like-2'));
  });
}
