import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_config.dart';
import 'secrets.dart';

// Core
import '../core/network/network_info.dart';

// Features - Auth
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/domain/usecases/sign_in_with_apple.dart';
import '../features/auth/domain/usecases/sign_in_with_google.dart';
import '../features/auth/domain/usecases/sign_in_with_kakao.dart';
import '../features/auth/domain/usecases/sign_out.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';

// Features - Emotion
import '../features/emotion/data/repositories/emotion_repository_impl.dart';
import '../features/emotion/domain/repositories/emotion_repository.dart';
import '../features/emotion/domain/usecases/analyze_emotion.dart';
import '../features/emotion/domain/usecases/save_emotion_analysis.dart';
import '../features/emotion/domain/usecases/get_emotion_history.dart';
import '../features/emotion/domain/usecases/get_emotion_statistics.dart';
import '../features/emotion/domain/usecases/delete_emotion_analysis.dart';
import '../features/emotion/domain/usecases/get_previous_analysis.dart';
import '../features/emotion/data/datasources/emotion_ai_service.dart';
import '../features/emotion/data/datasources/image_service.dart';
import '../features/emotion/presentation/bloc/emotion_analysis_bloc.dart';

// Features - Social
import '../features/social/data/repositories/social_repository_impl.dart';
import '../features/social/data/datasources/social_remote_data_source.dart';
import '../features/social/domain/repositories/social_repository.dart';
import '../features/social/domain/usecases/get_user_profile.dart';
import '../features/social/domain/usecases/follow_user.dart';
import '../features/social/domain/usecases/unfollow_user.dart';
import '../features/social/domain/usecases/get_feed.dart';
import '../features/social/domain/usecases/create_post.dart';
import '../features/social/domain/usecases/update_post.dart';
import '../features/social/domain/usecases/delete_post.dart';
import '../features/social/domain/usecases/like_post.dart';
import '../features/social/domain/usecases/unlike_post.dart';
import '../features/social/domain/usecases/save_post.dart';
import '../features/social/domain/usecases/unsave_post.dart';
import '../features/social/domain/usecases/get_saved_posts.dart';
import '../features/social/domain/usecases/get_comments.dart';
import '../features/social/domain/usecases/create_comment.dart';
import '../features/social/domain/usecases/delete_comment.dart';
import '../features/social/domain/usecases/update_comment.dart';
import '../features/social/presentation/bloc/social_bloc.dart';
import '../features/social/presentation/bloc/notifications_bloc.dart';
import '../features/social/presentation/bloc/profile_bloc.dart';
import '../features/social/presentation/bloc/feed_bloc.dart';
import '../features/social/presentation/bloc/search_bloc.dart';
import '../features/social/presentation/bloc/notification_badge/notification_badge_bloc.dart';
import '../features/social/presentation/bloc/bookmark_bloc.dart';

// Features - Pets
import '../features/pets/data/repositories/pet_repository_impl.dart';
import '../features/pets/domain/repositories/pet_repository.dart';
import '../features/pets/domain/usecases/get_user_pets.dart';
import '../features/pets/domain/usecases/add_pet.dart';
import '../features/pets/domain/usecases/update_pet.dart';
import '../features/pets/domain/usecases/delete_pet.dart';
import '../features/pets/presentation/bloc/pet_bloc.dart';

// Features - Health
import '../features/health/data/repositories/health_repository_impl.dart';
import '../features/health/domain/repositories/health_repository.dart';
import '../features/health/domain/usecases/get_health_records.dart';
import '../features/health/domain/usecases/add_health_record.dart';
import '../features/health/domain/usecases/update_health_record.dart';
import '../features/health/domain/usecases/delete_health_record.dart';
import '../features/health/domain/usecases/get_upcoming_records.dart';
import '../features/health/presentation/bloc/health_bloc.dart';

// Features - Chat
import '../features/chat/data/datasources/chat_remote_data_source.dart';
import '../features/chat/data/repositories/chat_repository_impl.dart';
import '../features/chat/domain/repositories/chat_repository.dart';
import '../features/chat/domain/usecases/get_chat_rooms.dart';
import '../features/chat/domain/usecases/get_chat_messages.dart';
import '../features/chat/domain/usecases/send_message.dart';
import '../features/chat/domain/usecases/send_image_message.dart';
import '../features/chat/domain/usecases/create_chat_room.dart';
import '../features/chat/domain/usecases/update_last_read.dart';
import '../features/chat/domain/usecases/get_unread_count.dart';
import '../features/chat/domain/usecases/search_users_for_chat.dart';
import '../features/chat/domain/usecases/leave_chat_room.dart';
import '../features/chat/domain/usecases/add_chat_members.dart';
import '../features/chat/presentation/bloc/chat_badge/chat_badge_bloc.dart';
import '../features/chat/presentation/bloc/chat_rooms/chat_rooms_bloc.dart';
import '../features/chat/presentation/bloc/chat_detail/chat_detail_bloc.dart';

