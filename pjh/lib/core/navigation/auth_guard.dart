import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';

class AuthGuard extends StatelessWidget {
  final Widget child;

  const AuthGuard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          // 로그인 상태가 아니면 로그인 페이지로 리디렉션
          context.go('/login');
        } else if (state is AuthAuthenticated) {
          // 인증되었지만 온보딩이 완료되지 않은 경우 온보딩으로 리디렉션
          final userProfile = state.userProfile;
          if (userProfile != null && !userProfile.isOnboardingCompleted) {
            final currentLocation = GoRouterState.of(context).uri.toString();
            if (currentLocation != '/onboarding') {
              context.go('/onboarding');
            }
          }
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            // 온보딩 완료 여부 체크
            final userProfile = state.userProfile;
            if (userProfile != null && !userProfile.isOnboardingCompleted) {
              // 온보딩이 완료되지 않은 경우 로딩 표시 (리디렉션 처리 중)
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            // 인증되고 온보딩이 완료된 사용자만 자식 위젯을 표시
            return child;
          } else if (state is AuthLoading || state is AuthInitial) {
            // 로딩 중이거나 초기 상태일 때 로딩 스피너 표시
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          } else {
            // 인증되지 않은 경우 빈 컨테이너 (리디렉션 처리 중)
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
        },
      ),
    );
  }
}
