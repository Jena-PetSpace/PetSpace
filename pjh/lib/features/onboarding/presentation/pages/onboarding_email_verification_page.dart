import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/themes/app_theme.dart';

class OnboardingEmailVerificationPage extends StatefulWidget {
  final String email;

  const OnboardingEmailVerificationPage({
    super.key,
    required this.email,
  });

  @override
  State<OnboardingEmailVerificationPage> createState() =>
      _OnboardingEmailVerificationPageState();
}

class _OnboardingEmailVerificationPageState
    extends State<OnboardingEmailVerificationPage> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  bool _isResending = false;
  int _resendCountdown = 0;
  Timer? _countdownTimer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 회원가입에서 이미 OTP를 발송했으므로 여기서는 발송하지 않음
    // 단지 60초 카운트다운만 시작
    _resendCountdown = 60;
    _startCountdown();
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

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      // 이메일 인증 재발송
      // signup 타입으로 재발송 (확인되지 않은 새 사용자용)
      final response = await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );

      developer.log('재발송 성공: ${response.toString()}', name: 'EmailVerification');

      if (mounted) {
        setState(() {
          _isResending = false;
          _resendCountdown = 60; // 60초 대기
        });

        // 카운트다운 시작
        _startCountdown();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('인증 코드가 이메일로 재발송되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      developer.log('재발송 실패: $e', name: 'EmailVerification', error: e);
      if (mounted) {
        setState(() {
          _isResending = false;
          _errorMessage = '코드 재발송 실패: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    // 6자리 코드 조합
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
      // OTP 검증 - signUp으로 보낸 코드는 signup 타입
      final response = await Supabase.instance.client.auth.verifyOTP(
        token: code,
        type: OtpType.signup,
        email: widget.email,
      );

      if (mounted) {
        if (response.user != null) {
          // 인증 성공 - 로그아웃 후 로그인 페이지로 이동
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이메일 인증이 완료되었습니다!\n이제 로그인할 수 있습니다.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // 인증 완료 후 로그아웃 (이용약관 페이지로 가지 않도록)
          await Supabase.instance.client.auth.signOut();

          // 로그인 페이지로 이동
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            context.go('/onboarding/login');
          }
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = e.message == 'Token has expired or is invalid'
              ? '인증 코드가 만료되었거나 올바르지 않습니다'
              : '인증 실패: ${e.message}';
        });

        // 입력 필드 초기화
        for (var controller in _controllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = '인증 실패: ${e.toString()}';
        });
      }
    }
  }

  void _onCodeChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      // 다음 필드로 자동 이동
      _focusNodes[index + 1].requestFocus();
    }

    // 6자리 모두 입력되면 자동 검증
    final allFilled = _controllers.every((c) => c.text.isNotEmpty);
    if (allFilled && !_isVerifying) {
      _verifyOtp();
    }
  }

  void _onKeyPressed(int index, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_controllers[index].text.isEmpty && index > 0) {
          // 현재 필드가 비어있고 백스페이스 누르면 이전 필드로 이동
          _focusNodes[index - 1].requestFocus();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            context.go('/onboarding/login');
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // 이메일 아이콘
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_read_outlined,
                    size: 50,
                    color: AppTheme.accentColor,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 제목
              const Text(
                '이메일 인증',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // 설명
              Text(
                '${widget.email}로\n발송된 6자리 인증 코드를 입력해주세요',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // 6자리 OTP 입력 필드
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 48,
                    height: 60,
                    child: KeyboardListener(
                      focusNode: FocusNode(),
                      onKeyEvent: (event) => _onKeyPressed(index, event),
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppTheme.accentColor,
                              width: 2,
                            ),
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) => _onCodeChanged(index, value),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // 에러 메시지
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_errorMessage != null) const SizedBox(height: 24),

              // 인증 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '인증하기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // 재발송 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '인증 코드를 받지 못하셨나요?',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: (_isResending || _resendCountdown > 0)
                        ? null
                        : _sendOtp,
                    child: Text(
                      _resendCountdown > 0
                          ? '재발송 ($_resendCountdown초)'
                          : '재발송',
                      style: TextStyle(
                        color: (_isResending || _resendCountdown > 0)
                            ? Colors.grey
                            : AppTheme.accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 안내 사항
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.subColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.subColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppTheme.accentColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '인증 안내',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem('인증 코드는 10분간 유효합니다'),
                    _buildInfoItem('이메일이 오지 않으면 스팸함을 확인해주세요'),
                    _buildInfoItem('재발송은 60초 후에 가능합니다'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              color: AppTheme.secondaryColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