// Features - MBTI (반려동물 성격 유형 검사)
import '../features/mbti/data/datasources/mbti_content_data_source.dart';
import '../features/mbti/data/datasources/mbti_draft_local_data_source.dart';
import '../features/mbti/data/repositories/mbti_repository_impl.dart';
import '../features/mbti/domain/repositories/mbti_repository.dart';
import '../features/mbti/domain/services/mbti_scorer.dart';
import '../features/mbti/domain/usecases/save_mbti_result.dart';
import '../features/mbti/domain/usecases/get_latest_mbti_result.dart';
import '../features/mbti/domain/usecases/get_mbti_history.dart';
import '../features/mbti/presentation/bloc/mbti_test_bloc.dart';

// Features - Fortune (반려동물 운세)
import '../features/fortune/data/datasources/fortune_content_data_source.dart';
import '../features/fortune/data/datasources/fortune_seen_local_data_source.dart';
import '../features/fortune/domain/services/fortune_generator.dart';

// Features - Quiz (O/X 퀴즈)
import '../features/quiz/data/datasources/quiz_content_data_source.dart';
import '../features/quiz/data/datasources/quiz_local_data_source.dart';
import '../features/quiz/domain/services/quiz_session_builder.dart';
import '../features/quiz/domain/services/quiz_reward_hook.dart';

// Features - News (반려동물 펫 뉴스 — Supabase published 조회)
import '../features/news/data/datasources/news_remote_data_source.dart';
import '../features/news/data/repositories/news_repository_impl.dart';
import '../features/news/domain/repositories/news_repository.dart';
import '../features/news/domain/usecases/get_published_news.dart';
import '../features/news/presentation/bloc/news_bloc.dart';

// Core Services
import '../core/services/image_upload_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/push_notification_service.dart';
import '../core/services/realtime_service.dart';
import '../core/services/profile_service.dart';
import '../core/services/block_service.dart';
import '../core/services/fcm_service.dart';
import '../core/services/local_notification_service.dart';

final sl = GetIt.instance;

Future<void> init() async {
  //! External & Core (먼저 초기화)
  await _initExternal();
  await _initCore();

  //! Features
  await _initAuth();
  await _initEmotion();
  await _initSocial();
  await _initPets();
  await _initHealth();
  await _initChat();
  await _initMbti();
  await _initFortune();
  await _initQuiz();
  await _initNews();
}

Future<void> _initAuth() async {
  // Auth feature dependencies

  // Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      supabaseClient: sl(),
      googleSignIn: sl(),
      networkInfo: sl(),
    ),
  );

  // Use Cases
  sl.registerLazySingleton(() => SignInWithGoogle(sl()));
  sl.registerLazySingleton(() => SignInWithKakao(sl()));
  sl.registerLazySingleton(() => SignInWithApple(sl()));
  sl.registerLazySingleton(() => SignOut(sl()));

  // BLoC
  sl.registerLazySingleton(
    () => AuthBloc(
      authRepository: sl(),
      signInWithGoogle: sl(),
      signInWithKakao: sl(),
      signInWithApple: sl(),
      signOut: sl(),
    ),
  );
}

Future<void> _initEmotion() async {
  // Emotion feature dependencies

  // Services - 인터페이스로 등록
  sl.registerLazySingleton<EmotionAIService>(
    () => EmotionAIServiceImpl(),
  );

  sl.registerLazySingleton<ImageService>(
    () => ImageServiceImpl(),
  );

  // Repository
  sl.registerLazySingleton<EmotionRepository>(
    () => EmotionRepositoryImpl(
      supabaseClient: sl(),
      aiService: sl(),
      imageService: sl(),
      networkInfo: sl(),
    ),
  );

  // Use Cases
  sl.registerLazySingleton(() => AnalyzeEmotion(sl()));
  sl.registerLazySingleton(() => SaveEmotionAnalysis(sl()));
  sl.registerLazySingleton(() => GetEmotionHistory(sl()));
  sl.registerLazySingleton(() => GetEmotionStatistics(sl()));
  sl.registerLazySingleton(() => DeleteEmotionAnalysis(sl()));
  sl.registerLazySingleton(() => GetPreviousAnalysis(sl()));

  // BLoC - factory로 등록: 페이지마다 새 인스턴스 생성 (singleton 재사용 시 closed 오류 방지)
  sl.registerFactory(
    () => EmotionAnalysisBloc(
      analyzeEmotion: sl(),
      saveEmotionAnalysis: sl(),
      getEmotionHistory: sl(),
      getEmotionStatistics: sl(),
      deleteEmotionAnalysis: sl(),
    ),
  );
}

