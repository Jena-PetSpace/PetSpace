import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/post.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/domain/usecases/save_post.dart';
import 'package:meong_nyang_diary/features/social/domain/usecases/unsave_post.dart';
import 'package:meong_nyang_diary/features/social/domain/usecases/get_saved_posts.dart';

class MockSocialRepository extends Mock implements SocialRepository {}

final _tPost = Post(
  id: 'post-001',
  authorId: 'user-001',
  authorName: '테스트유저',
  type: PostType.emotionAnalysis,
  createdAt: DateTime(2025, 6, 1),
);

void main() {
  late MockSocialRepository repo;

  setUp(() => repo = MockSocialRepository());

  // ── SavePost ──────────────────────────────────────────────────────────────
  group('SavePost', () {
    test('성공 → Right(void)', () async {
      when(() => repo.savePost(any(), any()))
          .thenAnswer((_) async => const Right(null));

      final uc = SavePost(repo);
      final result = await uc(SavePostParams(
        postId: 'post-001',
        userId: 'user-001',
      ));

      expect(result.isRight(), true);
      verify(() => repo.savePost('post-001', 'user-001')).called(1);
    });

    test('네트워크 실패 → Left(NetworkFailure)', () async {
      when(() => repo.savePost(any(), any()))
          .thenAnswer((_) async => const Left(NetworkFailure(message: '연결 오류')));

      final uc = SavePost(repo);
      final result = await uc(SavePostParams(postId: 'p', userId: 'u'));

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('Should fail'),
      );
    });
  });

  // ── UnsavePost ────────────────────────────────────────────────────────────
  group('UnsavePost', () {
    test('성공 → Right(void)', () async {
      when(() => repo.unsavePost(any(), any()))
          .thenAnswer((_) async => const Right(null));

      final uc = UnsavePost(repo);
      final result = await uc(UnsavePostParams(
        postId: 'post-001',
        userId: 'user-001',
      ));

      expect(result.isRight(), true);
      verify(() => repo.unsavePost('post-001', 'user-001')).called(1);
    });

    test('서버 실패 → Left(ServerFailure)', () async {
      when(() => repo.unsavePost(any(), any()))
          .thenAnswer((_) async => const Left(ServerFailure(message: '서버 오류')));

      final uc = UnsavePost(repo);
      final result = await uc(UnsavePostParams(postId: 'p', userId: 'u'));

      expect(result.isLeft(), true);
    });
  });

  // ── GetSavedPosts ─────────────────────────────────────────────────────────
  group('GetSavedPosts', () {
    test('성공 → Right(List<Post>)', () async {
      when(() => repo.getSavedPosts(
        userId: any(named: 'userId'),
        limit: any(named: 'limit'),
      )).thenAnswer((_) async => Right([_tPost]));

      final uc = GetSavedPosts(repo);
      final result = await uc(GetSavedPostsParams(userId: 'user-001'));

      result.fold(
        (f) => fail('Should not fail'),
        (posts) {
          expect(posts.length, 1);
          expect(posts.first.id, 'post-001');
        },
      );
    });

    test('빈 결과 → Right([])', () async {
      when(() => repo.getSavedPosts(
        userId: any(named: 'userId'),
        limit: any(named: 'limit'),
      )).thenAnswer((_) async => const Right([]));

      final uc = GetSavedPosts(repo);
      final result = await uc(GetSavedPostsParams(userId: 'user-001'));

      result.fold((f) => fail('fail'), (list) => expect(list, isEmpty));
    });

    test('limit 파라미터 전달 확인', () async {
      when(() => repo.getSavedPosts(
        userId: any(named: 'userId'),
        limit: any(named: 'limit'),
      )).thenAnswer((_) async => const Right([]));

      final uc = GetSavedPosts(repo);
      await uc(GetSavedPostsParams(userId: 'user-001', limit: 10));

      verify(() => repo.getSavedPosts(userId: 'user-001', limit: 10)).called(1);
    });

    test('실패 → Left', () async {
      when(() => repo.getSavedPosts(
        userId: any(named: 'userId'),
        limit: any(named: 'limit'),
      )).thenAnswer((_) async => const Left(ServerFailure(message: '서버 오류')));

      final uc = GetSavedPosts(repo);
      final result = await uc(GetSavedPostsParams(userId: 'user-001'));

      expect(result.isLeft(), true);
    });
  });
}
