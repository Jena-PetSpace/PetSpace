import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/core/services/push_notification_service.dart';
import 'package:meong_nyang_diary/core/services/realtime_service.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/comment.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/domain/usecases/create_comment.dart';
import 'package:meong_nyang_diary/features/social/domain/usecases/delete_comment.dart';
import 'package:meong_nyang_diary/features/social/domain/usecases/get_comments.dart';
import 'package:meong_nyang_diary/features/social/domain/usecases/update_comment.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/comment_bloc.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/comment_event.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/comment_state.dart';

class _MockSocialRepository extends Mock implements SocialRepository {}

class _MockPushNotificationService extends Mock
    implements PushNotificationService {}

class _MockRealtimeService extends Mock implements RealtimeService {}

Comment _comment(
  String id, {
  String? parentId,
  int likesCount = 0,
  bool liked = false,
  List<Comment> replies = const <Comment>[],
}) {
  return Comment(
    id: id,
    postId: 'post-1',
    authorId: 'author-$id',
    authorName: 'Author $id',
    content: 'content $id',
    createdAt: DateTime(2026, 7, 15),
    parentId: parentId,
    likesCount: likesCount,
    isLikedByCurrentUser: liked,
    replies: replies,
  );
}

void main() {
  late _MockSocialRepository repository;
  late _MockPushNotificationService pushService;
  late _MockRealtimeService realtimeService;
  late CommentBloc bloc;
  late List<Comment> initialComments;
  var serverTotal = 0;

  setUpAll(() {
    registerFallbackValue(_comment('fallback'));
  });

  setUp(() {
    repository = _MockSocialRepository();
    pushService = _MockPushNotificationService();
    realtimeService = _MockRealtimeService();
    initialComments = <Comment>[];
    serverTotal = 0;
    when(
      () => repository.getPostComments(
        postId: any(named: 'postId'),
        limit: any(named: 'limit'),
        lastCommentId: any(named: 'lastCommentId'),
      ),
    ).thenAnswer((_) async => Right(initialComments));
    when(() => repository.getPostDetail(any())).thenAnswer(
      (_) async => Right(<String, dynamic>{'comments_count': serverTotal}),
    );
    bloc = CommentBloc(
      getComments: GetComments(repository),
      createComment: CreateComment(repository),
      deleteComment: DeleteComment(repository),
      updateComment: UpdateComment(repository),
      currentUserId: 'viewer',
      socialRepository: repository,
      pushNotificationService: pushService,
      realtimeService: realtimeService,
      enableRealtime: false,
    );
  });

  tearDown(() => bloc.close());

  Future<CommentLoaded> load() async {
    final loaded = bloc.stream
        .where((state) => state is CommentLoaded)
        .cast<CommentLoaded>()
        .first;
    bloc.add(const LoadComments(postId: 'post-1'));
    return loaded;
  }

  Future<CommentLoaded> nextOutcome(CommentActionKind kind) {
    return bloc.stream
        .where(
          (state) =>
              state is CommentLoaded && state.actionOutcome?.kind == kind,
        )
        .cast<CommentLoaded>()
        .first;
  }

  test('initial load uses server total and exact page-size hasMore', () async {
    initialComments = List<Comment>.generate(
      20,
      (index) => _comment('c$index'),
    );
    serverTotal = 37;

    final state = await load();

    expect(state.comments, hasLength(20));
    expect(state.totalCount, 37);
    expect(state.hasMore, isTrue);
  });

  test('load-more failure keeps loaded threads and total count', () async {
    initialComments = List<Comment>.generate(
      20,
      (index) => _comment('c$index'),
    );
    serverTotal = 24;
    when(
      () => repository.getPostComments(
        postId: 'post-1',
        limit: 20,
        lastCommentId: 'c19',
      ),
    ).thenAnswer(
      (_) async => const Left(ServerFailure(message: 'internal-secret')),
    );
    await load();
    final failed = bloc.stream
        .where((state) => state is CommentLoaded && state.error != null)
        .cast<CommentLoaded>()
        .first;

    bloc.add(const LoadMoreComments(postId: 'post-1'));
    final state = await failed;

    expect(state.comments, hasLength(20));
    expect(state.totalCount, 24);
    expect(state.isLoadingMore, isFalse);
    expect(state.error, isNot(contains('internal-secret')));
  });

  test(
    'comment create failure changes no total and exposes safe outcome',
    () async {
      initialComments = [_comment('parent')];
      serverTotal = 1;
      when(() => repository.createComment(any())).thenAnswer(
        (_) async => const Left(ServerFailure(message: 'repository-secret')),
      );
      await load();
      final outcome = nextOutcome(CommentActionKind.commentCreated);

      bloc.add(
        const CreateCommentRequested(postId: 'post-1', content: 'retry me'),
      );
      final state = await outcome;

      expect(state.comments, hasLength(1));
      expect(state.totalCount, 1);
      expect(state.isSubmitting, isFalse);
      expect(state.actionOutcome?.succeeded, isFalse);
      expect(
        state.actionOutcome?.message,
        isNot(contains('repository-secret')),
      );
    },
  );

  test('reply create updates nested list and increments total', () async {
    initialComments = [_comment('parent')];
    serverTotal = 1;
    final reply = _comment('reply', parentId: 'parent');
    when(
      () => repository.createComment(any()),
    ).thenAnswer((_) async => Right(reply));
    await load();
    serverTotal = 2;
    final outcome = nextOutcome(CommentActionKind.replyCreated);

    bloc.add(
      const CreateReplyRequested(
        postId: 'post-1',
        parentId: 'parent',
        content: 'reply',
      ),
    );
    final state = await outcome;

    expect(state.comments.single.replies.single.id, 'reply');
    expect(state.totalCount, 2);
    expect(state.hasMore, isFalse);
  });

  test(
    'parent delete removes its replies and decrements canonical total',
    () async {
      final parent = _comment(
        'parent',
        replies: [
          _comment('r1', parentId: 'parent'),
          _comment('r2', parentId: 'parent'),
        ],
      );
      initialComments = [parent, _comment('other')];
      serverTotal = 4;
      when(
        () => repository.deleteComment('parent'),
      ).thenAnswer((_) async => const Right(null));
      await load();
      serverTotal = 1;
      final outcome = nextOutcome(CommentActionKind.commentDeleted);

      bloc.add(const DeleteCommentRequested(commentId: 'parent'));
      final state = await outcome;

      expect(state.comments.map((comment) => comment.id), ['other']);
      expect(state.totalCount, 1);
      expect(state.pendingDeleteIds, isEmpty);
    },
  );

  test('reply like failure rolls back only that nested target', () async {
    final reply = _comment('reply', parentId: 'parent');
    initialComments = [
      _comment('parent', replies: [reply]),
      _comment('other', likesCount: 4, liked: true),
    ];
    serverTotal = 3;
    when(() => repository.likeComment('reply', 'viewer')).thenAnswer(
      (_) async => const Left(ServerFailure(message: 'like-secret')),
    );
    await load();
    final outcome = nextOutcome(CommentActionKind.likeFailed);

    bloc.add(
      const LikeCommentRequested(commentId: 'reply', isCurrentlyLiked: false),
    );
    final state = await outcome;

    final rolledBack = state.comments.first.replies.single;
    expect(rolledBack.isLikedByCurrentUser, isFalse);
    expect(rolledBack.likesCount, 0);
    expect(state.comments.last.isLikedByCurrentUser, isTrue);
    expect(state.comments.last.likesCount, 4);
    expect(state.pendingLikeIds, isEmpty);
  });
}