Future<void> _initSocial() async {
  // Social feature dependencies

  // Data Sources
  sl.registerLazySingleton<SocialRemoteDataSource>(
    () => SocialRemoteDataSourceImpl(
      supabaseClient: sl<SupabaseClient>(),
    ),
  );

  // Repository
  sl.registerLazySingleton<SocialRepository>(
    () => SocialRepositoryImpl(
      remoteDataSource: sl<SocialRemoteDataSource>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );

  // Use Cases
  sl.registerLazySingleton(() => GetUserProfile(sl<SocialRepository>()));
  sl.registerLazySingleton(() => FollowUser(sl<SocialRepository>()));
  sl.registerLazySingleton(() => UnfollowUser(sl<SocialRepository>()));
  sl.registerLazySingleton(() => GetFeed(sl<SocialRepository>()));
  sl.registerLazySingleton(() => CreatePost(sl<SocialRepository>()));
  sl.registerLazySingleton(() => UpdatePost(sl<SocialRepository>()));
  sl.registerLazySingleton(() => DeletePost(sl<SocialRepository>()));
  sl.registerLazySingleton(() => LikePost(sl<SocialRepository>()));
  sl.registerLazySingleton(() => UnlikePost(sl<SocialRepository>()));
  sl.registerLazySingleton(() => SavePost(sl<SocialRepository>()));
  sl.registerLazySingleton(() => UnsavePost(sl<SocialRepository>()));
  sl.registerLazySingleton(() => GetSavedPosts(sl<SocialRepository>()));
  sl.registerLazySingleton(() => GetComments(sl<SocialRepository>()));
  sl.registerLazySingleton(() => CreateComment(sl<SocialRepository>()));
  sl.registerLazySingleton(() => DeleteComment(sl<SocialRepository>()));
  sl.registerLazySingleton(() => UpdateComment(sl<SocialRepository>()));

  // BLoCs
  sl.registerFactory(
    () => SocialBloc(
      socialRepository: sl<SocialRepository>(),
    ),
  );

  sl.registerFactory(
    () => FeedBloc(
      getFeed: sl<GetFeed>(),
      createPost: sl<CreatePost>(),
      updatePost: sl<UpdatePost>(),
      deletePost: sl<DeletePost>(),
      likePost: sl<LikePost>(),
      unlikePost: sl<UnlikePost>(),
      savePost: sl<SavePost>(),
      unsavePost: sl<UnsavePost>(),
      getSavedPosts: sl<GetSavedPosts>(),
      socialRepository: sl<SocialRepository>(),
    ),
  );

  sl.registerFactory(
    () => BookmarkBloc(
      repository: sl<SocialRepository>(),
    ),
  );

  sl.registerFactory(
    () => NotificationsBloc(
      socialRepository: sl<SocialRepository>(),
    ),
  );

  sl.registerFactory(
    () => ProfileBloc(
      getUserProfile: sl<GetUserProfile>(),
      followUser: sl<FollowUser>(),
      unfollowUser: sl<UnfollowUser>(),
      socialRepository: sl<SocialRepository>(),
    ),
  );

  sl.registerFactory(
    () => SearchBloc(
      repository: sl<SocialRepository>(),
    ),
  );

  sl.registerFactory(
    () => NotificationBadgeBloc(
      socialRepository: sl<SocialRepository>(),
    ),
  );

  // Note: CommentBloc requires currentUserId parameter, so it will be created
  // in the widget tree with BlocProvider and manual dependency injection
}

Future<void> _initPets() async {
  // Pets feature dependencies

  // Repository
  sl.registerLazySingleton<PetRepository>(
    () => PetRepositoryImpl(
      supabaseClient: sl(),
      networkInfo: sl(),
      imageUploadService: sl(),
    ),
  );

  // Use Cases
  sl.registerLazySingleton(() => GetUserPets(sl()));
  sl.registerLazySingleton(() => AddPet(sl()));
  sl.registerLazySingleton(() => UpdatePet(sl()));
  sl.registerLazySingleton(() => DeletePet(sl()));

  // BLoC
  sl.registerFactory(
    () => PetBloc(
      getUserPets: sl(),
      addPet: sl(),
      updatePet: sl(),
      deletePet: sl(),
    ),
  );
}

Future<void> _initHealth() async {
  // Repository
  sl.registerLazySingleton<HealthRepository>(
    () => HealthRepositoryImpl(
      supabaseClient: sl(),
      networkInfo: sl(),
    ),
  );

  // Use Cases
  sl.registerLazySingleton(() => GetHealthRecords(sl()));
  sl.registerLazySingleton(() => AddHealthRecord(sl()));
  sl.registerLazySingleton(() => UpdateHealthRecord(sl()));
  sl.registerLazySingleton(() => DeleteHealthRecord(sl()));
  sl.registerLazySingleton(() => GetUpcomingRecords(sl()));

  // BLoC
  sl.registerFactory(
    () => HealthBloc(
      healthRepository: sl(),
      getHealthRecords: sl(),
      addHealthRecord: sl(),
      updateHealthRecord: sl(),
      deleteHealthRecord: sl(),
      getUpcomingRecords: sl(),
    ),
  );
}

Future<void> _initChat() async {
  // Chat feature dependencies

  // Data Sources
  sl.registerLazySingleton<ChatRemoteDataSource>(
    () => ChatRemoteDataSourceImpl(
      supabaseClient: sl<SupabaseClient>(),
    ),
  );

  // Repository
  sl.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(
      remoteDataSource: sl<ChatRemoteDataSource>(),
      networkInfo: sl<NetworkInfo>(),
      blockService: sl<BlockService>(),
    ),
  );

  // Use Cases
  sl.registerLazySingleton(() => GetChatRooms(sl<ChatRepository>()));
  sl.registerLazySingleton(() => GetChatMessages(sl<ChatRepository>()));
  sl.registerLazySingleton(() => SendMessage(sl<ChatRepository>()));
  sl.registerLazySingleton(() => SendImageMessage(sl<ChatRepository>()));
  sl.registerLazySingleton(() => CreateDirectChat(sl<ChatRepository>()));
  sl.registerLazySingleton(() => CreateGroupChat(sl<ChatRepository>()));
  sl.registerLazySingleton(() => UpdateLastRead(sl<ChatRepository>()));
  sl.registerLazySingleton(() => GetUnreadCount(sl<ChatRepository>()));
  sl.registerLazySingleton(() => SearchUsersForChat(sl<ChatRepository>()));
  sl.registerLazySingleton(() => LeaveChatRoom(sl<ChatRepository>()));
  sl.registerLazySingleton(() => AddChatMembers(sl<ChatRepository>()));

  // BLoCs
  sl.registerFactory(
    () => ChatBadgeBloc(
      getUnreadCount: sl<GetUnreadCount>(),
    ),
  );

  sl.registerFactory(
    () => ChatRoomsBloc(
      getChatRooms: sl<GetChatRooms>(),
      createDirectChat: sl<CreateDirectChat>(),
      createGroupChat: sl<CreateGroupChat>(),
    ),
  );

  sl.registerFactory(
    () => ChatDetailBloc(
      getChatMessages: sl<GetChatMessages>(),
      sendMessage: sl<SendMessage>(),
      sendImageMessage: sl<SendImageMessage>(),
      updateLastRead: sl<UpdateLastRead>(),
    ),
  );
}

