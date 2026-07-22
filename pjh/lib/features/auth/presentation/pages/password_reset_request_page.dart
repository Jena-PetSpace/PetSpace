import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_app_bar.dart';

class PasswordResetRequestPage extends StatefulWidget {
  const PasswordResetRequestPage({super.key});

  @override
  State<PasswordResetRequestPage> createState() =>
      _PasswordResetRequestPageState();
}

class _PasswordResetRequestPageState extends State<PasswordResetRequestPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

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

      // Supabase는 등록되지 않은 이메일에도 동일하게 응답한다. 계정 존재 여부를
      // 화면 문구나 분기에서 추측할 수 없도록 성공·일반 실패 안내도 중립적으로 유지한다.
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: null,
      );

      if (mounted) {
        context.go(
          '/auth/password-reset/verify?email=${Uri.encodeComponent(email)}',
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _getErrorMessage(error.message);
        });
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

  String _getErrorMessage(String error) {
    if (error.toLowerCase().contains('rate limit') ||
        error.toLowerCase().contains('too many')) {
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
        backgroundColor: AppTheme.surfaceColor,
        onBack: () => context.go('/onboarding/login'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppTheme.actionContainer,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          child: const Icon(
                            Icons.lock_reset_rounded,
                            color: AppTheme.brandDeep,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
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
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: '이메일',
                          hintText: 'jena@example.com',
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) return '이메일을 입력해주세요.';
                          if (!RegExp(
                            r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$',
                          ).hasMatch(email)) {
                            return '올바른 이메일 형식으로 입력해주세요.';
                          }
                          return null;
                        },
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withValues(alpha: .08),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSm),
                              border: Border.all(
                                color:
                                    AppTheme.errorColor.withValues(alpha: .24),
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
            Container(
              padding: EdgeInsets.fromLTRB(
                24,
                12,
                24,
                12 + MediaQuery.paddingOf(context).bottom,
              ),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceColor,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  key: const ValueKey('password-reset-submit'),
                  onPressed: _isLoading ? null : _sendResetCode,
                  child: _isLoading
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('인증 코드 받기'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
