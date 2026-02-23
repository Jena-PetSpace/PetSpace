import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_config.dart';

// Core
import '../core/network/network_info.dart';

// Features - Auth
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
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
import '../features/social/domain/usecases/get_comments.dart';
import '../features/social/domain/usecases/create_comment.dart';
import '../features/social/domain/usecases/delete_comment.dart';
import '../features/social/domain/usecases/update_comment.dart';
import '../features/social/presentation/bloc/social_bloc.dart';
import '../features/social/presentation/bloc/notifications_bloc.dart';
import '../features/social/presentation/bloc/profile_bloc.dart';
import '../features/social/presentation/bloc/feed_bloc.dart';
import '../features/social/presentation/bloc/search_bloc.dart';

// Features - Pets
import '../features/pets/data/repositories/pet_repository_impl.dart';
import '../features/pets/domain/repositories/pet_repository.dart';
import '../features/pets/domain/usecases/get_user_pets.dart';
import '../features/pets/domain/usecases/add_pet.dart';
import '../features/pets/domain/usecases/update_pet.dart';
import '../features/pets/domain/usecases/delete_pet.dart';
import '../features/pets/presentation/bloc/pet_bloc.dart';

// Core Services
import '../core/services/image_upload_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/realtime_service.dart';
import '../core/services/profile_service.dart';
import '../core/services/fcm_service.dart';

final sl = GetIt.instance;

Future<void> init() async {
  //! Features
  await _initAuth();
  await _initEmotion();
  await _initSocial();
  await _initPets();
  await _initCore();
  await _initExternal();
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
  sl.registerLazySingleton(() => SignOut(sl()));

  // BLoC
  sl.registerFactory(
    () => AuthBloc(
      authRepository: sl(),
      signInWithGoogle: sl(),
      signInWithKakao: sl(),
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

  // BLoC
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

Future<void> _initCore() async {
  // Core
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl());

  // Core Services
  sl.registerLazySingleton<ImageUploadService>(
    () => ImageUploadService(
      storage: sl(),
      auth: null,
    ),
  );

  sl.registerLazySingleton<NotificationService>(
    () => NotificationService(),
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

  sl.registerLazySingleton<FCMService>(
    () => FCMService(
      supabase: sl(),
    ),
  );
}

Future<void> _initExternal() async {
  // External services
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);

  // Supabase client
  sl.registerLazySingleton(() => Supabase.instance.client);

  // Google Sign In
  sl.registerLazySingleton(() => GoogleSignIn(
    serverClientId: ApiConfig.isGoogleLoginConfigured ? '436717619181-57khh827kfg9t5j1oo9tpnloalf7rtb7.apps.googleusercontent.com' : null,
    scopes: [
      'email',
      'profile',
    ],
  ));
}