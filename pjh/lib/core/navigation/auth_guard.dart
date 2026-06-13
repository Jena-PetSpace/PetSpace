import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';

class AuthGuard extends StatelessWidget {
  final Widget child;

  const AuthGuard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // 네비게이션(미인증·soft-delete·온보딩 미완료 리디렉션)은
    // GoRouter의 refreshListenable + redirect 단일 지점에서 처리한다.
    // AuthGuard는 인증/로딩 상태에 따른 화면 표시(가드)만 담당한다.
    return BlocBuilder<AuthBloc, AuthState>(
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
        });
  }
}
