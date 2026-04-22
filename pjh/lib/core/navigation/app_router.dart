import 'dart:async';
import '../../config/injection_container.dart' as di;
import '../../core/services/fcm_service.dart';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../config/injection_container.dart';
import '../../features/social/presentation/bloc/notifications_bloc.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/emotion/presentation/pages/emotion_analysis_page.dart';
import '../../features/emotion/presentation/pages/emotion_result_loader_page.dart';
import '../../features/emotion/presentation/pages/emotion_history_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/profile_edit_page.dart';
import '../../features/profile/presentation/pages/settings_page.dart';
import '../../features/social/presentation/pages/home_page.dart';
import '../../features/social/presentation/pages/explore_page.dart';
import '../../features/social/presentation/pages/notifications_page.dart';
import '../../features/social/presentation/pages/post_detail_page.dart';
import '../../features/social/presentation/pages/create_post_page.dart';
import '../../features/social/presentation/pages/profile_page.dart'
    as social_profile;
import '../../features/social/presentation/bloc/profile_bloc.dart';
import '../../features/social/presentation/pages/search_page.dart';
import '../../features/social/presentation/bloc/search_bloc.dart';
import '../../features/health/presentation/pages/health_main_page.dart';
import '../../features/feed_hub/presentation/pages/feed_hub_page.dart';
import '../../features/my/presentation/pages/my_page.dart';
import '../../features/my/presentation/pages/my_posts_page.dart';
import '../../features/my/presentation/pages/my_saved_posts_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_slides_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_login_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_email_verification_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_profile_setup_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_pet_registration_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_tutorial_page.dart';
import '../../features/onboarding/presentation/pages/splash_page.dart';
import '../../features/profile/presentation/pages/privacy_policy_page.dart';
import '../../features/my/presentation/pages/reward_store_page.dart';
import '../../features/emotion/presentation/pages/emotion_calendar_page.dart';
import '../../features/home/presentation/pages/hospital_search_page.dart';
import '../../features/social/presentation/pages/channel_subscription_page.dart';
import '../../features/pets/presentation/pages/public_pet_page.dart';
import '../../features/emotion/presentation/pages/weekly_report_page.dart';
import '../../features/emotion/presentation/pages/ai_history_page.dart';
import '../../features/emotion/presentation/pages/emotion_timeline_page.dart';
import '../../features/emotion/presentation/pages/emotion_loading_page.dart';
import '../../features/emotion/presentation/pages/emotion_result_page.dart';
import '../../features/emotion/domain/entities/emotion_analysis.dart';
import '../../features/emotion/presentation/widgets/emotion_loading_widget.dart';
import '../../features/emotion/presentation/bloc/emotion_analysis_bloc.dart';
import '../../features/health/presentation/pages/health_alert_settings_page.dart';
import '../../features/emotion/presentation/pages/health_result_page.dart';
import '../../features/emotion/data/models/health_analysis_model.dart';
import '../../features/onboarding/presentation/pages/onboarding_complete_page.dart';
import '../../features/auth/presentation/pages/terms_agreement_page.dart';
import '../../features/auth/presentation/pages/kakao_consent_page.dart';
import '../../features/auth/presentation/pages/password_reset_request_page.dart';
import '../../features/auth/presentation/pages/password_reset_verification_page.dart';
import '../../features/auth/presentation/pages/password_reset_new_password_page.dart';
import '../../features/pets/presentation/pages/pet_management_page.dart';
import '../../features/pets/presentation/bloc/pet_bloc.dart';
import '../../features/pets/presentation/bloc/pet_event.dart';
import '../../features/chat/presentation/pages/chat_rooms_page.dart';
import '../../features/chat/presentation/pages/chat_detail_page.dart';
import '../../features/chat/presentation/pages/create_chat_page.dart';
import '../../features/chat/presentation/pages/chat_room_settings_page.dart';
import '../../features/chat/presentation/bloc/chat_rooms/chat_rooms_bloc.dart';
import '../../features/chat/presentation/bloc/chat_detail/chat_detail_bloc.dart';
import '../../features/social/presentation/pages/hashtag_page.dart';
import '../../features/social/presentation/pages/location_posts_page.dart';
import '../../features/my/presentation/pages/my_settings_page.dart';
import '../../features/profile/presentation/pages/notification_settings_page.dart';
import '../../features/profile/presentation/pages/privacy_settings_page.dart';
import '../../features/profile/presentation/pages/help_page.dart';
import '../../features/social/presentation/pages/followers_page.dart';
import '../../main_navigation.dart';
import 'auth_guard.dart';

