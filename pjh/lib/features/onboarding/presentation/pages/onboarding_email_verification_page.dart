import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/icon_badge_circle.dart';
import '../../../../shared/widgets/info_box.dart';
import '../../../../shared/widgets/petspace_app_bar.dart';

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
  // KeyboardListener 전용 FocusNode (dispose 관리)
  final List<FocusNode> _keyboardListenerNodes =
      List.generate(6, (_) => FocusNode());

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
    for (var node in _keyboardListenerNodes) {
      node.dispose();
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
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );

      if (mounted) {
        setState(() {
          _isResending = false;
          _resendCountdown = 60; // 60초 대기
        });

        // 카운트다운 시작
        _startCountdown();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('인증 코드를 다시 보냈어요.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isResending = false;
          _errorMessage = '인증 코드를 다시 보내지 못했어요. 잠시 후 다시 시도해주세요.';
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
              content: Text('이메일 인증이 완료됐어요. 이제 로그인해주세요.'),
              backgroundColor: AppTheme.successColor,
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
              : '인증을 완료하지 못했어요. 코드를 확인하고 다시 시도해주세요.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = '인증을 완료하지 못했어요. 잠시 후 다시 시도해주세요.';
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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: PetSpaceAppBar.page(
        title: '이메일 인증',
        backgroundColor: theme.scaffoldBackgroundColor,
        onBack: () async {
          // 미완료 인증 상태의 session을 정리한 뒤 로그인 페이지로 이동
          try {
            await Supabase.instance.client.auth.signOut();
          } catch (_) {}
          if (context.mounted) {
            context.go('/onboarding/login');
          }
        },
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24.w, 32.h, 24.w, 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: IconBadgeCircle(
                  icon: Icons.mark_email_read_outlined,
                  size: 56,
                  tone: BadgeTone.feature,
                ),
              ),
              SizedBox(height: 24.h),

              // 제목
              Text(
                '이메일 인증',
                style: TextStyle(
                  fontSize: AppTheme.fontTitle.sp,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 10.h),

              // 설명
              Text(
                '${widget.email}로\n발송된 6자리 인증 코드를 입력해주세요',
                style: TextStyle(
                  fontSize: AppTheme.fontBody.sp,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 32.h),

              // 6자리 OTP 입력 필드
              _buildCodeFields(),
              SizedBox(height: 24.h),

              // 에러 메시지
              if (_errorMessage != null)
                Container(
                  key: const Key('email_verification_error'),
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm.r),
                    border: Border.all(
                        color: AppTheme.errorColor.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.errorColor, size: 20),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: AppTheme.errorColor,
                            fontSize: AppTheme.fontCaption.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_errorMessage != null) SizedBox(height: 24.h),

              // 인증 버튼
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  key: const Key('email_verification_submit'),
                  onPressed: _isVerifying ? null : _verifyOtp,
                  child: _isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('인증하기'),
                ),
              ),
              SizedBox(height: 24.h),

              // 재발송 버튼
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4.w,
                children: [
                  Text(
                    '인증 코드를 받지 못하셨나요?',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: AppTheme.fontCaption.sp,
                    ),
                  ),
                  TextButton(
                    onPressed: (_isResending || _resendCountdown > 0)
                        ? null
                        : _sendOtp,
                    child: Text(
                      _resendCountdown > 0 ? '재발송 ($_resendCountdown초)' : '재발송',
                      style: TextStyle(
                        color: (_isResending || _resendCountdown > 0)
                            ? theme.colorScheme.onSurfaceVariant
                            : (theme.brightness == Brightness.dark
                                ? theme.colorScheme.primary
                                : AppTheme.actionBase),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),

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

  Widget _buildCodeFields() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        isDark ? theme.colorScheme.outlineVariant : AppTheme.border;
    final focusColor = isDark ? theme.colorScheme.primary : AppTheme.actionBase;
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 6.w;
        final available = constraints.maxWidth - (gap * 5);
        final fieldWidth = (available / 6).clamp(36.0, 48.0);
        return Row(
          key: const Key('email_verification_code_row'),
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return Semantics(
              label: '인증 코드 ${index + 1}번째 자리',
              textField: true,
              child: SizedBox(
                width: fieldWidth,
                height: 56,
                child: KeyboardListener(
                  focusNode: _keyboardListenerNodes[index],
                  onKeyEvent: (event) => _onKeyPressed(index, event),
                  child: TextField(
                    key: ValueKey('email-verification-digit-$index'),
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    enabled: !_isVerifying,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    textInputAction: index == 5
                        ? TextInputAction.done
                        : TextInputAction.next,
                    maxLength: 1,
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: EdgeInsets.symmetric(vertical: 14.h),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm.r),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm.r),
                        borderSide: BorderSide(color: focusColor, width: 1.5),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm.r),
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) => _onCodeChanged(index, value),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
