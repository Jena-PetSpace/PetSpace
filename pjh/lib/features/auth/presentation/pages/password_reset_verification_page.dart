import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/themes/app_theme.dart';

class PasswordResetVerificationPage extends StatefulWidget {
  final String email;

  const PasswordResetVerificationPage({
    super.key,
    required this.email,
  });

  @override
  State<PasswordResetVerificationPage> createState() =>
      _PasswordResetVerificationPageState();
}

class _PasswordResetVerificationPageState
    extends State<PasswordResetVerificationPage> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  bool _isResending = false;
  int _resendCountdown = 60; // 초기 60초 (페이지 로드 시 자동 발송됨)
  Timer? _countdownTimer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 카운트다운 시작 (request 페이지에서 이미 발송했으므로)
    _startCountdown();
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
      await Supabase.instance.client.auth.signInWithOtp(
        email: widget.email,
        emailRedirectTo: null,
      );

      if (mounted) {
        setState(() {
          _isResending = false;
          _resendCountdown = 60;
        });

        _startCountdown();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('인증 코드가 재발송되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isResending = false;
          _errorMessage = '코드 재발송 실패: ${e.toString()}';
        });
      }
    }
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
      final response = await Supabase.instance.client.auth.verifyOTP(
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
              backgroundColor: Colors.green,
            ),
          );

          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            context.go(
              '/auth/password-reset/new-password?email=${Uri.encodeComponent(widget.email)}',
            );
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
      _focusNodes[index + 1].requestFocus();
    }

    final allFilled = _controllers.every((c) => c.text.isNotEmpty);
    if (allFilled && !_isVerifying) {
      _verifyOtp();
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () async {
            // 로그아웃 후 비밀번호 찾기 페이지로 이동
            await Supabase.instance.client.auth.signOut();
            if (context.mounted) {
              context.go('/auth/password-reset/request');
            }
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
                '인증 코드 확인',
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                        : _resendOtp,
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