class AppRouter {
  static GoRouter createRouter(AuthBloc authBloc) {
    final router = GoRouter(
      // 초기 위치는 홈으로 설정하고, redirect 로직에서 인증 상태에 따라 적절히 리다이렉트
      initialLocation: '/home',
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      routes: [
        // ── ShellRoute 밖: 하단 네비바 없는 fullscreen 라우트 ──
        GoRoute(
          path: '/emotion/loading',
          name: 'emotion-loading',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            final imagePaths = (extra['imagePaths'] as List<String>?) ?? [];
            final bloc = extra['bloc'] as EmotionAnalysisBloc?;
            final event = extra['event'] as EmotionAnalysisEvent?;
            if (bloc == null) {
              return const Scaffold(
                body: SizedBox.expand(child: EmotionLoadingWidget()),
              );
            }
            return BlocProvider.value(
              value: bloc,
              child: EmotionLoadingPage(imagePaths: imagePaths, event: event),
            );
          },
        ),
        GoRoute(
          path: '/emotion/result-direct',
          name: 'emotion-result-direct',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            final analysis = extra['analysis'] as EmotionAnalysis?;
            final imagePaths = (extra['imagePaths'] as List<String>?) ?? [];
            final bloc = extra['bloc'] as EmotionAnalysisBloc?;
            if (analysis == null) return const SizedBox.shrink();
            final page = EmotionResultPage(
              analysis: analysis,
              imagePaths: imagePaths,
            );
            if (bloc != null) {
              return BlocProvider.value(value: bloc, child: page);
            }
            return BlocProvider(
              create: (_) => sl<EmotionAnalysisBloc>(),
              child: page,
            );
          },
        ),
        GoRoute(path: '/channels', builder: (_, __) => const ChannelSubscriptionPage()),
        GoRoute(
          path: '/pet/public/:petId',
          builder: (_, state) => PublicPetPage(petId: state.pathParameters['petId']!),
        ),
        GoRoute(path: '/emotion/weekly-report', builder: (_, __) => const WeeklyReportPage()),
        GoRoute(path: '/health/alert-settings', builder: (_, __) => const HealthAlertSettingsPage()),
        GoRoute(
          path: '/privacy',
          builder: (context, state) => const PrivacyPolicyPage(),
        ),
        GoRoute(
          path: '/reward',
          builder: (context, state) => const RewardStorePage(),
        ),
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashPage(),
        ),
        GoRoute(
          path: '/onboarding',
          name: 'onboarding',
          builder: (context, state) => const OnboardingPage(),
        ),
        GoRoute(
          path: '/onboarding/slides',
          name: 'onboarding-slides',
          builder: (context, state) => const OnboardingSlidesPage(),
        ),
        GoRoute(
          path: '/onboarding/login',
          name: 'onboarding-login',
          builder: (context, state) => const OnboardingLoginPage(),
        ),
        GoRoute(
          path: '/onboarding/email-verification',
          name: 'onboarding-email-verification',
          builder: (context, state) {
            final email = state.uri.queryParameters['email'] ?? '';
            return OnboardingEmailVerificationPage(email: email);
          },
        ),
        GoRoute(
          path: '/onboarding/kakao-consent',
          name: 'kakao-consent',
          builder: (context, state) => const KakaoConsentPage(),
        ),
        GoRoute(
          path: '/onboarding/terms',
          name: 'onboarding-terms',
          builder: (context, state) => const TermsAgreementPage(),
        ),
        GoRoute(
          path: '/onboarding/profile',
          name: 'onboarding-profile',
          builder: (context, state) => const OnboardingProfileSetupPage(),
        ),
        GoRoute(
          path: '/onboarding/pet-registration',
          name: 'onboarding-pet-registration',
          builder: (context, state) => const OnboardingPetRegistrationPage(),
        ),
        GoRoute(
          path: '/onboarding/tutorial',
          name: 'onboarding-tutorial',
          builder: (context, state) => const OnboardingTutorialPage(),
        ),
        GoRoute(
          path: '/onboarding/complete',
          name: 'onboarding-complete',
          builder: (context, state) => const OnboardingCompletePage(),
        ),
        // 카카오 OAuth 콜백 처리 (GoRouter 오류 방지용)
        // 실제 처리는 Kakao SDK가 자동으로 수행하므로 단순히 로그인 페이지로 리다이렉트
        GoRoute(
          path: '/oauth',
          name: 'oauth-callback',
          redirect: (context, state) {
            // Kakao SDK가 이미 OAuth를 처리했으므로 로그인 페이지로 이동
            // AuthBloc의 상태 변경에 따라 자동으로 적절한 페이지로 리다이렉트됨
            return '/onboarding/login';
          },
        ),
        // 비밀번호 재설정 플로우
        GoRoute(
          path: '/auth/password-reset/request',
          name: 'password-reset-request',
          builder: (context, state) => const PasswordResetRequestPage(),
        ),
        GoRoute(
          path: '/auth/password-reset/verify',
          name: 'password-reset-verify',
          builder: (context, state) {
            final email = state.uri.queryParameters['email'] ?? '';
            return PasswordResetVerificationPage(email: email);
          },
        ),
        GoRoute(
          path: '/auth/password-reset/new-password',
          name: 'password-reset-new-password',
          builder: (context, state) {
            final email = state.uri.queryParameters['email'] ?? '';
            return PasswordResetNewPasswordPage(email: email);
          },
        ),
        GoRoute(
          path: '/post/:postId',
          name: 'post-detail',
          builder: (context, state) => PostDetailPage(
            postId: state.pathParameters['postId']!,
          ),
        ),
        ShellRoute(
          builder: (context, state, child) => BlocProvider(
            create: (_) => sl<PetBloc>()..add(LoadUserPets()),
            child: AuthGuard(
              child: MainNavigation(child: child),
            ),
          ),
          routes: [
            GoRoute(
              path: '/home',
              name: 'home',
              builder: (context, state) => const HomePage(),
            ),
            GoRoute(
              path: '/health',
              name: 'health',
              builder: (context, state) => const HealthMainPage(),
            ),
            GoRoute(
              path: '/feed',
              name: 'feed-hub',
              builder: (context, state) {
                final tab = state.uri.queryParameters['tab'];
                final category = state.uri.queryParameters['category'];
                int initialTab = 0;
                if (tab == 'following') initialTab = 1;
                if (tab == 'community') initialTab = 2;
                return FeedHubPage(
                    initialTab: initialTab, initialCategory: category);
              },
            ),
            GoRoute(
              path: '/my',
              name: 'my',
              builder: (context, state) => const MyPage(),
              routes: [
                GoRoute(
                  path: 'posts',
                  name: 'my-posts',
                  builder: (context, state) => const MyPostsPage(),
                ),
                GoRoute(
                  path: 'saved',
                  name: 'my-saved',
                  builder: (context, state) => const MySavedPostsPage(),
                ),
                GoRoute(
                  path: 'edit-profile',
                  name: 'my-edit-profile',
                  builder: (context, state) => const ProfileEditPage(),
                ),
              ],
            ),
            GoRoute(
              path: '/followers/:uid',
              name: 'followers',
              builder: (context, state) => FollowersPage(
                userId: state.pathParameters['uid']!,
                userName: state.uri.queryParameters['name'] ?? '',
              ),
            ),
            GoRoute(
              path: '/following/:uid',
              name: 'following',
              builder: (context, state) => FollowersPage(
                userId: state.pathParameters['uid']!,
                userName: state.uri.queryParameters['name'] ?? '',
                initialTab: 1,
              ),
            ),
            GoRoute(
              path: '/explore',
              name: 'explore',
              builder: (context, state) {
                final hashtag = state.uri.queryParameters['hashtag'];
                final query = state.uri.queryParameters['query'];

                return ExplorePage(
                  initialHashtag: hashtag,
                  initialQuery: query,
                );
              },
            ),
            GoRoute(
              path: '/search',
              name: 'search',
              builder: (context, state) {
                final hashtag = state.uri.queryParameters['hashtag'];
                final query = state.uri.queryParameters['query'];

                return BlocProvider(
                  create: (context) => sl<SearchBloc>(),
                  child: SearchPage(
                    initialHashtag: hashtag,
                    initialQuery: query,
                  ),
                );
              },
            ),
            GoRoute(
              path: '/create-post',
              name: 'create-post',
              builder: (context, state) {
                final petId = state.uri.queryParameters['petId'];
                final petName = state.uri.queryParameters['petName'];
                final imageUrl = state.uri.queryParameters['imageUrl'];
                return CreatePostPage(
                  petId: petId,
                  petName: petName,
                  imageUrl: imageUrl,
                );
              },
            ),
            GoRoute(
              path: '/notifications',
              name: 'notifications',
              builder: (context, state) {
                final queryUserId = state.uri.queryParameters['userId'];
                final authState = authBloc.state;
                final userId = queryUserId ??
                    (authState is AuthAuthenticated ? authState.user.uid : '');
                return BlocProvider(
                  create: (context) => sl<NotificationsBloc>()
                    ..add(LoadNotificationsRequested(userId: userId)),
                  child: NotificationsPage(userId: userId),
                );
              },
            ),
            GoRoute(
              path: '/profile',
              name: 'profile',
              builder: (context, state) => const ProfilePage(),
              routes: [
                GoRoute(
                  path: '/edit',
                  name: 'profile-edit',
                  builder: (context, state) => const ProfileEditPage(),
                ),
                GoRoute(
                  path: '/settings',
                  name: 'settings',
                  builder: (context, state) => const SettingsPage(),
                ),
              ],
            ),
            GoRoute(
              path: '/pets',
              name: 'pets',
              builder: (context, state) => const PetManagementPage(),
            ),
            GoRoute(
              path: '/settings',
              name: 'settings-direct',
              builder: (context, state) => const SettingsPage(),
            ),
            GoRoute(
              path: '/settings/my',
              name: 'my-settings',
              builder: (context, state) => const MySettingsPage(),
            ),
            GoRoute(
              path: '/settings/notification',
              name: 'notification-settings',
              builder: (context, state) => const NotificationSettingsPage(),
            ),
            GoRoute(
              path: '/settings/privacy',
              name: 'privacy-settings',
              builder: (context, state) => const PrivacySettingsPage(),
            ),
            GoRoute(
              path: '/settings/help',
              name: 'help-settings',
              builder: (context, state) => const HelpPage(),
            ),
            GoRoute(
              path: '/user-profile/:userId',
              name: 'user-profile',
              builder: (context, state) {
                final userId = state.pathParameters['userId']!;
                // query param 없거나 빈 문자열이면 현재 로그인 유저 ID 사용
                final paramId = state.uri.queryParameters['currentUserId'];
                final currentUserId = (paramId != null && paramId.isNotEmpty)
                    ? paramId
                    : authBloc.state is AuthAuthenticated
                        ? (authBloc.state as AuthAuthenticated).user.uid
                        : null;

                return BlocProvider(
                  create: (context) => sl<ProfileBloc>(),
                  child: social_profile.ProfilePage(
                    userId: userId,
                    currentUserId: currentUserId,
                  ),
                );
              },
            ),
            GoRoute(
              path: '/chat',
              name: 'chat',
              builder: (context, state) => BlocProvider(
                create: (context) => sl<ChatRoomsBloc>(),
                child: const ChatRoomsPage(),
              ),
            ),
            GoRoute(
              path: '/chat/new',
              name: 'chat-new',
              builder: (context, state) => BlocProvider(
                create: (context) => sl<ChatRoomsBloc>(),
                child: const CreateChatPage(),
              ),
            ),
            GoRoute(
              path: '/chat/:roomId',
              name: 'chat-detail',
              builder: (context, state) {
                final roomId = state.pathParameters['roomId']!;
                final roomName = state.uri.queryParameters['name'];
                return BlocProvider(
                  create: (context) => sl<ChatDetailBloc>(),
                  child: ChatDetailPage(
                    roomId: roomId,
                    roomName: roomName,
                  ),
                );
              },
            ),
            GoRoute(
              path: '/chat/:roomId/settings',
              name: 'chat-settings',
              builder: (context, state) => ChatRoomSettingsPage(
                roomId: state.pathParameters['roomId']!,
                roomName: state.uri.queryParameters['name'],
              ),
            ),
            GoRoute(
              path: '/hashtag/:tag',
              name: 'hashtag',
              builder: (context, state) => HashtagPage(
                hashtag: state.pathParameters['tag']!,
              ),
            ),
            GoRoute(
              path: '/location',
              name: 'location-posts',
              builder: (context, state) {
                final extra = state.extra as Map<String, dynamic>? ?? {};
                return LocationPostsPage(
                  lat: (extra['lat'] as num?)?.toDouble() ?? 0.0,
                  lng: (extra['lng'] as num?)?.toDouble() ?? 0.0,
                  locationName: extra['locationName'] as String?,
                );
              },
            ),
            GoRoute(
              path: '/hospital',
              name: 'hospital',
              builder: (_, __) => const HospitalSearchPage(),
            ),
            GoRoute(
              path: '/health/result',
              name: 'health-result',
              builder: (context, state) {
                final result = state.extra as HealthAnalysisModel;
                return HealthResultPage(result: result);
              },
            ),
            GoRoute(
              path: '/emotion',
              name: 'emotion',
              builder: (context, state) {
                final petId = state.uri.queryParameters['petId'];
                final petName = state.uri.queryParameters['petName'];
                return EmotionAnalysisPage(
                  initialPetId: petId,
                  initialPetName: petName,
                );
              },
              routes: [
                GoRoute(
                  path: 'result/:analysisId',
                  name: 'emotion-result',
                  builder: (context, state) => EmotionResultLoaderPage(
                    analysisId: state.pathParameters['analysisId']!,
                  ),
                ),
                GoRoute(
                  path: '/history',
                  name: 'emotion-history',
                  builder: (context, state) {
                    final authState = authBloc.state;
                    final userId = authState is AuthAuthenticated
                        ? authState.user.uid
                        : '';
                    return EmotionHistoryPage(userId: userId);
                  },
                ),
                GoRoute(
                  path: 'calendar',
                  name: 'emotion-calendar',
                  builder: (_, __) => const EmotionCalendarPage(),
                ),
              ],
            ),
            GoRoute(
              path: '/ai-history-page',
              name: 'ai-history-page',
              builder: (context, state) {
                return BlocProvider(
                  create: (_) => sl<EmotionAnalysisBloc>(),
                  child: const AiHistoryPage(),
                );
              },
            ),
            GoRoute(
              path: '/ai-history',
              name: 'ai-history',
              builder: (context, state) {
                return BlocProvider(
                  create: (_) => sl<EmotionAnalysisBloc>(),
                  child: const AiHistoryPage(),
                );
              },
            ),
            GoRoute(
              path: '/emotion-timeline',
              name: 'emotion-timeline',
              builder: (context, state) {
                final extra = state.extra as Map<String, dynamic>? ?? {};
                return EmotionTimelinePage(
                  petId: extra['petId'] as String? ?? '',
                  petName: extra['petName'] as String? ?? '반려동물',
                  petAvatarUrl: extra['petAvatarUrl'] as String?,
                );
              },
            ),
          ],
        ),
      ],
      redirect: (context, state) {
        final authState = authBloc.state;
        final isOnboardingRoute =
            state.matchedLocation.startsWith('/onboarding');
        final currentPath = state.matchedLocation;

        log('=== ROUTER REDIRECT DEBUG ===', name: 'GoRouter');
        log('Current path: $currentPath', name: 'GoRouter');
        log('Auth state: ${authState.runtimeType}', name: 'GoRouter');

        // 카카오 OAuth 콜백 deep link는 무시 (GoRouter가 처리하지 않도록)
        // Kakao SDK가 자동으로 처리하므로 로그인 페이지로 리다이렉트
        final uri = state.uri;
        if (uri.scheme.startsWith('kakao') && uri.host == 'oauth') {
          log('Kakao OAuth callback in GoRouter - redirecting to login',
              name: 'GoRouter');
          return '/onboarding/login';
        }

        // 초기 상태일 때만 splash로 → AuthLoading은 현재 위치 유지 (로그인 중 스플래시로 튕기지 않도록)
        if (authState is AuthInitial) {
          log('Auth state is initial - holding at splash', name: 'GoRouter');
          return '/splash';
        }

        // 로딩 중일 때는 현재 위치 유지 (로그인 버튼 누른 후 splash로 튕기지 않도록)
        if (authState is AuthLoading) {
          log('Auth state is loading - staying at current path: $currentPath',
              name: 'GoRouter');
          return null;
        }

        // 이메일 인증 필요 상태 (회원가입 직후)
        if (authState is AuthEmailVerificationRequired) {
          log('Email verification required - allowing email verification route',
              name: 'GoRouter');
          // 이메일 인증 페이지는 허용
          if (currentPath.startsWith('/onboarding/email-verification')) {
            return null;
          }
          // 로그인 페이지도 허용 (BlocListener가 이메일 인증 페이지로 이동시킴)
          if (currentPath == '/onboarding/login') {
            return null;
          }
          // 그 외에는 로그인 페이지로 리다이렉트
          log('Redirecting to /onboarding/login (email verification required)',
              name: 'GoRouter');
          return '/onboarding/login';
        }

        // 인증된 상태
        if (authState is AuthAuthenticated) {
          final user = authState.user;

          log('User authenticated - isOnboardingCompleted: ${user.isOnboardingCompleted}',
              name: 'GoRouter');
          log('User ID: ${user.uid}', name: 'GoRouter');

          // 온보딩이 완료되지 않은 경우 (신규 사용자)
          if (!user.isOnboardingCompleted) {
            log('User onboarding NOT completed', name: 'GoRouter');
            // 로그인 페이지에서는 약관 페이지로 리다이렉트
            if (currentPath == '/onboarding/login') {
              log('On login page - redirecting to /onboarding/terms',
                  name: 'GoRouter');
              return '/onboarding/terms';
            }
            // 이미 온보딩 관련 페이지에 있으면 그대로 유지 (login 제외)
            if (isOnboardingRoute) {
              log('Already on onboarding route: $currentPath',
                  name: 'GoRouter');
              return null;
            }
            // 온보딩 약관 동의 페이지로 리다이렉트
            log('Redirecting to /onboarding/terms', name: 'GoRouter');
            return '/onboarding/terms';
          }

          // 온보딩이 완료된 경우 (기존 사용자)
          log('User onboarding completed - existing user', name: 'GoRouter');
          // 온보딩 페이지에 있으면 홈으로 리다이렉트
          if (isOnboardingRoute) {
            log('Redirecting to /home (onboarding completed)',
                name: 'GoRouter');
            return '/home';
          }
          // 그 외에는 현재 위치 유지
          return null;
        }

        // 인증되지 않은 상태 (AuthUnauthenticated)
        log('User not authenticated', name: 'GoRouter');
        // 온보딩 페이지는 허용
        if (currentPath == '/onboarding' ||
            currentPath == '/onboarding/slides') {
          return null;
        }

        // 이메일 인증 페이지는 허용
        if (currentPath.startsWith('/onboarding/email-verification')) {
          return null;
        }

        // 비밀번호 재설정 페이지는 허용
        if (currentPath.startsWith('/auth/password-reset')) {
          return null;
        }

        // 스플래시 페이지는 인증 상태와 무관하게 항상 허용
        // (SplashPage 내부에서 BlocListener가 인증 확인 후 직접 이동)
        if (currentPath == '/splash') {
          return null;
        }

        // 이미 로그인 페이지에 있으면 그대로 유지
        if (currentPath == '/onboarding/login') {
          return null;
        }

        // 그 외에는 로그인 페이지로 리다이렉트 (로그아웃 시 등)
        log('Redirecting to /onboarding/login (unauthenticated)',
            name: 'GoRouter');
        return '/onboarding/login';
      },
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('페이지를 찾을 수 없습니다.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/onboarding/login'),
                child: const Text('로그인으로 돌아가기'),
              ),
            ],
          ),
        ),
      ),
    );

    // FCMService에 navigatorKey 주입 (딥링크 라우팅용)
    try {
      di.sl<FCMService>().navigatorKey = GlobalKey<NavigatorState>()
        ..currentState;
      // GoRouter 자체 navigatorKey 활용
      di.sl<FCMService>().navigatorKey = router.routerDelegate.navigatorKey;
    } catch (e) {
      log('[AppRouter] FCMService navigatorKey 설정 실패: $e', name: 'AppRouter');
    }

    return router;
  }
}

// GoRouter의 refreshListenable을 위한 헬퍼 클래스
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
