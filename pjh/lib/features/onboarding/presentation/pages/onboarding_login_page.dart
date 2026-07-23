import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/error_messages.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/rate_limit_countdown.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/domain/services/account_deletion_policy.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

/// 이메일 인증과 소셜 로그인을 한 화면에 제공하는 인증 진입 화면.
class OnboardingLoginPage extends StatefulWidget {
  /// 플랫폼 분기와 무관하게 Apple 버튼을 검증할 때만 사용한다.
  final bool? showAppleButton;

  const OnboardingLoginPage({super.key, this.showAppleButton});

  @override
  State<OnboardingLoginPage> createState() => _OnboardingLoginPageState();
}

class _OnboardingLoginPageState extends State<OnboardingLoginPage> {
  // Google Identity가 제공하는 2026 iOS Light 원형 로그인 아이콘 원본.
  // 임의의 단색 G를 만들지 않고 승인된 자산을 그대로 렌더링한다.
  static final _googleSignInButtonPng = base64Decode(
    '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',
  );

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

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
      child: _buildUnifiedEntry(),
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

  Widget _buildUnifiedEntry() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(24.w, 32.h, 24.w, 28.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBrandStory(),
              SizedBox(height: 32.h),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: const ValueKey('auth-email-field'),
                      controller: _emailController,
                      enabled: !_isPending,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: '아이디',
                        hintText: 'jena@example.com',
                      ),
                      validator: _validateEmail,
                    ),
                    SizedBox(height: 14.h),
                    TextFormField(
                      key: const ValueKey('auth-password-field'),
                      controller: _passwordController,
                      enabled: !_isPending,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      obscureText: true,
                      textInputAction: _isLogin
                          ? TextInputAction.done
                          : TextInputAction.next,
                      onFieldSubmitted: _isLogin && !_isPending
                          ? (_) => _submitEmail()
                          : null,
                      autofillHints: _isLogin
                          ? const [AutofillHints.password]
                          : const [AutofillHints.newPassword],
                      decoration: const InputDecoration(labelText: '비밀번호'),
                      validator: _validatePassword,
                    ),
                    if (!_isLogin) ...[
                      SizedBox(height: 14.h),
                      TextFormField(
                        key: const ValueKey('auth-password-confirm-field'),
                        controller: _passwordConfirmController,
                        enabled: !_isPending,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted:
                            _isPending ? null : (_) => _submitEmail(),
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: const InputDecoration(
                          labelText: '비밀번호 확인',
                        ),
                        validator: _validatePasswordConfirm,
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
                    SizedBox(height: 20.h),
                    SizedBox(
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
                            : Text(
                                _isLogin ? '로그인하기' : '회원가입 계속하기',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),
              _buildAccountLinks(),
              SizedBox(height: 24.h),
              _buildDivider(),
              SizedBox(height: 20.h),
              _buildSocialLoginRow(isDark),
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
          '반려동물의 감정부터 건강 신호까지 AI로 확인하고, 소중한 일상을 기록해보세요.',
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

  Widget _buildAccountLinks() {
    final theme = Theme.of(context);
    final linkColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.primary
        : AppTheme.brandDeep;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2.w,
      runSpacing: 0,
      children: [
        TextButton(
          key: const Key('auth-mode-toggle'),
          onPressed: _isPending
              ? null
              : () => setState(() {
                    _isLogin = !_isLogin;
                    _formKey.currentState?.reset();
                  }),
          style: TextButton.styleFrom(foregroundColor: linkColor),
          child: Text(_isLogin ? '회원가입' : '로그인'),
        ),
        _buildLinkSeparator(theme),
        TextButton(
          key: const Key('find-account-id'),
          onPressed: _isPending ? null : _showAccountIdHelp,
          style: TextButton.styleFrom(foregroundColor: linkColor),
          child: const Text('아이디 찾기'),
        ),
        _buildLinkSeparator(theme),
        TextButton(
          key: const Key('find-password'),
          onPressed: _isPending ? null : _forgotPassword,
          style: TextButton.styleFrom(foregroundColor: linkColor),
          child: const Text('비밀번호 찾기'),
        ),
      ],
    );
  }

  Widget _buildLinkSeparator(ThemeData theme) {
    return Text(
      '·',
      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
    );
  }

  Widget _buildSocialLoginRow(bool isDark) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        if (_showApple) _buildSocialCircle('Apple', isDark),
        _buildSocialCircle('Google', isDark),
        _buildSocialCircle('Kakao', isDark),
      ],
    );
  }

  Widget _buildSocialCircle(String provider, bool isDark) {
    final isLoading = _pendingProvider == provider;
    final semanticsLabel = switch (provider) {
      'Google' => 'Google로 로그인하기',
      'Kakao' => '카카오톡으로 로그인하기',
      _ => 'Apple로 로그인하기',
    };
    final (Color background, Color foreground, Color border, Widget icon) =
        switch (provider) {
      'Apple' => (
          isDark ? Colors.white : Colors.black,
          isDark ? Colors.black : Colors.white,
          Colors.transparent,
          const Icon(Icons.apple, size: 26),
        ),
      'Google' => (
          Colors.transparent,
          AppTheme.actionBase,
          Colors.transparent,
          Image.memory(
            _googleSignInButtonPng,
            key: const Key('google-login-brand-icon'),
            width: 58,
            height: 58,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            filterQuality: FilterQuality.high,
          ),
        ),
      _ => (
          const Color(0xFFFEE500),
          const Color(0xFF191919),
          Colors.transparent,
          SvgPicture.asset(
            'assets/images/kakao_talk_login_symbol.svg',
            key: const Key('kakao-login-brand-icon'),
            width: 30,
            height: 30,
          ),
        ),
    };
    final enabled = !_isPending;
    return Semantics(
      label: semanticsLabel,
      button: true,
      enabled: enabled,
      child: ExcludeSemantics(
        child: Tooltip(
          message: semanticsLabel,
          child: Material(
            key: ValueKey('social-login-$provider'),
            color: background,
            shape: CircleBorder(side: BorderSide(color: border)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? () => _beginProvider(provider) : null,
              customBorder: const CircleBorder(),
              child: SizedBox.square(
                dimension: 58,
                child: Center(
                  child: isLoading
                      ? SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: foreground,
                          ),
                        )
                      : IconTheme(
                          data: IconThemeData(color: foreground),
                          child: DefaultTextStyle(
                            style: TextStyle(color: foreground),
                            child: icon,
                          ),
                        ),
                ),
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
    if (password.length < 8 ||
        !RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password)) {
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

  void _showAccountIdHelp() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('아이디를 찾고 있나요?'),
        content: const Text(
          'PetSpace 아이디는 가입할 때 사용한 이메일 주소예요.\n\n'
          '이메일로 가입했다면 자주 사용하는 메일함을 확인해주세요. '
          'Apple·Google·Kakao로 가입했다면 로그인 화면 아래의 같은 계정 버튼을 이용해주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
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
