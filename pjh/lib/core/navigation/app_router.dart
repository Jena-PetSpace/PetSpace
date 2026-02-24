import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../config/injection_container.dart';
import '../../features/social/presentation/bloc/notifications_bloc.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/emotion/presentation/pages/emotion_analysis_page.dart';
import '../../features/emotion/domain/entities/emotion_analysis.dart';
import '../../features/emotion/presentation/pages/emotion_result_page.dart';
import '../../features/emotion/presentation/pages/emotion_history_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/profile_edit_page.dart';
import '../../features/profile/presentation/pages/settings_page.dart';
import '../../features/social/presentation/pages/home_page.dart';
import '../../features/social/presentation/pages/explore_page.dart';
import '../../features/social/presentation/pages/notifications_page.dart';
import '../../features/social/presentation/pages/post_detail_page.dart';
import '../../features/social/presentation/pages/create_post_page.dart';
import '../../features/social/presentation/pages/profile_page.dart' as social_profile;
import '../../features/social/presentation/bloc/profile_bloc.dart';
import '../../features/social/presentation/pages/search_page.dart';
import '../../features/social/presentation/bloc/search_bloc.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_slides_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_login_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_email_verification_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_profile_setup_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_pet_registration_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_tutorial_page.dart';
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
import '../../features/chat/presentation/bloc/chat_rooms/chat_rooms_bloc.dart';
import '../../features/chat/presentation/bloc/chat_detail/chat_detail_bloc.dart';
import '../../main_navigation.dart';
import 'auth_guard.dart';

class AppRouter {
  static GoRouter createRouter(AuthBloc authBloc) {
    return GoRouter(
      // 초기 위치는 홈으로 설정하고, redirect 로직에서 인증 상태에 따라 적절히 리다이렉트
      initialLocation: '/home',
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
    routes: [
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
        builder: (context, state, child) => AuthGuard(
          child: MainNavigation(child: child),
        ),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) => const HomePage(),
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
              final userId = state.uri.queryParameters['userId'] ?? '';
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
            builder: (context, state) => BlocProvider(
              create: (context) => sl<PetBloc>(),
              child: const PetManagementPage(),
            ),
          ),
          GoRoute(
            path: '/user-profile/:userId',
            name: 'user-profile',
            builder: (context, state) {
              final userId = state.pathParameters['userId']!;
              final currentUserId = state.uri.queryParameters['currentUserId'];

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
            path: '/emotion',
            name: 'emotion',
            builder: (context, state) {
              final petId = state.uri.queryParameters['petId'];
              final petName = state.uri.queryParameters['petName'];
              return BlocProvider(
                create: (context) => sl<PetBloc>()..add(LoadUserPets()),
                child: EmotionAnalysisPage(
                  initialPetId: petId,
                  initialPetName: petName,
                ),
              );
            },
            routes: [
              GoRoute(
                path: '/result/:analysisId',
                name: 'emotion-result',
                builder: (context, state) => EmotionResultPage(
                  analysis:
                      EmotionAnalysis.empty(), // TODO: Load from analysisId
                ),
              ),
              GoRoute(
                path: '/history',
                name: 'emotion-history',
                builder: (context, state) => const EmotionHistoryPage(
                  userId: '', // TODO: Get current user ID
                ),
              ),
            ],
          ),
        ],
      ),
    ],
      redirect: (context, state) {
        final authState = authBloc.state;
        final isOnboardingRoute = state.matchedLocation.startsWith('/onboarding');
        final currentPath = state.matchedLocation;

        log('=== ROUTER REDIRECT DEBUG ===', name: 'GoRouter');
        log('Current path: $currentPath', name: 'GoRouter');
        log('Auth state: ${authState.runtimeType}', name: 'GoRouter');

        // 카카오 OAuth 콜백 deep link는 무시 (GoRouter가 처리하지 않도록)
        // Kakao SDK가 자동으로 처리하므로 로그인 페이지로 리다이렉트
        final uri = state.uri;
        if (uri.scheme.startsWith('kakao') && uri.host == 'oauth') {
          log('Kakao OAuth callback in GoRouter - redirecting to login', name: 'GoRouter');
          return '/onboarding/login';
        }

        // 초기 상태이거나 로딩 중일 때
        // authStateChanges 스트림이 첫 이벤트를 발생시킬 때까지 대기
        if (authState is AuthInitial || authState is AuthLoading) {
          // 처음 사용하는 경우 1차 온보딩 페이지로
          if (currentPath == '/home' || currentPath == '/') {
            log('Redirecting to /onboarding (initial state)', name: 'GoRouter');
            return '/onboarding';
          }
          return null;
        }

        // 이메일 인증 필요 상태 (회원가입 직후)
        if (authState is AuthEmailVerificationRequired) {
          log('Email verification required - allowing email verification route', name: 'GoRouter');
          // 이메일 인증 페이지는 허용
          if (currentPath.startsWith('/onboarding/email-verification')) {
            return null;
          }
          // 로그인 페이지도 허용 (BlocListener가 이메일 인증 페이지로 이동시킴)
          if (currentPath == '/onboarding/login') {
            return null;
          }
          // 그 외에는 로그인 페이지로 리다이렉트
          log('Redirecting to /onboarding/login (email verification required)', name: 'GoRouter');
          return '/onboarding/login';
        }

        // 인증된 상태
        if (authState is AuthAuthenticated) {
          final user = authState.user;

          log('User authenticated - isOnboardingCompleted: ${user.isOnboardingCompleted}', name: 'GoRouter');
          log('User ID: ${user.uid}', name: 'GoRouter');

          // 온보딩이 완료되지 않은 경우 (신규 사용자)
          if (!user.isOnboardingCompleted) {
            log('User onboarding NOT completed', name: 'GoRouter');
            // 로그인 페이지에서는 약관 페이지로 리다이렉트
            if (currentPath == '/onboarding/login') {
              log('On login page - redirecting to /onboarding/terms', name: 'GoRouter');
              return '/onboarding/terms';
            }
            // 이미 온보딩 관련 페이지에 있으면 그대로 유지 (login 제외)
            if (isOnboardingRoute) {
              log('Already on onboarding route: $currentPath', name: 'GoRouter');
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
            log('Redirecting to /home (onboarding completed)', name: 'GoRouter');
            return '/home';
          }
          // 그 외에는 현재 위치 유지
          return null;
        }

        // 인증되지 않은 상태 (AuthUnauthenticated)
        log('User not authenticated', name: 'GoRouter');
        // 온보딩 페이지는 허용
        if (currentPath == '/onboarding' || currentPath == '/onboarding/slides') {
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

        // 이미 로그인 페이지에 있으면 그대로 유지
        if (currentPath == '/onboarding/login') {
          return null;
        }

        // 그 외에는 로그인 페이지로 리다이렉트 (로그아웃 시 등)
        log('Redirecting to /onboarding/login (unauthenticated)', name: 'GoRouter');
        return '/onboarding/login';
      },
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('라우팅 오류: ${state.error}'),
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