Future<void> _initMbti() async {
  // MBTI feature dependencies (반려동물 성격 유형 검사)

  // Data Source (앱 번들 JSON 콘텐츠 로더)
  sl.registerLazySingleton<MbtiContentDataSource>(
    () => MbtiContentDataSourceImpl(),
  );

  // Data Source (검사 임시저장 — shared_preferences)
  sl.registerLazySingleton<MbtiDraftLocalDataSource>(
    () => MbtiDraftLocalDataSourceImpl(prefs: sl()),
  );

  // Domain Service (채점기 — 외부 의존 없음)
  sl.registerLazySingleton(() => const MbtiScorer());

  // Repository
  sl.registerLazySingleton<MbtiRepository>(
    () => MbtiRepositoryImpl(
      supabaseClient: sl(),
      networkInfo: sl(),
    ),
  );

  // Use Cases
  sl.registerLazySingleton(() => SaveMbtiResult(sl()));
  sl.registerLazySingleton(() => GetLatestMbtiResult(sl()));
  sl.registerLazySingleton(() => GetMbtiHistory(sl()));

  // BLoC — factory (페이지마다 새 인스턴스)
  sl.registerFactory(
    () => MbtiTestBloc(
      contentDataSource: sl(),
      draftDataSource: sl(),
      scorer: sl(),
      saveMbtiResult: sl(),
      mbtiRepository: sl(),
      socialRepository: sl(),
    ),
  );
}

