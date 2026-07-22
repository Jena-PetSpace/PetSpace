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

  group('CommunityPost.category (컬럼)', () {
    CommunityPost build(String? category) => CommunityPost.fromJson({
          'id': 'x',
          'author_id': 'u',
          'caption': 'c',
          'category': category,
          'created_at': '2026-06-10T09:00:00.000Z',
        });

    test('category 컬럼 값을 그대로 보존한다', () {
      expect(build('health').category, 'health');
      expect(build('qa').category, 'qa');
    });

    test('category 컬럼이 NULL이면 category는 null', () {
      final post = CommunityPost.fromJson(const {
        'id': 'x',
        'author_id': 'u',
        'caption': 'c',
        'created_at': '2026-06-10T09:00:00.000Z',
      });
      expect(post.category, isNull);
    });
  });

  group('CommunityPost.categoryLabel (category 컬럼 기반)', () {
    CommunityPost build(String? category) => CommunityPost.fromJson({
          'id': 'x',
          'author_id': 'u',
          'caption': 'c',
          'category': category,
          'created_at': '2026-06-10T09:00:00.000Z',
        });

    test('신 체계(라운지 4종) 값을 한글 라벨로 변환한다', () {
      expect(build('chat').categoryLabel, '잡담');
      expect(build('brag').categoryLabel, '자랑');
      expect(build('qa').categoryLabel, '궁금해요'); // 구 'Q&A' → 재편 후 재사용
      expect(build('info').categoryLabel, '정보');
    });

    test('구 체계 값(재편 이전 글)도 호환 표기한다', () {
      expect(build('quiz').categoryLabel, 'O/X 퀴즈');
      expect(build('careguide').categoryLabel, '케어가이드');
      expect(build('education').categoryLabel, '교육');
      expect(build('policy').categoryLabel, '정책');
      expect(build('event').categoryLabel, '이벤트');
      expect(build('health').categoryLabel, '건강');
      expect(build('training').categoryLabel, '훈련');
      expect(build('food').categoryLabel, '먹거리');
      expect(build('life').categoryLabel, '생활');
    });

    test('category가 NULL이거나 미상이면 빈 문자열', () {
      expect(build(null).categoryLabel, '');
      expect(build('알수없음').categoryLabel, '');
    });
  });

  group('CommunityPost 제목·본문 호환 파싱', () {
    CommunityPost build(String caption) => CommunityPost.fromJson({
          'id': 'legacy',
          'author_id': 'u',
          'caption': caption,
          'created_at': '2026-06-10T09:00:00.000Z',
        });

    test('신규 제목과 본문을 빈 줄 기준으로 분리하고 CRLF도 정규화한다', () {
      final post = build('산책 친구를 찾습니다\r\n\r\n주말 오전에 함께 걸어요.\r\n한강에서 만나요.');

      expect(post.title, '산책 친구를 찾습니다');
      expect(post.body, '주말 오전에 함께 걸어요.\n한강에서 만나요.');
    });

    test('구형 단일 caption은 제목으로 보존한다', () {
      final post = build('예전 형식으로 작성한 글');

      expect(post.title, '예전 형식으로 작성한 글');
      expect(post.body, isEmpty);
    });

    test('제목이 비어 있는 legacy caption도 본문을 잃지 않는다', () {
      final post = build('\n\n본문만 남아 있는 글');

      expect(post.title, isEmpty);
      expect(post.body, '본문만 남아 있는 글');
    });
  });
}
