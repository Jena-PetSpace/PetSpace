import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Features
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';

// Shared Widgets
import '../shared/widgets/main_navigation_wrapper.dart';

// Injection
import 'injection_container.dart' as di;

// 라우트 이름 상수
class Routes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String emotionAnalysis = '/emotion-analysis';
  static const String emotionResult = '/emotion-result';
  static const String postCreate = '/post-create';
  static const String postDetail = '/post-detail';
  static const String feed = '/feed';
  static const String search = '/search';
  static const String settings = '/settings';
  static const String petRegistration = '/pet-registration';
  static const String petDetail = '/pet-detail';
  static const String emotionHistory = '/emotion-history';
  static const String followers = '/followers';
  static const String following = '/following';
}

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.splash:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => di.sl<AuthBloc>()..add(AuthStarted()),
            child: const AuthWrapper(),
          ),
        );
      case Routes.onboarding:
        return MaterialPageRoute(
          builder: (_) => const OnboardingScreen(),
        );
      case Routes.login:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => di.sl<AuthBloc>(),
            child: const LoginPage(),
          ),
        );
      case Routes.home:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        );
      case Routes.profile:
        return MaterialPageRoute(
          builder: (_) => const ProfileScreen(),
        );
      case Routes.emotionAnalysis:
        return MaterialPageRoute(
          builder: (_) => const EmotionAnalysisScreen(),
        );
      case Routes.emotionResult:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => EmotionResultScreen(
            analysisResult: args?['analysisResult'],
            imagePath: args?['imagePath'],
          ),
        );
      case Routes.postCreate:
        return MaterialPageRoute(
          builder: (_) => const PostCreateScreen(),
        );
      case Routes.feed:
        return MaterialPageRoute(
          builder: (_) => const FeedScreen(),
        );
      case Routes.petRegistration:
        return MaterialPageRoute(
          builder: (_) => const PetRegistrationScreen(),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const NotFoundScreen(),
        );
    }
  }
}

// 임시 화면 위젯들 (실제로는 각 feature에서 구현됩니다)
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthLoading || state is AuthInitial) {
          return const SplashScreen();
        } else if (state is AuthAuthenticated) {
          return const HomeScreen();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFFF8A65).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.pets,
                size: 50,
                color: Color(0xFFFF8A65),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '멍x냥 다이어리',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8A65)),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Onboarding Screen'),
      ),
    );
  }
}

// LoginScreen 제거됨 - LoginPage로 대체

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainNavigationWrapper();
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Profile Screen'),
      ),
    );
  }
}

class EmotionAnalysisScreen extends StatelessWidget {
  const EmotionAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Emotion Analysis Screen'),
      ),
    );
  }
}

class EmotionResultScreen extends StatelessWidget {
  final dynamic analysisResult;
  final String? imagePath;

  const EmotionResultScreen({
    super.key,
    this.analysisResult,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Emotion Result Screen'),
      ),
    );
  }
}

class PostCreateScreen extends StatelessWidget {
  const PostCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Post Create Screen'),
      ),
    );
  }
}

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Feed Screen'),
      ),
    );
  }
}

class PetRegistrationScreen extends StatelessWidget {
  const PetRegistrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Pet Registration Screen'),
      ),
    );
  }
}

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Page Not Found'),
      ),
      body: const Center(
        child: Text('404 - Page Not Found'),
      ),
    );
  }
}