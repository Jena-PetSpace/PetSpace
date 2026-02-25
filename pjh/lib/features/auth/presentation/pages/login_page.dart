import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import '../bloc/auth_bloc.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          // 온보딩 완료 여부에 따라 다르게 라우팅
          final user = state.user;
          if (user.isOnboardingCompleted) {
            context.go('/home');
          } else {
            context.go('/onboarding/profile');
          }
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                _buildHeader(),
                const SizedBox(height: 40),
                _buildSocialLoginButtons(),
                const SizedBox(height: 24),
                _buildDivider(),
                const SizedBox(height: 24),
                _buildEmailForm(),
                const Spacer(),
                _buildBottomButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isLogin ? '로그인' : '회원가입',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isLogin ? '펫페이스에 오신 것을 환영합니다' : '새로운 계정을 만들어보세요',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSocialLoginButtons() {
    return Column(
      children: [
        _buildSocialButton(
          icon: Icons.chat_bubble,
          text: '카카오로 시작하기',
          color: const Color(0xFFFEE500),
          textColor: Colors.black87,
          onPressed: _kakaoLogin,
        ),
        const SizedBox(height: 12),
        _buildSocialButton(
          icon: Icons.account_circle,
          text: '구글로 시작하기',
          color: Colors.white,
          textColor: Colors.black87,
          onPressed: _googleLogin,
          hasBorder: true,
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String text,
    required Color color,
    required Color textColor,
    required VoidCallback onPressed,
    bool hasBorder = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: textColor),
        label: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 0,
          side: hasBorder ? BorderSide(color: Colors.grey[300]!) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey[300])),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '또는',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey[300])),
      ],
    );
  }

  Widget _buildEmailForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: '이메일',
              hintText: 'example@email.com',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '이메일을 입력해주세요';
              }
              if (!value.contains('@')) {
                return '올바른 이메일 형식이 아닙니다';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '비밀번호',
              hintText: '비밀번호를 입력하세요',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '비밀번호를 입력해주세요';
              }
              if (value.length < 6) {
                return '비밀번호는 최소 6자 이상이어야 합니다';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _emailLogin,
              child: Text(_isLogin ? '로그인' : '회원가입'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Column(
      children: [
        TextButton(
          onPressed: () {
            setState(() {
              _isLogin = !_isLogin;
            });
          },
          child: Text(
            _isLogin ? '계정이 없으신가요? 회원가입' : '이미 계정이 있으신가요? 로그인',
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (_isLogin)
          TextButton(
            onPressed: _forgotPassword,
            child: Text(
              '비밀번호를 잊으셨나요?',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ),
      ],
    );
  }

  void _kakaoLogin() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('카카오 로그인 기능 구현 예정')),
    );
    // 임시로 프로필 설정으로 이동 (실제로는 AuthBloc을 통해 처리)
    context.go('/onboarding/profile');
  }

  void _googleLogin() {
    // Google Sign In is not supported on Windows/Linux/macOS desktop platforms
    // For development on desktop, provide a bypass option
    if (Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.linux ||
        Theme.of(context).platform == TargetPlatform.macOS) {
      _showDesktopGoogleSignInDialog();
      return;
    }

    context.read<AuthBloc>().add(AuthSignInWithGoogleRequested());
  }

  void _showDesktopGoogleSignInDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('데스크톱 개발 모드'),
        content: const Text(
          'Google Sign In은 데스크톱 플랫폼을 지원하지 않습니다.\n\n'
          '개발 및 테스트를 위해:\n'
          '• 이메일/비밀번호 로그인을 사용하세요\n'
          '• 또는 Android 에뮬레이터에서 테스트하세요\n\n'
          '임시로 프로필 설정 페이지로 이동하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Development bypass - go to profile setup
              context.go('/onboarding/profile');
            },
            child: const Text('계속하기'),
          ),
        ],
      ),
    );
  }

  void _emailLogin() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isLogin ? '이메일 로그인 기능 구현 예정' : '이메일 회원가입 기능 구현 예정'),
        ),
      );
      // 임시로 프로필 설정으로 이동 (실제로는 AuthBloc을 통해 처리)
      context.go('/onboarding/profile');
    }
  }

  void _forgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('비밀번호 찾기 기능 구현 예정')),
    );
  }
}
