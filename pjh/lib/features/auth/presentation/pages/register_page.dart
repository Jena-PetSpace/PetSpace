import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/social_login_button.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회원가입'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '펫페이스',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),
            const Text(
              'AI 기반 반려동물 감정 분석으로\n소중한 순간들을 기록해보세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 48),
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                return Column(
                  children: [
                    SocialLoginButton(
                      text: 'Google로 시작하기',
                      onPressed: () {
                        context.read<AuthBloc>().add(AuthSignInWithGoogleRequested());
                      },
                      backgroundColor: Colors.white,
                      textColor: Colors.black,
                      icon: Icons.g_mobiledata,
                    ),
                    const SizedBox(height: 16),
                    SocialLoginButton(
                      text: 'Kakao로 시작하기',
                      onPressed: () {
                        context.read<AuthBloc>().add(AuthSignInWithKakaoRequested());
                      },
                      backgroundColor: const Color(0xFFFFE812),
                      textColor: Colors.black,
                      icon: Icons.chat_bubble,
                    ),
                    if (state is AuthLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: CircularProgressIndicator(),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}