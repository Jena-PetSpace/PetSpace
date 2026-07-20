import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:meong_nyang_diary/features/social/data/datasources/social_remote_data_source.dart';

void main() {
  test('uses only public columns and deterministic composite ordering',
      () async {
    http.Request? request;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode([
            {
              'id': 'u1',
              'display_name': 'Mina',
              'username': 'mina',
              'photo_url': null,
              'bio': 'pet',
              'created_at': '2026-07-19T01:00:00Z',
              'updated_at': '2026-07-19T01:00:00Z',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: incoming,
        );
      }),
    );
    final source = SocialRemoteDataSourceImpl(supabaseClient: client);

    final users = await source.searchUsers('mi', 20, null);

    expect(users.single.id, 'u1');
    expect(request?.url.queryParameters['select'], contains('display_name'));
    expect(request?.url.queryParameters['select'], isNot(contains('email')));
    expect(
      request?.url.queryParameters['order'],
      'created_at.desc.nullslast,id.desc.nullslast',
    );
  });

  test('composite cursor is resolved before the next page query', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: MockClient((incoming) async {
        requests.add(incoming);
        if (incoming.url.query.contains('id=eq.u1')) {
          return http.Response(
            jsonEncode({
              'id': 'u1',
              'display_name': 'Mina',
              'username': 'mina',
              'photo_url': null,
              'bio': null,
              'created_at': '2026-07-19T01:00:00Z',
              'updated_at': '2026-07-19T01:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: incoming,
          );
        }
        return http.Response(
          jsonEncode([
            {
              'id': 'u0',
              'display_name': 'Joon',
              'username': 'joon',
              'photo_url': null,
              'bio': null,
              'created_at': '2026-07-18T01:00:00Z',
              'updated_at': '2026-07-18T01:00:00Z',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: incoming,
        );
      }),
    );
    final source = SocialRemoteDataSourceImpl(supabaseClient: client);

    final users = await source.searchUsers('o', 20, 'u1');

    expect(requests, hasLength(2));
    expect(requests.last.url.queryParametersAll['or'], hasLength(2));
    expect(requests.last.url.query, contains('display_name.ilike.'));
    expect(requests.last.url.query, contains('created_at.lt.'));
    expect(
      requests.last.url.queryParametersAll['or']!.join(' '),
      contains('id.lt."u1"'),
    );
    expect(users.single.id, 'u0');
  });

  test('missing cursor row returns empty without repeating page one', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: MockClient((incoming) async {
        requests.add(incoming);
        return http.Response(
          'null',
          200,
          headers: {'content-type': 'application/json'},
          request: incoming,
        );
      }),
    );
    final source = SocialRemoteDataSourceImpl(supabaseClient: client);

    final users = await source.searchUsers('mi', 20, 'missing-user');

    expect(users, isEmpty);
    expect(requests, hasLength(1));
    expect(requests.single.url.query, contains('id=eq.missing-user'));
  });
}
