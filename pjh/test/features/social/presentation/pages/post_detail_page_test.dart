import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/core/services/realtime_service.dart';
import 'package:meong_nyang_diary/features/auth/domain/entities/user.dart';
import 'package:meong_nyang_diary/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/bookmark_collection.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/comment.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/post_likes_page.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/saved_posts_page.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/domain/usecases/create_comment.dart';
import 'package:meong_nyang_diary/features/social/domain/usecases/delete_comment.dart';
import 'package:meong_nyang_diary/features/social/domain/usecases/get_comments.dart';
import 'package:meong_nyang_diary/features/social/domain/usecases/update_comment.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/comment_bloc.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/comment_event.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/comment_state.dart';
import 'package:meong_nyang_diary/features/social/presentation/pages/post_detail_page.dart';
import 'package:meong_nyang_diary/features/social/presentation/utils/saved_posts_change_notifier.dart';

class _MockSocialRepository extends Mock implements SocialRepository {}

class _MockCommentBloc extends MockBloc<CommentEvent, CommentState>
    implements CommentBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockRealtimeService extends Mock implements RealtimeService {}

class _FakeComment extends Fake implements Comment {}

Map<String, dynamic> _post({
  int likesCount = 0,
  int commentsCount = 5,
  List<String> imageUrls = const <String>[],
}) {
  return <String, dynamic>{
    'id': 'post-1',
    'author_id': 'author-1',
    'caption': 'A trustworthy post detail',
    'created_at': '2026-07-15T00:00:00Z',
    'likes_count': likesCount,
    'comments_count': commentsCount,
    'image_urls': imageUrls,
    'users': <String, dynamic>{'display_name': 'Mina', 'photo_url': null},
  };
}

User _user() {
  return User(
    uid: 'viewer',
    email: 'private@example.com',
    displayName: 'Viewer',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    pets: const <String>[],
    following: const <String>[],
    followers: const <String>[],
    settings: const UserSettings(
      notificationsEnabled: true,
      privacyLevel: PrivacyLevel.public,
      showEmotionAnalysisToPublic: false,
    ),
  );
}

