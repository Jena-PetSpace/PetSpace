import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../../core/error/error_messages.dart';
import '../../../../core/utils/auth_input_validators.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_uiux_v3.dart';
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
  static final Future<Uint8List> _googleSignInButtonPng = rootBundle
      .loadString('assets/images/google_sign_in_round_light.png.b64')
      .then(
        (encoded) => base64Decode(encoded.replaceAll(RegExp(r'\s+'), '')),
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
                      validator: AuthInputValidators.validateEmail,
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
                    PetSpaceV3PrimaryButton(
                      key: const ValueKey('email-auth-submit'),
                      label: _isLogin ? '로그인하기' : '회원가입 계속하기',
                      onPressed: _isPending ? null : _submitEmail,
                      loading: _pendingProvider == 'Email',
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
                    // 로그인/회원가입 전환 시 아이디는 유지해 재입력을 줄이고,
                    // 비밀번호 계열만 새 인증 흐름에 남지 않도록 초기화한다.
                    _passwordController.clear();
                    _passwordConfirmController.clear();
                    _rateLimitDuration = null;
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
      'Kakao' => '카카오 로그인',
      _ => 'Apple로 로그인하기',
    };
    final (Color background, Color foreground, Color border, Widget icon) =
        switch (provider) {
      'Apple' => (
          isDark ? Colors.white : Colors.black,
          isDark ? Colors.black : Colors.white,
          Colors.transparent,
          SizedBox.square(
            key: const Key('apple-login-brand-icon'),
            dimension: 28,
            child: CustomPaint(
              painter: AppleLogoPainter(
                color: isDark ? Colors.black : Colors.white,
              ),
            ),
          ),
        ),
      'Google' => (
          Colors.transparent,
          AppTheme.actionBase,
          Colors.transparent,
          SizedBox.square(
            key: const Key('google-login-brand-icon'),
            dimension: 58,
            child: FutureBuilder<Uint8List>(
              future: _googleSignInButtonPng,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }
                return Image.memory(
                  snapshot.requireData,
                  width: 58,
                  height: 58,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.high,
                );
              },
            ),
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
      excludeSemantics: true,
      onTap: enabled ? () => _beginProvider(provider) : null,
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
                        key: ValueKey('social-login-progress-$provider'),
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
    );
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return '비밀번호를 입력해주세요.';
    if (password.length < 8 ||
        !RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password)) {
      return '영문과 숫자를 포함해 8자 이상 입력해주세요.';
    }
    if (password.length > 72) return '비밀번호는 최대 72자까지 입력할 수 있어요.';
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
