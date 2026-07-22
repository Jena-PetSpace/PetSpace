import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/bookmark_collection.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/saved_posts_page.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/bookmark_bloc.dart';

class _MockRepository extends Mock implements SocialRepository {}

void main() {
  late _MockRepository repository;
  final now = DateTime(2026, 7, 15);
  late BookmarkCollection collection;

  setUp(() {
    repository = _MockRepository();
    collection = BookmarkCollection(
      id: 'c1',
      userId: 'u1',
      name: '산책',
      createdAt: now,
      updatedAt: now,
    );
  });

  blocTest<BookmarkBloc, BookmarkState>(
    '컬렉션과 두 카운트를 독립 상태로 적재한다',
    build: () {
      when(() => repository.getBookmarkCollections('u1'))
          .thenAnswer((_) async => Right([collection]));
      when(() => repository.countSavedPosts(
            userId: 'u1',
            scope: const SavedPostsScope.all(),
          )).thenAnswer((_) async => const Right(8));
      when(() => repository.countSavedPosts(
                userId: 'u1',
                scope: const SavedPostsScope.unassigned(),
              ))
          .thenAnswer(
              (_) async => const Left(ServerFailure(message: 'count-failed')));
      return BookmarkBloc(repository: repository);
    },
    act: (bloc) => bloc.add(const LoadBookmarkCollections(userId: 'u1')),
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      expect(bloc.state.collections, [collection]);
      expect(bloc.state.allCount, 8);
      expect(bloc.state.collectionsStatus, BookmarkLoadStatus.success);
      expect(bloc.state.unassignedCountStatus, BookmarkLoadStatus.failure);
    },
  );

  blocTest<BookmarkBloc, BookmarkState>(
    '삭제는 collection id와 user id를 함께 전달하고 목록을 보존 갱신한다',
    build: () {
      when(() => repository.deleteBookmarkCollection(
            collectionId: 'c1',
            userId: 'u1',
          )).thenAnswer((_) async => const Right(null));
      when(() => repository.countSavedPosts(
            userId: 'u1',
            scope: const SavedPostsScope.all(),
          )).thenAnswer((_) async => const Right(8));
      when(() => repository.countSavedPosts(
            userId: 'u1',
            scope: const SavedPostsScope.unassigned(),
          )).thenAnswer((_) async => const Right(3));
      return BookmarkBloc(repository: repository);
    },
    seed: () => BookmarkState(
      collectionsStatus: BookmarkLoadStatus.success,
      collections: [collection],
    ),
    act: (bloc) => bloc.add(const DeleteBookmarkCollection(
      collectionId: 'c1',
      userId: 'u1',
    )),
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      expect(bloc.state.collections, isEmpty);
      expect(bloc.state.unassignedCount, 3);
    },
  );
}