Future<void> _initFortune() async {
  // Fortune feature dependencies (반려동물 운세 — 외부 호출·DB 0)

  // Data Source (앱 번들 JSON 콘텐츠 로더)
  sl.registerLazySingleton<FortuneContentDataSource>(
    () => FortuneContentDataSourceImpl(),
  );

  // Domain Service (결정적 생성기 — 외부 의존 없음)
  sl.registerLazySingleton(() => const FortuneGenerator());

  // Data Source (오늘 확인 여부 — shared_preferences)
  sl.registerLazySingleton<FortuneSeenLocalDataSource>(
    () => FortuneSeenLocalDataSourceImpl(prefs: sl()),
  );
}

Future<void> _initQuiz() async {
  // Quiz feature dependencies (O/X 퀴즈 — 외부 호출·DB 0, 로컬 prefs만)

  // Data Source (앱 번들 JSON 콘텐츠 로더)
  sl.registerLazySingleton<QuizContentDataSource>(
    () => QuizContentDataSourceImpl(),
  );

  // Data Source (시드·커서·완료·스트릭 — shared_preferences)
  sl.registerLazySingleton<QuizLocalDataSource>(
    () => QuizLocalDataSourceImpl(prefs: sl()),
  );

  // Domain Service (출제 코디네이터 — 외부 의존 없음)
  sl.registerLazySingleton(
    () => QuizSessionBuilder(
      contentDataSource: sl(),
      localDataSource: sl(),
    ),
  );

  // 보상 연계 훅 (1차 no-op — 리워드스토어 구현 시 교체)
  sl.registerLazySingleton<QuizRewardHook>(() => const QuizRewardHookNoop());
}

Future<void> _initNews() async {
  // News feature dependencies (펫 뉴스 — Supabase published 조회·링크아웃)

  // Data Source
  sl.registerLazySingleton<NewsRemoteDataSource>(
    () => NewsRemoteDataSourceImpl(supabaseClient: sl()),
  );

  // Repository
  sl.registerLazySingleton<NewsRepository>(
    () => NewsRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // Use Cases
  sl.registerLazySingleton(() => GetPublishedNews(sl()));

  // BLoC
  sl.registerFactory(() => NewsBloc(getPublishedNews: sl()));
}

Future<void> _initCore() async {
  // Core
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl());

  // Core Services
  sl.registerLazySingleton<ImageUploadService>(
    () => ImageUploadService(
      storage: sl(),
    ),
  );

  sl.registerLazySingleton<NotificationService>(
    () => NotificationService(),
  );

  sl.registerLazySingleton<PushNotificationService>(
    () => PushNotificationService(),
  );

  sl.registerLazySingleton<RealtimeService>(
    () => RealtimeService(),
  );

  sl.registerLazySingleton<ProfileService>(
    () => ProfileService(
      supabase: sl(),
      imageUploadService: sl(),
    ),
  );

  sl.registerLazySingleton<LocalNotificationService>(
    () => LocalNotificationService(supabase: sl()),
  );

  sl.registerLazySingleton<BlockService>(
    () => BlockService(supabase: sl()),
  );

  try {
    sl.registerLazySingleton<FCMService>(
      () => FCMService(
        supabase: sl(),
        localNotificationService: sl<LocalNotificationService>(),
      ),
    );
  } catch (e) {
    // Firebase 미설정 플랫폼에서는 FCMService 등록 건너뜀
  }
}

Future<void> _initExternal() async {
  // External services
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);

  // Supabase client — lazy하게 접근 (백그라운드 초기화 완료 후 실제 사용됨)
  sl.registerLazySingleton(() => Supabase.instance.client);

  // Google Sign In
  sl.registerLazySingleton(() => GoogleSignIn(
        clientId: Platform.isIOS ? Secrets.googleIosClientId : null,
        serverClientId:
            ApiConfig.isGoogleLoginConfigured ? Secrets.googleClientId : null,
        scopes: [
          'email',
          'profile',
        ],
      ));
}
