import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/features/feed_hub/domain/entities/community_post.dart';

void main() {
  group('CommunityPost.fromJson', () {
    test('전체 필드가 채워진 정상 Map을 매핑한다', () {
      final json = {
        'id': 'post-001',
        'author_id': 'user-001',
        'caption': '강아지 사료 추천해주세요',
        'hashtags': ['community', 'food'],
        'likes_count': 5,
        'comments_count': 3,
        'created_at': '2026-06-10T09:00:00.000Z',
        'users': {
          'display_name': '집사1',
          'photo_url': 'https://example.com/p.jpg',
        },
      };

      final post = CommunityPost.fromJson(json);

      expect(post.id, 'post-001');
      expect(post.authorId, 'user-001');
      expect(post.authorName, '집사1');
      expect(post.authorPhotoUrl, 'https://example.com/p.jpg');
      expect(post.content, '강아지 사료 추천해주세요');
      expect(post.hashtags, ['community', 'food']);
      expect(post.likes, 5);
      expect(post.comments, 3);
      expect(post.createdAt, DateTime.parse('2026-06-10T09:00:00.000Z'));
    });

    test('users join이 null이면 authorName은 익명 폴백', () {
      final json = {
        'id': 'post-002',
        'author_id': 'user-002',
        'caption': '본문',
        'hashtags': <String>[],
        'created_at': '2026-06-10T09:00:00.000Z',
        'users': null,
      };

      final post = CommunityPost.fromJson(json);

      expect(post.authorName, '익명');
      expect(post.authorPhotoUrl, isNull);
    });

    test('likes_count / comments_count 누락 시 0으로 폴백', () {
      final json = {
        'id': 'post-003',
        'author_id': 'user-003',
        'caption': '본문',
        'hashtags': <String>[],
        'created_at': '2026-06-10T09:00:00.000Z',
      };

      final post = CommunityPost.fromJson(json);

      expect(post.likes, 0);
      expect(post.comments, 0);
    });

    test('caption 누락 시 빈 문자열로 폴백', () {
      final json = {
        'id': 'post-004',
        'author_id': 'user-004',
        'hashtags': <String>[],
        'created_at': '2026-06-10T09:00:00.000Z',
      };

      final post = CommunityPost.fromJson(json);

      expect(post.content, '');
    });

    test('hashtags 누락 시 빈 리스트로 폴백', () {
      final json = {
        'id': 'post-005',
        'author_id': 'user-005',
        'caption': '본문',
        'created_at': '2026-06-10T09:00:00.000Z',
      };

      final post = CommunityPost.fromJson(json);

      expect(post.hashtags, isEmpty);
    });
  });

  group('CommunityPost.categoryLabel', () {
    test('hashtags에서 카테고리 한글 라벨을 도출한다', () {
      CommunityPost build(List<String> tags) => CommunityPost.fromJson({
            'id': 'x',
            'author_id': 'u',
            'caption': 'c',
            'hashtags': tags,
            'created_at': '2026-06-10T09:00:00.000Z',
          });

      expect(build(['qa']).categoryLabel, 'Q&A');
      expect(build(['health']).categoryLabel, '건강');
      expect(build(['training']).categoryLabel, '훈련');
      expect(build(['food']).categoryLabel, '먹거리');
      expect(build(['life']).categoryLabel, '생활');
      expect(build(['magazine']).categoryLabel, '매거진');
    });

    test('알려진 카테고리 태그가 없으면 빈 문자열', () {
      final post = CommunityPost.fromJson(const {
        'id': 'x',
        'author_id': 'u',
        'caption': 'c',
        'hashtags': ['community', '랜덤태그'],
        'created_at': '2026-06-10T09:00:00.000Z',
      });

      expect(post.categoryLabel, '');
    });
  });
}
