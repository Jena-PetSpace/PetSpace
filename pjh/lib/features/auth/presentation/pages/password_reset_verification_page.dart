import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/info_box.dart';
import '../../../../shared/widgets/petspace_app_bar.dart';
import '../../../../shared/widgets/petspace_uiux_v3.dart';

class PasswordResetVerificationPage extends StatefulWidget {
  final String email;
  final GoTrueClient? authClient;
  final int initialResendCountdown;

  const PasswordResetVerificationPage({
    super.key,
    required this.email,
    this.authClient,
    this.initialResendCountdown = 60,
  });

  @override
  State<PasswordResetVerificationPage> createState() =>
      _PasswordResetVerificationPageState();
}

class _PasswordResetVerificationPageState
    extends State<PasswordResetVerificationPage> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final TextEditingController _accessibleCodeController =
      TextEditingController();
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  // KeyboardListener 전용 FocusNode (dispose 관리)
  final List<FocusNode> _keyboardListenerNodes =
      List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  bool _isResending = false;
  late int _resendCountdown;
  Timer? _countdownTimer;
  String? _errorMessage;
  bool get _isCodeComplete =>
      _controllers.every((controller) => controller.text.isNotEmpty);
  GoTrueClient get _authClient =>
      widget.authClient ?? Supabase.instance.client.auth;

  @override
  void initState() {
    super.initState();
    _resendCountdown = widget.initialResendCountdown;
    // 카운트다운 시작 (request 페이지에서 이미 발송했으므로)
    _startCountdown();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    _accessibleCodeController.dispose();
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    for (var node in _keyboardListenerNodes) {
      node.dispose();
    }
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _resendOtp() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      await _authClient.signInWithOtp(
        email: widget.email,
        emailRedirectTo: null,
        shouldCreateUser: false,
      );

      _completeResend();
    } on AuthException catch (error) {
      if (!mounted) return;
      final normalized = error.message.toLowerCase();
      final isRateLimited =
          normalized.contains('rate limit') || normalized.contains('too many');
      if (isRateLimited) {
        setState(() {
          _isResending = false;
          _errorMessage = '요청이 많아요. 잠시 후 다시 시도해주세요.';
        });
      } else {
        // 미등록 주소 응답은 재발송 성공과 동일하게 처리해 계정 존재 여부를
        // 화면에서 추측할 수 없게 한다.
        _completeResend();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isResending = false;
          _errorMessage = '인증 코드 재발송에 실패했습니다. 잠시 후 다시 시도해주세요.';
        });
      }
    }
  }

  void _completeResend() {
    if (!mounted) return;
    setState(() {
      _isResending = false;
      _resendCountdown = 60;
    });
    _startCountdown();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('인증 코드가 재발송되었습니다'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  Future<void> _verifyOtp() async {
    final code = _controllers.map((c) => c.text).join();

    if (code.length != 6) {
      setState(() {
        _errorMessage = '6자리 인증 코드를 모두 입력해주세요';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      // OTP 검증 - signInWithOtp로 보낸 코드는 magiclink 타입
      final response = await _authClient.verifyOTP(
        token: code,
        type: OtpType.magiclink,
        email: widget.email,
      );

      if (mounted) {
        if (response.user != null) {
          // 인증 성공 - 새 비밀번호 설정 페이지로 이동
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('인증이 완료되었습니다'),
              backgroundColor: AppTheme.successColor,
            ),
          );

          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            context.go(
              '/auth/password-reset/new-password?email=${Uri.encodeComponent(widget.email)}',
            );
          }
        } else {
          setState(() {
            _isVerifying = false;
            _errorMessage = '인증을 완료하지 못했어요. 코드를 확인하고 다시 시도해주세요.';
          });
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = e.message == 'Token has expired or is invalid'
              ? '인증 코드가 만료되었거나 올바르지 않습니다'
              : '인증을 완료하지 못했어요. 코드를 확인하고 다시 시도해주세요.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = '인증 처리 중 오류가 발생했습니다. 다시 시도해주세요.';
        });
      }
    }
  }

  void _onCodeChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() => _errorMessage = null);
  }

  void _onAccessibleCodeChanged(String value) {
    for (var index = 0; index < _controllers.length; index++) {
      _controllers[index].text = index < value.length ? value[index] : '';
    }
    setState(() => _errorMessage = null);
  }

  Future<void> _signOutAndGo(String route) async {
    try {
      await _authClient.signOut();
    } catch (_) {
      // 로컬 세션 정리가 실패해도 사용자가 재설정 흐름에 갇히지 않게 한다.
    }
    if (mounted) {
      context.go(route);
    }
  }

  void _onKeyPressed(int index, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_controllers[index].text.isEmpty && index > 0) {
          _focusNodes[index - 1].requestFocus();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: PetSpaceAppBar.page(
        title: '인증 코드 확인',
        backgroundColor: AppTheme.backgroundColor,
        onBack: () => _signOutAndGo('/auth/password-reset/request'),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 제목
              const Text(
                '인증 코드 확인',
                style: TextStyle(
                  fontSize: AppTheme.fontTitle,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.brandDeep,
                ),
              ),
              const SizedBox(height: 10),

              // 설명
              Text(
                '${widget.email}로\n발송된 6자리 인증 코드를 입력해주세요',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // 6자리 OTP 입력 필드
              LayoutBuilder(
                builder: (context, constraints) {
                  final useSingleCodeField =
                      MediaQuery.textScalerOf(context).scale(22) >= 36 ||
                          constraints.maxWidth < 300;
                  if (useSingleCodeField) {
                    return Semantics(
                      label: '6자리 인증 코드',
                      textField: true,
                      child: TextField(
                        key: const ValueKey(
                          'password-reset-code-accessible',
                        ),
                        controller: _accessibleCodeController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        maxLength: 6,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 10,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          labelText: '6자리 인증 코드',
                          hintText: '000000',
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: _onAccessibleCodeChanged,
                        onSubmitted: _isCodeComplete && !_isVerifying
                            ? (_) => _verifyOtp()
                            : null,
                      ),
                    );
                  }

                  const gap = 8.0;
                  final available = (constraints.maxWidth - (gap * 5)) / 6;
                  final fieldWidth = available.clamp(36.0, 48.0).toDouble();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      return ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: fieldWidth,
                          maxWidth: fieldWidth,
                          minHeight: 60,
                        ),
                        child: Semantics(
                          label: '인증 코드 ${index + 1}번째 자리',
                          textField: true,
                          child: KeyboardListener(
                            focusNode: _keyboardListenerNodes[index],
                            onKeyEvent: (event) => _onKeyPressed(index, event),
                            child: TextField(
                              key: ValueKey('password-reset-code-$index'),
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              textInputAction: index == 5
                                  ? TextInputAction.done
                                  : TextInputAction.next,
                              autofillHints: index == 0
                                  ? const [AutofillHints.oneTimeCode]
                                  : null,
                              maxLength: 1,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (value) =>
                                  _onCodeChanged(index, value),
                              onSubmitted:
                                  index == 5 && _isCodeComplete && !_isVerifying
                                      ? (_) => _verifyOtp()
                                      : null,
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
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

              // 인증 버튼
              PetSpaceV3PrimaryButton(
                key: const ValueKey('password-reset-verify-submit'),
                label: '인증하기',
                onPressed: _isVerifying || !_isCodeComplete ? null : _verifyOtp,
                loading: _isVerifying,
              ),
              const SizedBox(height: 24),

              // 재발송 버튼
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  const Text(
                    '인증 코드를 받지 못하셨나요?',
                    style: TextStyle(
                      color: AppTheme.neutral600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: (_isResending || _resendCountdown > 0)
                        ? null
                        : _resendOtp,
                    child: Text(
                      _resendCountdown > 0 ? '재발송 ($_resendCountdown초)' : '재발송',
                      style: TextStyle(
                        color: (_isResending || _resendCountdown > 0)
                            ? AppTheme.neutral500
                            : AppTheme.accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 안내 사항
              const InfoBox(
                title: '인증 안내',
                items: [
                  '인증 코드는 10분간 유효합니다',
                  '이메일이 오지 않으면 스팸함을 확인해주세요',
                  '재발송은 60초 후에 가능합니다',
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
