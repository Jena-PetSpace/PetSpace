import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/auth_input_validators.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_app_bar.dart';
import '../../../../shared/widgets/petspace_bottom_action_bar.dart';
import '../../../../shared/widgets/petspace_uiux_v3.dart';

class PasswordResetRequestPage extends StatefulWidget {
  final GoTrueClient? authClient;

  const PasswordResetRequestPage({
    super.key,
    this.authClient,
  });

  @override
  State<PasswordResetRequestPage> createState() =>
      _PasswordResetRequestPageState();
}

class _PasswordResetRequestPageState extends State<PasswordResetRequestPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  bool get _canSendResetCode =>
      AuthInputValidators.isValidEmail(_emailController.text);
  GoTrueClient get _authClient =>
      widget.authClient ?? Supabase.instance.client.auth;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();

      // 계정 생성은 금지하고, 계정 존재 여부를 화면 문구나 분기에서 추측할 수
      // 없도록 성공·일반 실패 안내를 같은 중립 흐름으로 유지한다.
      await _authClient.signInWithOtp(
        email: email,
        emailRedirectTo: null,
        shouldCreateUser: false,
      );

      if (mounted) {
        _goToVerification(email);
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      if (_isRateLimitError(error.message)) {
        setState(() {
          _isLoading = false;
          _errorMessage = _getErrorMessage(error.message);
        });
      } else {
        // 미등록 주소의 Supabase 응답도 성공과 같은 화면으로 보내 계정 존재
        // 여부를 노출하지 않는다. 이 경우 코드는 검증되지 않는다.
        _goToVerification(_emailController.text.trim());
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '안내를 보내지 못했어요. 잠시 후 다시 시도해주세요.';
        });
      }
    }
  }

  void _goToVerification(String email) {
    context.go(
      '/auth/password-reset/verify?email=${Uri.encodeComponent(email)}',
    );
  }

  bool _isRateLimitError(String error) {
    final normalized = error.toLowerCase();
    return normalized.contains('rate limit') || normalized.contains('too many');
  }

  String _getErrorMessage(String error) {
    if (_isRateLimitError(error)) {
      return '요청이 많아 잠시 쉬어가야 해요. 잠시 후 다시 시도해주세요.';
    }
    return '입력한 주소로 안내를 보내지 못했어요. 잠시 후 다시 시도해주세요.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: PetSpaceAppBar.page(
        title: '비밀번호 찾기',
        backgroundColor: AppTheme.backgroundColor,
        onBack: () => context.go('/onboarding/login'),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '비밀번호 재설정 안내를\n보내드릴게요',
                  style: TextStyle(
                    color: AppTheme.brandDeep,
                    fontSize: AppTheme.fontTitle,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '계정에 사용한 이메일을 입력해주세요. 확인할 수 있는 경우 6자리 인증 코드를 보내드려요.',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: AppTheme.fontBody,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  key: const ValueKey('password-reset-email'),
                  controller: _emailController,
                  enabled: !_isLoading,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: '이메일',
                    hintText: 'jena@example.com',
                  ),
                  validator: AuthInputValidators.validateEmail,
                  onChanged: (_) {
                    setState(() => _errorMessage = null);
                  },
                  onFieldSubmitted: _canSendResetCode && !_isLoading
                      ? (_) => _sendResetCode()
                      : null,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(
                          color: AppTheme.errorColor.withValues(alpha: .24),
                        ),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: AppTheme.fontCaption,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: AppTheme.textMuted,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '보안을 위해 해당 이메일의 가입 여부는 화면에 표시하지 않아요.',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: AppTheme.fontCaption,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: PetSpaceBottomActionBar(
        minimum: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        child: PetSpaceV3PrimaryButton(
          key: const ValueKey('password-reset-submit'),
          label: '인증 코드 받기',
          onPressed: _isLoading || !_canSendResetCode ? null : _sendResetCode,
          loading: _isLoading,
        ),
      ),
    );
  }
}