void main() {
  late _MockSocialRepository repository;
  late _MockAuthBloc authBloc;
  late AuthAuthenticated authState;

  setUpAll(() {
    registerFallbackValue(_FakeComment());
  });

  setUp(() {
    repository = _MockSocialRepository();
    authBloc = _MockAuthBloc();
    authState = AuthAuthenticated(_user());
    when(() => authBloc.state).thenReturn(authState);
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: authState,
    );
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required CommentBloc commentBloc,
    String? currentUserId = 'viewer',
    SavedPostsChangeNotifier? savedPostsNotifier,
    ValueNotifier<bool>? commentMutationNotifier,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: PostDetailPage(
              postId: 'post-1',
              repository: repository,
              commentBloc: commentBloc,
              currentUserId: currentUserId,
              savedPostsNotifier: savedPostsNotifier,
              commentMutationNotifier: commentMutationNotifier,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  _MockCommentBloc mockCommentBloc({int totalCount = 5}) {
    final bloc = _MockCommentBloc();
    final state = CommentLoaded(
      comments: const <Comment>[],
      totalCount: totalCount,
      hasMore: false,
    );
    when(() => bloc.state).thenReturn(state);
    whenListen(bloc, const Stream<CommentState>.empty(), initialState: state);
    return bloc;
  }

  testWidgets('post error retries safely', (tester) async {
    var response = 0;
    when(() => repository.getPostDetail('post-1')).thenAnswer((_) async {
      response++;
      if (response == 1) {
        return const Left(ServerFailure(message: 'repository-secret'));
      }
      return Right(_post());
    });
    when(
      () => repository.isPostLiked('post-1', 'viewer'),
    ).thenAnswer((_) async => const Right(false));
    when(
      () => repository.isPostSaved('post-1', 'viewer'),
    ).thenAnswer((_) async => const Right(false));
    final bloc = mockCommentBloc();

    await pumpPage(tester, commentBloc: bloc);

    expect(find.byKey(const Key('post_detail_error')), findsOneWidget);
    expect(find.textContaining('repository-secret'), findsNothing);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('A trustworthy post detail'), findsOneWidget);
  });

  testWidgets('not-found is distinct from loading and error', (tester) async {
    when(
      () => repository.getPostDetail('post-1'),
    ).thenAnswer((_) async => const Right(null));
    final bloc = mockCommentBloc();

    await pumpPage(tester, commentBloc: bloc);

    expect(find.byKey(const Key('post_detail_not_found')), findsOneWidget);
    expect(find.byKey(const Key('post_detail_error')), findsNothing);
  });

  testWidgets('uses AuthBloc identity when no id is injected', (tester) async {
    when(
      () => repository.getPostDetail('post-1'),
    ).thenAnswer((_) async => Right(_post()));
    when(
      () => repository.isPostLiked('post-1', 'viewer'),
    ).thenAnswer((_) async => const Right(false));
    when(
      () => repository.isPostSaved('post-1', 'viewer'),
    ).thenAnswer((_) async => const Right(false));
    final bloc = mockCommentBloc();

    await pumpPage(tester, commentBloc: bloc, currentUserId: null);

    verify(() => repository.isPostLiked('post-1', 'viewer')).called(1);
    verify(() => repository.isPostSaved('post-1', 'viewer')).called(1);
  });

  testWidgets('comment action moves focus to the canonical composer', (
    tester,
  ) async {
    when(
      () => repository.getPostDetail('post-1'),
    ).thenAnswer((_) async => Right(_post()));
    when(
      () => repository.isPostLiked('post-1', 'viewer'),
    ).thenAnswer((_) async => const Right(false));
    when(
      () => repository.isPostSaved('post-1', 'viewer'),
    ).thenAnswer((_) async => const Right(false));
    final bloc = mockCommentBloc();

    await pumpPage(tester, commentBloc: bloc);
    await tester.tap(find.byKey(const Key('post_detail_comment_action')));
    await tester.pump();

    final input = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('post_comment_input')),
        matching: find.byType(EditableText),
      ),
    );
    expect(input.focusNode.hasFocus, isTrue);
  });

  testWidgets('post report shows success only after repository success', (
    tester,
  ) async {
    when(
      () => repository.getPostDetail('post-1'),
    ).thenAnswer((_) async => Right(_post()));
    when(
      () => repository.isPostLiked('post-1', 'viewer'),
    ).thenAnswer((_) async => const Right(false));
    when(
      () => repository.isPostSaved('post-1', 'viewer'),
    ).thenAnswer((_) async => const Right(false));
    when(
      () => repository.reportPost(
        'post-1',
        'viewer',
        '스팸 또는 광고',
      ),
    ).thenAnswer((_) async => const Right(null));
    final bloc = mockCommentBloc();

    await pumpPage(tester, commentBloc: bloc);
    await tester.tap(find.byKey(const Key('post_detail_options')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('신고'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('social_report_reason_스팸 또는 광고')),
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('social_report_submit')));
    await tester.tap(find.byKey(const Key('social_report_submit')));
    await tester.pumpAndSettle();

    verify(
      () => repository.reportPost(
        'post-1',
        'viewer',
        '스팸 또는 광고',
      ),
    ).called(1);
    expect(find.text('신고가 접수되었습니다.'), findsOneWidget);
  });

  testWidgets('uses one total count and serializes rapid post-like taps', (
    tester,
  ) async {
    var detailCalls = 0;
    var likedCalls = 0;
    when(() => repository.getPostDetail('post-1')).thenAnswer((_) async {
      detailCalls++;
      return Right(
        _post(likesCount: detailCalls == 1 ? 0 : 1, commentsCount: 99),
      );
    });
    when(() => repository.isPostLiked('post-1', 'viewer')).thenAnswer((
      _,
    ) async {
      likedCalls++;
      return Right(likedCalls > 1);
    });
    when(
      () => repository.isPostSaved('post-1', 'viewer'),
    ).thenAnswer((_) async => const Right(false));
    final likeCompleter = Completer<Either<Failure, void>>();
    when(
      () => repository.likePost('post-1', 'viewer'),
    ).thenAnswer((_) => likeCompleter.future);
    final bloc = mockCommentBloc(totalCount: 5);

    await pumpPage(tester, commentBloc: bloc);

    expect(find.text('댓글 5개'), findsOneWidget);
    expect(find.text('99'), findsNothing);
    final like = find.byKey(const Key('post_detail_like_button'));
    await tester.tap(like);
    await tester.pump();
    await tester.tap(like, warnIfMissed: false);
    await tester.pump();
    verify(() => repository.likePost('post-1', 'viewer')).called(1);
    expect(find.text('1'), findsOneWidget);

    likeCompleter.complete(const Right(null));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('zero like count opens a distinct likes list', (tester) async {
    when(
      () => repository.getPostDetail('post-1'),
    ).thenAnswer((_) async => Right(_post()));
    when(
      () => repository.isPostLiked('post-1', 'viewer'),
    ).thenAnswer((_) async => const Right(false));
    when(
      () => repository.isPostSaved('post-1', 'viewer'),
    ).thenAnswer((_) async => const Right(false));
    when(
      () => repository.getPostLikesPage(
        postId: 'post-1',
        currentUserId: 'viewer',
        cursor: null,
        query: '',
        limit: 20,
      ),
    ).thenAnswer(
      (_) async => const Right(PostLikesPage(items: [], hasMore: false)),
    );
    final bloc = mockCommentBloc();

    await pumpPage(tester, commentBloc: bloc);
    await tester.tap(find.byKey(const Key('post_detail_likes_count')));
    await tester.pumpAndSettle();

    expect(find.text('좋아요 0'), findsOneWidget);
    expect(find.byKey(const Key('likes_empty')), findsOneWidget);
  });

  testWidgets('double tapping an already-liked image never unlikes it',
      (tester) async {
    when(
      () => repository.getPostDetail('post-1'),
    ).thenAnswer(
      (_) async => Right(
        _post(
          likesCount: 1,
          imageUrls: const ['https://example.com/pet.jpg'],
        ),
      ),
    );
    when(
      () => repository.isPostLiked('post-1', 'viewer'),
    ).thenAnswer((_) async => const Right(true));
    when(
      () => repository.isPostSaved('post-1', 'viewer'),
    ).thenAnswer((_) async => const Right(false));
    final bloc = mockCommentBloc();

    await pumpPage(tester, commentBloc: bloc);
    final media = find.byKey(const Key('post_detail_media_0'));
    await tester.tap(media);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(media);
    await tester.pump();

    verifyNever(() => repository.likePost(any(), any()));
    verifyNever(() => repository.unlikePost(any(), any()));
    expect(
      find.byKey(const Key('post_detail_double_tap_heart')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 850));
  });

  testWidgets('comment create failure preserves text and hides raw error', (
    tester,
  ) async {
    when(
      () => repository.getPostDetail('post-1'),
    ).thenAnswer((_) async => Right(_post(commentsCount: 0)));
    when(
      () => repository.isPostLiked('post-1', 'viewer'),
    ).thenAnswer((_) async => const Right(false));
    when(
      () => repository.isPostSaved('post-1', 'viewer'),
    ).thenAnswer((_) async => const Right(false));
    when(
      () => repository.getPostComments(
        postId: 'post-1',
        limit: 20,
        lastCommentId: null,
      ),
    ).thenAnswer((_) async => const Right(<Comment>[]));
    when(() => repository.createComment(any())).thenAnswer(
      (_) async => const Left(ServerFailure(message: 'create-secret')),
    );
    final bloc = CommentBloc(
      getComments: GetComments(repository),
      createComment: CreateComment(repository),
      deleteComment: DeleteComment(repository),
      updateComment: UpdateComment(repository),
      currentUserId: 'viewer',
      socialRepository: repository,
      realtimeService: _MockRealtimeService(),
      enableRealtime: false,
    );
    addTearDown(bloc.close);
    final loaded = bloc.stream
        .where((state) => state is CommentLoaded)
        .cast<CommentLoaded>()
        .first;
    bloc.add(const LoadComments(postId: 'post-1'));
    await loaded;

    await pumpPage(tester, commentBloc: bloc);
    await tester.enterText(
      find.byKey(const Key('post_comment_input')),
      'retry me',
    );
    await tester.tap(find.byKey(const Key('post_comment_send')));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const Key('post_comment_input')),
    );
    expect(field.controller?.text, 'retry me');
    expect(find.textContaining('create-secret'), findsNothing);
  });

  testWidgets('serializes save and publishes only after server success', (
    tester,
  ) async {
    when(
      () => repository.getPostDetail('post-1'),
    ).thenAnswer((_) async => Right(_post()));
    when(
      () => repository.isPostLiked('post-1', 'viewer'),
    ).thenAnswer((_) async => const Right(false));
    when(
      () => repository.isPostSaved('post-1', 'viewer'),
    ).thenAnswer((_) async => const Right(false));
    final saveCompleter = Completer<Either<Failure, void>>();
    when(
      () => repository.savePost('post-1', 'viewer'),
    ).thenAnswer((_) => saveCompleter.future);
    when(
      () => repository.getBookmarkCollections('viewer'),
    ).thenAnswer((_) async => const Right(<BookmarkCollection>[]));
    when(
      () => repository.getSavedPostLocation(postId: 'post-1', userId: 'viewer'),
    ).thenAnswer(
      (_) async => const Right(SavedPostLocation(savedPostId: 'saved-1')),
    );
    final notifier = SavedPostsChangeNotifier.forTest();
    final bloc = mockCommentBloc();

    await pumpPage(tester, commentBloc: bloc, savedPostsNotifier: notifier);

    final saveButton = find.byKey(const Key('post_detail_save_button'));
    await tester.tap(saveButton);
    await tester.pump();
    await tester.tap(saveButton, warnIfMissed: false);
    await tester.pump();

    verify(() => repository.savePost('post-1', 'viewer')).called(1);
    expect(notifier.revision, 0);

    saveCompleter.complete(const Right(null));
    await tester.pumpAndSettle();

    expect(notifier.revision, 1);
    expect(notifier.lastChange?.type, SavedPostsChangeType.saved);
    expect(find.text('게시물을 저장했어요'), findsOneWidget);
    expect(
      find.byKey(const Key('post_detail_collection_button')),
      findsOneWidget,
    );

    await tester.tap(find.text('컬렉션 선택'));
    await tester.pumpAndSettle();
    expect(find.text('저장 위치 선택'), findsOneWidget);
  });

  testWidgets('failed unsave restores only prior saved state', (tester) async {
    when(
      () => repository.getPostDetail('post-1'),
    ).thenAnswer((_) async => Right(_post()));
    when(
      () => repository.isPostLiked('post-1', 'viewer'),
    ).thenAnswer((_) async => const Right(false));
    when(
      () => repository.isPostSaved('post-1', 'viewer'),
    ).thenAnswer((_) async => const Right(true));
    when(
      () => repository.getSavedPostLocation(postId: 'post-1', userId: 'viewer'),
    ).thenAnswer(
      (_) async => const Right(
        SavedPostLocation(savedPostId: 'saved-1', collectionId: 'walks'),
      ),
    );
    when(() => repository.unsavePost('post-1', 'viewer')).thenAnswer(
      (_) async => const Left(ServerFailure(message: 'unsave-secret')),
    );
    final notifier = SavedPostsChangeNotifier.forTest();
    final bloc = mockCommentBloc();

    await pumpPage(tester, commentBloc: bloc, savedPostsNotifier: notifier);
    await tester.tap(find.byKey(const Key('post_detail_save_button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('post_detail_collection_button')),
      findsOneWidget,
    );
    expect(find.textContaining('unsave-secret'), findsNothing);
    expect(notifier.revision, 0);
  });

  testWidgets('publishes successful comment count mutations to its owner', (
    tester,
  ) async {
    when(
      () => repository.getPostDetail('post-1'),
    ).thenAnswer((_) async => Right(_post()));
    when(
      () => repository.isPostLiked('post-1', 'viewer'),
    ).thenAnswer((_) async => const Right(false));
    when(
      () => repository.isPostSaved('post-1', 'viewer'),
    ).thenAnswer((_) async => const Right(false));
    final controller = StreamController<CommentState>.broadcast();
    addTearDown(controller.close);
    final bloc = _MockCommentBloc();
    const initial = CommentLoaded(
      comments: [],
      totalCount: 0,
      hasMore: false,
    );
    whenListen(bloc, controller.stream, initialState: initial);
    final notifier = ValueNotifier<bool>(false);
    addTearDown(notifier.dispose);

    await pumpPage(
      tester,
      commentBloc: bloc,
      commentMutationNotifier: notifier,
    );
    controller.add(
      const CommentLoaded(
        comments: [],
        totalCount: 1,
        hasMore: false,
        actionOutcome: CommentActionOutcome(
          id: 1,
          kind: CommentActionKind.commentCreated,
          succeeded: true,
        ),
      ),
    );
    await tester.pump();

    expect(notifier.value, isTrue);
  });
}
