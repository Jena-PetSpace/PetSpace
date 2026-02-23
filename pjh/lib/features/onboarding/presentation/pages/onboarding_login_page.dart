import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/rate_limit_countdown.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class OnboardingLoginPage extends StatefulWidget {
  const OnboardingLoginPage({super.key});

  @override
  State<OnboardingLoginPage> createState() => _OnboardingLoginPageState();
}

class _OnboardingLoginPageState extends State<OnboardingLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _isSigningUp = false; // 회원가입 진행 중인지 추적
  bool _isKakaoLoginInProgress = false; // 카카오 로그인 중
  bool _isGoogleLoginInProgress = false; // 구글 로그인 중
  bool _isEmailLoginInProgress = false; // 이메일 로그인 중
  Duration? _rateLimitDuration; // Rate limit 남은 시간

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        developer.log('AuthBloc 상태 변경: ${state.runtimeType}', name: 'LoginPage');

        if (state is AuthEmailVerificationRequired) {
          // state의 user 객체에서 이메일을 가져옴
          final email = state.user.email;
          developer.log('이메일 인증 필요 상태 감지, 이메일: $email', name: 'LoginPage');
          // 회원가입 완료 시 이메일 인증 페이지로 이동
          setState(() {
            _isSigningUp = false;
            _rateLimitDuration = null;
            // 로딩 상태 초기화
            _isKakaoLoginInProgress = false;
            _isGoogleLoginInProgress = false;
            _isEmailLoginInProgress = false;
          });
          final route = '/onboarding/email-verification?email=${Uri.encodeComponent(email)}';
          developer.log('이메일 인증 페이지로 이동: $route', name: 'LoginPage');
          context.go(route);
        } else if (state is AuthAuthenticated) {
          // 로그인 완료 시 로딩 상태 초기화
          setState(() {
            _isKakaoLoginInProgress = false;
            _isGoogleLoginInProgress = false;
            _isEmailLoginInProgress = false;
          });
          // 로그인 완료 시 GoRouter의 redirect 로직이 자동으로 처리
          // is_onboarding_completed = false -> /onboarding/terms
          // is_onboarding_completed = true -> /home
        } else if (state is AuthError) {
          setState(() {
            _isSigningUp = false;
            // 로딩 상태 초기화
            _isKakaoLoginInProgress = false;
            _isGoogleLoginInProgress = false;
            _isEmailLoginInProgress = false;
            // Rate limit 에러인 경우 카운트다운 시작
            if (state.retryAfter != null) {
              _rateLimitDuration = state.retryAfter;
            } else {
              _rateLimitDuration = null;
              // Rate limit이 아닌 일반 에러는 SnackBar로 표시
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          });
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 40.h),
                    _buildHeader(),
                    SizedBox(height: 40.h),
                    _buildSocialLoginButtons(),
                    SizedBox(height: 24.h),
                    _buildDivider(),
                    SizedBox(height: 24.h),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildEmailForm(),
                            // Rate limit 카운트다운 표시를 회원가입 버튼 밑으로 이동
                            if (_rateLimitDuration != null) ...[
                              SizedBox(height: 16.h),
                              RateLimitCountdown(
                                duration: _rateLimitDuration!,
                                onComplete: () {
                                  setState(() {
                                    _rateLimitDuration = null;
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    _buildBottomButtons(),
                  ],
                ),
              ),
            ),
            // 로딩 오버레이
            if (_isKakaoLoginInProgress || _isGoogleLoginInProgress || _isEmailLoginInProgress)
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                ),
              ),
          ],
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
          style: TextStyle(
            fontSize: 28.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          _isLogin ? '멍x냥 다이어리에 오신 것을 환영합니다' : '새로운 계정을 만들어보세요',
          style: TextStyle(
            fontSize: 16.sp,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSocialLoginButtons() {
    // 회원가입 모드에서는 소셜 로그인 버튼 숨김
    if (!_isLogin) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        _buildSocialButton(
          icon: Icons.account_circle,
          text: 'Google 계정으로 로그인하기',
          color: const Color(0xFF4285F4),
          textColor: Colors.white,
          onPressed: _googleLogin,
        ),
        SizedBox(height: 12.h),
        _buildSocialButton(
          icon: Icons.chat_bubble,
          text: '카카오톡 계정으로 로그인하기',
          color: const Color(0xFFFEE500),
          textColor: Colors.black87,
          onPressed: _kakaoLogin,
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
      height: 50.h,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: textColor, size: 24.w),
        label: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w500,
            fontSize: 14.sp,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 0,
          side: hasBorder ? BorderSide(color: Colors.grey[300]!) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    // 회원가입 모드에서는 Divider 숨김
    if (!_isLogin) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey[300])),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            '또는',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14.sp,
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
          // 회원가입 모드에서만 성명 필드 표시
          if (!_isLogin) ...[
            TextFormField(
              controller: _displayNameController,
              decoration: InputDecoration(
                labelText: '성명',
                hintText: '실명을 입력해주세요',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.person, size: 24.w),
              ),
              validator: (value) {
                if (!_isLogin) {
                  if (value == null || value.trim().isEmpty) {
                    return '성명을 입력해주세요';
                  }
                  if (value.trim().length < 2) {
                    return '성명은 최소 2자 이상이어야 합니다';
                  }
                  if (value.trim().length > 20) {
                    return '성명은 최대 20자까지 가능합니다';
                  }
                }
                return null;
              },
            ),
            SizedBox(height: 16.h),
          ],
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: '이메일',
              hintText: 'example@email.com',
              border: const OutlineInputBorder(),
              prefixIcon: Icon(Icons.email, size: 24.w),
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
          SizedBox(height: 16.h),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: '비밀번호',
              hintText: '비밀번호를 입력하세요',
              border: const OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock, size: 24.w),
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
          // 회원가입 모드에서만 비밀번호 확인 필드 표시
          if (!_isLogin) ...[
            SizedBox(height: 16.h),
            TextFormField(
              controller: _passwordConfirmController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '비밀번호 확인',
                hintText: '비밀번호를 다시 입력하세요',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline, size: 24.w),
              ),
              validator: (value) {
                if (!_isLogin) {
                  if (value == null || value.isEmpty) {
                    return '비밀번호 확인을 입력해주세요';
                  }
                  if (value != _passwordController.text) {
                    return '비밀번호가 일치하지 않습니다';
                  }
                }
                return null;
              },
            ),
          ],
          SizedBox(height: 24.h),
          SizedBox(
            width: double.infinity,
            height: 50.h,
            child: ElevatedButton(
              onPressed: (_isSigningUp || _isEmailLoginInProgress) ? null : _emailLogin,
              child: (_isSigningUp || _isEmailLoginInProgress)
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(_isLogin ? '로그인' : '회원가입', style: TextStyle(fontSize: 16.sp)),
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
    developer.log('카카오 로그인 버튼 클릭됨', name: 'LoginPage');
    setState(() {
      _isKakaoLoginInProgress = true;
    });
    try {
      developer.log('AuthSignInWithKakaoRequested 이벤트 발생', name: 'LoginPage');
      context.read<AuthBloc>().add(AuthSignInWithKakaoRequested());
    } catch (e, stackTrace) {
      developer.log('이벤트 발생 중 오류: $e', name: 'LoginPage', error: e, stackTrace: stackTrace);
      setState(() {
        _isKakaoLoginInProgress = false;
      });
    }
  }

  void _googleLogin() {
    setState(() {
      _isGoogleLoginInProgress = true;
    });
    context.read<AuthBloc>().add(AuthSignInWithGoogleRequested());
  }

  void _emailLogin() {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      setState(() {
        _isEmailLoginInProgress = true;
      });

      if (_isLogin) {
        // 로그인
        context.read<AuthBloc>().add(
          AuthSignInWithEmailRequested(email: email, password: password),
        );
      } else {
        // 회원가입
        setState(() {
          _isSigningUp = true;
        });
        final displayName = _displayNameController.text.trim();
        context.read<AuthBloc>().add(
          AuthSignUpWithEmailRequested(
            email: email,
            password: password,
            displayName: displayName,
          ),
        );
      }
    }
  }

  void _forgotPassword() {
    context.go('/auth/password-reset/request');
  }
}
