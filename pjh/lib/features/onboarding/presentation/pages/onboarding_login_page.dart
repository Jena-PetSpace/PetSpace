import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/error_messages.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_app_bar.dart';
import '../../../../shared/widgets/rate_limit_countdown.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/domain/services/account_deletion_policy.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/widgets/social_login_button.dart';

/// 로그인 provider 선택과 이메일 인증을 두 단계로 분리한 인증 진입 화면.
class OnboardingLoginPage extends StatefulWidget {
  /// 플랫폼 분기와 무관하게 Apple 버튼을 검증할 때만 사용한다.
  final bool? showAppleButton;

  const OnboardingLoginPage({super.key, this.showAppleButton});

  @override
  State<OnboardingLoginPage> createState() => _OnboardingLoginPageState();
}

class _OnboardingLoginPageState extends State<OnboardingLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _showEmailAuth = false;
  bool _isLogin = true;
  String? _pendingProvider;
  Duration? _rateLimitDuration;
  bool _restoreDialogShown = false;

  bool get _isPending => _pendingProvider != null;
  bool get _showApple => widget.showAppleButton ?? Platform.isIOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<AuthBloc>().state;
      if (state is AuthAccountDeleted) {
        _showRestoreDialog(context, state.user);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: _onAuthState,
      child: _showEmailAuth ? _buildEmailAuth() : _buildProviderEntry(),
    );
  }

  void _onAuthState(BuildContext context, AuthState state) {
    if (state is AuthLoading) return;

    if (state is AuthAccountDeleted) {
      _resetPending();
      _showRestoreDialog(context, state.user);
      return;
    }

    if (state is AuthEmailVerificationRequired) {
      _resetPending();
      final route =
          '/onboarding/email-verification?email=${Uri.encodeComponent(state.user.email)}';
      context.go(route);
      return;
    }

    if (state is AuthAuthenticated) {
      _resetPending();
      return;
    }

    if (state is AuthCancelled) {
      _resetPending();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${state.provider} 로그인을 취소했어요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (state is AuthError) {
      _resetPending();
      if (state.retryAfter != null) {
        setState(() => _rateLimitDuration = state.retryAfter);
      } else {
        setState(() => _rateLimitDuration = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(publicAuthErrorMessage(state.message)),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _resetPending() {
    if (!mounted) return;
    setState(() => _pendingProvider = null);
  }

  Widget _buildProviderEntry() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 28.h),
              _buildBrandStory(),
              SizedBox(height: 44.h),
              if (_showApple) ...[
                SocialLoginButton(
                  icon: Icons.apple,
                  text: 'Apple로 계속하기',
                  backgroundColor: Colors.black,
                  textColor: Colors.white,
                  isLoading: _pendingProvider == 'Apple',
                  onPressed: _isPending ? null : () => _beginProvider('Apple'),
                ),
                SizedBox(height: 12.h),
              ],
              SocialLoginButton(
                icon: Icons.g_mobiledata_rounded,
                text: 'Google로 계속하기',
                backgroundColor: isDark ? Colors.white : surface,
                textColor: AppTheme.primaryTextColor,
                borderColor: isDark ? AppTheme.neutral300 : AppTheme.border,
                isLoading: _pendingProvider == 'Google',
                onPressed: _isPending ? null : () => _beginProvider('Google'),
              ),
              SizedBox(height: 12.h),
              SocialLoginButton(
                icon: Icons.chat_bubble_rounded,
                text: '카카오로 계속하기',
                backgroundColor: const Color(0xFFFEE500),
                textColor: const Color(0xFF191919),
                isLoading: _pendingProvider == 'Kakao',
                onPressed: _isPending ? null : () => _beginProvider('Kakao'),
              ),
              SizedBox(height: 24.h),
              _buildDivider(),
              SizedBox(height: 24.h),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _isPending
                      ? null
                      : () => setState(() => _showEmailAuth = true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        isDark ? theme.colorScheme.primary : AppTheme.brandDeep,
                    backgroundColor: surface,
                    side: BorderSide(
                      color: isDark
                          ? theme.colorScheme.outlineVariant
                          : AppTheme.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
                    ),
                  ),
                  child: Text(
                    '이메일로 계속하기',
                    style: TextStyle(
                      fontSize: AppTheme.fontBody.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                '가입 과정에서 이용약관과 개인정보 처리방침을 확인하고 선택할 수 있어요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: muted,
                  fontSize: AppTheme.fontMicro.sp,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandStory() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor =
        isDark ? theme.colorScheme.onSurface : AppTheme.brandDeep;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56.w,
          height: 56.w,
          decoration: BoxDecoration(
            color: AppTheme.actionContainer,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
          ),
          child: Icon(Icons.pets, color: titleColor, size: 28.w),
        ),
        SizedBox(height: 24.h),
        Text(
          '함께한 하루가\n더 오래 기억되도록',
          style: TextStyle(
            color: titleColor,
            fontSize: 28.sp,
            fontWeight: FontWeight.w700,
            height: 1.28,
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          '반려동물의 일상과 건강을 한곳에서 기록하고, 믿을 수 있는 이웃과 나눠보세요.',
          style: TextStyle(
            color: muted,
            fontSize: AppTheme.fontBody.sp,
            height: 1.55,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    final theme = Theme.of(context);
    final divider = theme.brightness == Brightness.dark
        ? theme.colorScheme.outlineVariant
        : AppTheme.border;
    return Row(
      children: [
        Expanded(child: Divider(color: divider)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            '또는',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: AppTheme.fontCaption.sp,
            ),
          ),
        ),
        Expanded(child: Divider(color: divider)),
      ],
    );
  }

  Widget _buildEmailAuth() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: PetSpaceAppBar.page(
        title: '이메일로 계속하기',
        backgroundColor: theme.colorScheme.surface,
        onBack:
            _isPending ? null : () => setState(() => _showEmailAuth = false),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              color: theme.colorScheme.surface,
              padding: EdgeInsets.fromLTRB(24.w, 10.h, 24.w, 14.h),
              child: _buildAuthModeSelector(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 24.h),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isLogin ? '다시 만나 반가워요' : 'PetSpace를 시작해요',
                        style: TextStyle(
                          color: isDark
                              ? theme.colorScheme.onSurface
                              : AppTheme.brandDeep,
                          fontSize: AppTheme.fontTitle.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        _isLogin
                            ? '가입한 이메일과 비밀번호를 입력해주세요.'
                            : '자주 확인하는 이메일을 사용해주세요.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: AppTheme.fontBody.sp,
                        ),
                      ),
                      SizedBox(height: 28.h),
                      TextFormField(
                        key: const ValueKey('auth-email-field'),
                        controller: _emailController,
                        enabled: !_isPending,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: '이메일',
                          hintText: 'jena@example.com',
                        ),
                        validator: _validateEmail,
                      ),
                      SizedBox(height: 16.h),
                      TextFormField(
                        key: const ValueKey('auth-password-field'),
                        controller: _passwordController,
                        enabled: !_isPending,
                        obscureText: true,
                        autofillHints: _isLogin
                            ? const [AutofillHints.password]
                            : const [AutofillHints.newPassword],
                        decoration: const InputDecoration(labelText: '비밀번호'),
                        validator: _validatePassword,
                      ),
                      if (!_isLogin) ...[
                        SizedBox(height: 8.h),
                        Text(
                          '영문과 숫자를 포함해 8자 이상 입력해주세요.',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: AppTheme.fontCaption.sp,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        TextFormField(
                          key: const ValueKey('auth-password-confirm-field'),
                          controller: _passwordConfirmController,
                          enabled: !_isPending,
                          obscureText: true,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: const InputDecoration(
                            labelText: '비밀번호 확인',
                          ),
                          validator: _validatePasswordConfirm,
                        ),
                      ],
                      if (_isLogin) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isPending ? null : _forgotPassword,
                            child: const Text('비밀번호를 잊으셨나요?'),
                          ),
                        ),
                      ],
                      if (_rateLimitDuration != null) ...[
                        SizedBox(height: 16.h),
                        RateLimitCountdown(
                          duration: _rateLimitDuration!,
                          onComplete: () {
                            if (mounted) {
                              setState(() => _rateLimitDuration = null);
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                24.w,
                12.h,
                24.w,
                12.h + MediaQuery.paddingOf(context).bottom,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? theme.colorScheme.outlineVariant
                        : AppTheme.border,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  key: const ValueKey('email-auth-submit'),
                  onPressed: _isPending ? null : _submitEmail,
                  child: _pendingProvider == 'Email'
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isLogin ? '로그인' : '다음'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthModeSelector() {
    final theme = Theme.of(context);
    return Container(
      height: 44,
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.surfaceContainerHighest
            : AppTheme.subtleBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm.r),
      ),
      child: Row(
        children: [
          Expanded(child: _buildModeButton('로그인', true)),
          Expanded(child: _buildModeButton('회원가입', false)),
        ],
      ),
    );
  }

  Widget _buildModeButton(String label, bool loginMode) {
    final selected = _isLogin == loginMode;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? theme.colorScheme.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(6.r),
        child: InkWell(
          onTap: _isPending
              ? null
              : () => setState(() {
                    _isLogin = loginMode;
                    _formKey.currentState?.reset();
                  }),
          borderRadius: BorderRadius.circular(6.r),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? (isDark
                        ? theme.colorScheme.onSurface
                        : AppTheme.brandDeep)
                    : theme.colorScheme.onSurfaceVariant,
                fontSize: AppTheme.fontBody.sp,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return '이메일을 입력해주세요.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return '올바른 이메일 주소를 입력해주세요.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return '비밀번호를 입력해주세요.';
    if (!_isLogin &&
        (password.length < 8 ||
            !RegExp(r'[A-Za-z]').hasMatch(password) ||
            !RegExp(r'[0-9]').hasMatch(password))) {
      return '영문과 숫자를 포함해 8자 이상 입력해주세요.';
    }
    return null;
  }

  String? _validatePasswordConfirm(String? value) {
    if (_isLogin) return null;
    if (value == null || value.isEmpty) return '비밀번호를 다시 입력해주세요.';
    if (value != _passwordController.text) return '비밀번호가 일치하지 않습니다.';
    return null;
  }

  void _beginProvider(String provider) {
    if (_isPending) return;
    setState(() => _pendingProvider = provider);
    final bloc = context.read<AuthBloc>();
    switch (provider) {
      case 'Apple':
        bloc.add(AuthSignInWithAppleRequested());
      case 'Google':
        bloc.add(AuthSignInWithGoogleRequested());
      case 'Kakao':
        bloc.add(AuthSignInWithKakaoRequested());
    }
  }

  void _submitEmail() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _pendingProvider = 'Email');
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (_isLogin) {
      context.read<AuthBloc>().add(
            AuthSignInWithEmailRequested(email: email, password: password),
          );
    } else {
      context.read<AuthBloc>().add(
            AuthSignUpWithEmailRequested(email: email, password: password),
          );
    }
  }

  void _forgotPassword() {
    context.go('/auth/password-reset/request');
  }

  void _showRestoreDialog(BuildContext context, User user) {
    if (_restoreDialogShown || user.deletedAt == null) return;
    _restoreDialogShown = true;
    final days = AccountDeletionPolicy.remainingDays(
      user.deletedAt!,
      DateTime.now(),
    );
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('계정 복구'),
        content: Text(
          '탈퇴 처리된 계정입니다.\n'
          '$days일 후 모든 데이터가 영구 삭제될 예정이에요.\n'
          '계정을 복구할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<AuthBloc>().add(AuthSignOutRequested());
            },
            child: const Text('나중에'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<AuthBloc>().add(AuthRestoreAccountRequested());
            },
            child: const Text('복구하기'),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) _restoreDialogShown = false;
    });
  }
}
