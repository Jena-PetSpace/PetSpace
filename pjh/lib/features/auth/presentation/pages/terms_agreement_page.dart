import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../../core/constants/legal_documents.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../config/injection_container.dart' as di;
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
  bool _locationAgreed = false; // 위치기반 서비스 약관 (선택)
  bool _marketingAgreed = false;
  bool _isSaving = false;

  // 필수: 만14세 + 이용약관 + 개인정보. (위치·마케팅은 선택)
  bool get _canProceed => _ageAgreed && _termsAgreed && _privacyAgreed;

  void _toggleAll(bool? value) {
    setState(() {
      _allAgreed = value ?? false;
      _ageAgreed = _allAgreed;
      _termsAgreed = _allAgreed;
      _privacyAgreed = _allAgreed;
      _locationAgreed = _allAgreed;
      _marketingAgreed = _allAgreed;
    });
  }

  void _updateAllAgreedState() {
    setState(() {
      _allAgreed = _ageAgreed &&
          _termsAgreed &&
          _privacyAgreed &&
          _locationAgreed &&
          _marketingAgreed;
    });
  }

  /// 동의 기록을 DB에 저장한 뒤 다음 단계로 이동 (세션4 — 동의 증명)
  Future<void> _onProceed() async {
    if (!_canProceed || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await di.sl<ProfileService>().saveConsents(
            termsAgreed: _termsAgreed,
            privacyAgreed: _privacyAgreed,
            locationAgreed: _locationAgreed,
            marketingAgreed: _marketingAgreed,
            termsVersion: LegalDocuments.serviceTermsVersion,
            privacyVersion: LegalDocuments.privacyPolicyVersion,
            locationVersion: LegalDocuments.locationTermsVersion,
            marketingVersion: LegalDocuments.marketingConsentVersion,
          );
    } catch (_) {
      // 동의 기록 저장 실패해도 온보딩 진행은 막지 않는다(다음 로그인/설정에서 재기록 가능).
      // 단, 사용자에게는 별도 에러를 띄우지 않고 조용히 진행한다.
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
    if (mounted) {
      context.go('/onboarding/profile');
    }
  }

  void _openDetail(String title, String content, VoidCallback onAgree) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TermsDetailPage(
          title: title,
          content: content,
          onAgree: onAgree,
        ),
      ),
    );
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
              const Text(
                '서비스 이용약관에\n동의해주세요.',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 40),

              // 전체 동의
              GestureDetector(
                onTap: () => _toggleAll(!_allAgreed),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _allAgreed
                          ? AppTheme.primaryColor
                          : Colors.grey.shade300,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: _allAgreed
                        ? AppTheme.primaryColor.withValues(alpha: 0.05)
                        : Colors.transparent,
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

              // 개별 약관 항목들 (스크롤 — 항목이 5개로 늘어 화면 넘침 방지)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                        onDetailTap: () => _openDetail(
                          '서비스 이용약관',
                          LegalDocuments.serviceTerms,
                          () {
                            setState(() {
                              _termsAgreed = true;
                              _updateAllAgreedState();
                            });
                          },
                        ),
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
                        onDetailTap: () => _openDetail(
                          '개인정보 처리방침',
                          LegalDocuments.privacyPolicy,
                          () {
                            setState(() {
                              _privacyAgreed = true;
                              _updateAllAgreedState();
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildAgreementItem(
                        isRequired: false,
                        label: '위치기반 서비스 이용에 동의합니다.',
                        value: _locationAgreed,
                        onChanged: (value) {
                          setState(() {
                            _locationAgreed = value ?? false;
                            _updateAllAgreedState();
                          });
                        },
                        hasDetail: true,
                        onDetailTap: () => _openDetail(
                          '위치기반 서비스 이용약관',
                          LegalDocuments.locationTerms,
                          () {
                            setState(() {
                              _locationAgreed = true;
                              _updateAllAgreedState();
                            });
                          },
                        ),
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
                        onDetailTap: () => _openDetail(
                          '마케팅 정보 수신 동의',
                          LegalDocuments.marketingConsent,
                          () {
                            setState(() {
                              _marketingAgreed = true;
                              _updateAllAgreedState();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 안내 문구
              Center(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
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
                  onPressed: (_canProceed && !_isSaving) ? _onProceed : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canProceed
                        ? AppTheme.primaryColor
                        : Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
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
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: Row(
              children: [
                Icon(
                  value ? Icons.check_circle : Icons.circle_outlined,
                  color: value ? AppTheme.accentColor : Colors.grey,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      children: [
                        TextSpan(
                          text: isRequired ? '(필수) ' : '(선택) ',
                          style: TextStyle(
                            color: isRequired
                                ? AppTheme.highlightColor
                                : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: label),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasDetail) ...[
          const SizedBox(width: 8),
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
