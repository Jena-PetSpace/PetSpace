import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import 'terms_detail_page.dart';

class TermsAgreementPage extends StatefulWidget {
  const TermsAgreementPage({super.key});

  @override
  State<TermsAgreementPage> createState() => _TermsAgreementPageState();
}

class _TermsAgreementPageState extends State<TermsAgreementPage> {
  bool _allAgreed = false;
  bool _ageAgreed = false;
  bool _termsAgreed = false;
  bool _privacyAgreed = false;
  bool _marketingAgreed = false;

  bool get _canProceed =>
      _ageAgreed && _termsAgreed && _privacyAgreed;

  void _toggleAll(bool? value) {
    setState(() {
      _allAgreed = value ?? false;
      _ageAgreed = _allAgreed;
      _termsAgreed = _allAgreed;
      _privacyAgreed = _allAgreed;
      _marketingAgreed = _allAgreed;
    });
  }

  void _updateAllAgreedState() {
    setState(() {
      _allAgreed = _ageAgreed && _termsAgreed && _privacyAgreed && _marketingAgreed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            // 로그인 페이지로 돌아가기
            context.go('/onboarding/login');
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // 제목
              const Text(
                '서비스 이용약관에\n동의해주세요.',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 48),

              // 전체 동의
              GestureDetector(
                onTap: () => _toggleAll(!_allAgreed),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _allAgreed ? AppTheme.primaryColor : Colors.grey.shade300,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: _allAgreed ? AppTheme.primaryColor.withValues(alpha: 0.05) : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _allAgreed ? Icons.check_circle : Icons.circle_outlined,
                        color: _allAgreed ? AppTheme.primaryColor : Colors.grey,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        '네, 모두 동의합니다.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 개별 약관 항목들
              _buildAgreementItem(
                isRequired: true,
                label: '만 14세 이상입니다.',
                value: _ageAgreed,
                onChanged: (value) {
                  setState(() {
                    _ageAgreed = value ?? false;
                    _updateAllAgreedState();
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildAgreementItem(
                isRequired: true,
                label: '서비스 이용약관에 동의합니다.',
                value: _termsAgreed,
                onChanged: (value) {
                  setState(() {
                    _termsAgreed = value ?? false;
                    _updateAllAgreedState();
                  });
                },
                hasDetail: true,
                onDetailTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => TermsDetailPage(
                        title: '서비스 이용약관',
                        content: '서비스 이용약관 내용이 여기에 표시됩니다.\n\n'
                            '추후 실제 약관 내용으로 업데이트될 예정입니다.',
                        onAgree: () {
                          setState(() {
                            _termsAgreed = true;
                            _updateAllAgreedState();
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildAgreementItem(
                isRequired: true,
                label: '개인정보 수집 및 이용에 동의합니다.',
                value: _privacyAgreed,
                onChanged: (value) {
                  setState(() {
                    _privacyAgreed = value ?? false;
                    _updateAllAgreedState();
                  });
                },
                hasDetail: true,
                onDetailTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => TermsDetailPage(
                        title: '개인정보 처리방침',
                        content: '개인정보 처리방침 내용이 여기에 표시됩니다.\n\n'
                            '추후 실제 개인정보 처리방침 내용으로 업데이트될 예정입니다.',
                        onAgree: () {
                          setState(() {
                            _privacyAgreed = true;
                            _updateAllAgreedState();
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildAgreementItem(
                isRequired: false,
                label: '마케팅 활용 및 정보 수신에 동의합니다.',
                value: _marketingAgreed,
                onChanged: (value) {
                  setState(() {
                    _marketingAgreed = value ?? false;
                    _updateAllAgreedState();
                  });
                },
                hasDetail: true,
                onDetailTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => TermsDetailPage(
                        title: '마케팅 정보 수신 동의',
                        content: '마케팅 정보 수신 동의 내용이 여기에 표시됩니다.\n\n'
                            '추후 실제 마케팅 동의 내용으로 업데이트될 예정입니다.',
                        onAgree: () {
                          setState(() {
                            _marketingAgreed = true;
                            _updateAllAgreedState();
                          });
                        },
                      ),
                    ),
                  );
                },
              ),

              const Spacer(),

              // 안내 문구
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  child: Text(
                    '\'선택\' 항목에 동의하지 않아도 서비스 이용이 가능합니다.\n개인정보 수집 및 이용에 대한 동의를 거부할 권리가 있으나,\n동의 거부시 회원제 서비스 이용이 제한됩니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              // 다음 버튼
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _canProceed
                      ? () {
                          // 프로필 설정 페이지로 이동
                          context.go('/onboarding/profile');
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canProceed ? AppTheme.primaryColor : Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: const Text(
                    '다음',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgreementItem({
    required bool isRequired,
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
    bool hasDetail = false,
    VoidCallback? onDetailTap,
  }) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => onChanged(!value),
          child: Row(
            children: [
              Icon(
                value ? Icons.check_circle : Icons.circle_outlined,
                color: value ? AppTheme.accentColor : Colors.grey,
                size: 24,
              ),
              const SizedBox(width: 12),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  children: [
                    TextSpan(
                      text: isRequired ? '(필수) ' : '(선택) ',
                      style: TextStyle(
                        color: isRequired ? AppTheme.highlightColor : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: label),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (hasDetail) ...[
          const Spacer(),
          GestureDetector(
            onTap: onDetailTap,
            child: const Text(
              '보기',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.secondaryColor,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
