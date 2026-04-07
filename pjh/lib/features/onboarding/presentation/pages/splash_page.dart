import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';

/// 네이티브 스플래시 종료 후 AuthBloc이 인증 확인을 완료할 때까지 표시되는 화면.
/// BlocListener가 인증 완료 시 직접 이동시킴.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          if (!state.user.isOnboardingCompleted) {
            context.go('/onboarding/terms');
          } else {
            context.go('/home');
          }
        } else if (state is AuthUnauthenticated) {
          context.go('/onboarding');
        } else if (state is AuthEmailVerificationRequired) {
          context.go('/onboarding/login');
        }
      },
      child: const Scaffold(
        backgroundColor: Colors.white,
        body: SizedBox.shrink(),
      ),
    );
  }
}
