import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/info_box.dart';
import '../../../../shared/widgets/petspace_app_bar.dart';
import '../../../../shared/widgets/petspace_uiux_v3.dart';

class PasswordResetNewPasswordPage extends StatefulWidget {
  final String email;
  final GoTrueClient? authClient;

  const PasswordResetNewPasswordPage({
    super.key,
    required this.email,
    this.authClient,
  });

  @override
  State<PasswordResetNewPasswordPage> createState() =>
      _PasswordResetNewPasswordPageState();
}

class _PasswordResetNewPasswordPageState
    extends State<PasswordResetNewPasswordPage> {
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  String? _errorMessage;

  bool get _isFormReady =>
      _validatePassword(_passwordController.text) == null &&
      _validatePasswordConfirm(_passwordConfirmController.text) == null;
  GoTrueClient get _authClient =>
      widget.authClient ?? Supabase.instance.client.auth;

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final newPassword = _passwordController.text;

      // Supabase에서 비밀번호 업데이트
      await _authClient.updateUser(
        UserAttributes(password: newPassword),
      );

      if (mounted) {
        setState(() => _isLoading = false);
        // 성공 다이얼로그 표시
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 12),
                Text(
                  '비밀번호 변경 완료',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: const Text(
              '비밀번호가 성공적으로 변경되었습니다.\n새 비밀번호로 로그인해주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.5),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _signOutAndGoToLogin();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.actionBase,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '로그인하러 가기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _getErrorMessage(e.message);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '비밀번호 변경 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
        });
      }
    }
  }

  Future<void> _signOutAndGoToLogin() async {
    try {
      await _authClient.signOut();
    } catch (_) {
      // 네트워크 오류가 있어도 완료 다이얼로그에 사용자를 가두지 않는다.
    }
    if (mounted) {
      context.go('/onboarding/login');
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('Password should be at least')) {
      return '비밀번호는 영문과 숫자를 포함해 8자 이상이어야 합니다';
    }
    if (error.contains('New password should be different')) {
      return '이전 비밀번호와 다른 비밀번호를 입력해주세요';
    }
    return '비밀번호 변경에 실패했습니다. 잠시 후 다시 시도해주세요.';
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '비밀번호를 입력해주세요';
    }
    if (value.length < 8 ||
        !RegExp(r'[A-Za-z]').hasMatch(value) ||
        !RegExp(r'\d').hasMatch(value)) {
      return '비밀번호는 영문과 숫자를 포함해 8자 이상이어야 합니다';
    }
    if (value.length > 72) {
      return '비밀번호는 최대 72자까지 가능합니다';
    }
    return null;
  }

  String? _validatePasswordConfirm(String? value) {
    if (value == null || value.isEmpty) {
      return '비밀번호 확인을 입력해주세요';
    }
    if (value != _passwordController.text) {
      return '비밀번호가 일치하지 않습니다';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: PetSpaceAppBar.page(
        title: '새 비밀번호 설정',
        backgroundColor: AppTheme.backgroundColor,
        onBack: _signOutAndGoToLogin,
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
                // 제목
                const Text(
                  '새 비밀번호를\n설정해주세요',
                  style: TextStyle(
                    fontSize: AppTheme.fontTitle,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.brandDeep,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),

                // 설명
                const Text(
                  '영문과 숫자를 포함해 8자 이상 입력해주세요.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // 새 비밀번호 입력
                TextFormField(
                  key: const ValueKey('password-reset-new-password'),
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(
                    labelText: '새 비밀번호',
                    hintText: '영문·숫자 포함 8자 이상',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.lock,
                        color: AppTheme.secondaryTextColor),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: _validatePassword,
                  onChanged: (_) => setState(() => _errorMessage = null),
                ),
                const SizedBox(height: 16),

                // 비밀번호 확인
                TextFormField(
                  key: const ValueKey('password-reset-new-password-confirm'),
                  controller: _passwordConfirmController,
                  obscureText: _obscurePasswordConfirm,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(
                    labelText: '비밀번호 확인',
                    hintText: '비밀번호를 다시 입력하세요',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.lock_outline,
                        color: AppTheme.secondaryTextColor),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePasswordConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePasswordConfirm = !_obscurePasswordConfirm;
                        });
                      },
                    ),
                  ),
                  validator: _validatePasswordConfirm,
                  onChanged: (_) => setState(() => _errorMessage = null),
                  onFieldSubmitted: _isFormReady && !_isLoading
                      ? (_) => _resetPassword()
                      : null,
                ),
                const SizedBox(height: 24),

                // 에러 메시지
                if (_errorMessage != null)
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.tilePastelRose,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.errorColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppTheme.errorColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppTheme.errorColor,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_errorMessage != null) const SizedBox(height: 24),

                // 비밀번호 변경 버튼
                PetSpaceV3PrimaryButton(
                  key: const ValueKey('password-reset-new-submit'),
                  label: '비밀번호 변경',
                  onPressed:
                      _isLoading || !_isFormReady ? null : _resetPassword,
                  loading: _isLoading,
                ),
                const SizedBox(height: 24),

                // 안내 사항
                const InfoBox(
                  title: '비밀번호 안내',
                  items: [
                    '영문과 숫자를 포함해 8자 이상 입력해주세요',
                    '특수문자를 함께 사용하면 더 안전합니다',
                    '이전에 사용한 비밀번호와 다르게 설정해주세요',
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
