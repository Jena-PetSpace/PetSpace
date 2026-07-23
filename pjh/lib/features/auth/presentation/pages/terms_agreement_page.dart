import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_app_bar.dart';
import '../../../../core/constants/legal_documents.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../config/injection_container.dart' as di;
import 'terms_detail_page.dart';

typedef ConsentSaver = Future<void> Function({
  required bool termsAgreed,
  required bool privacyAgreed,
  required bool locationAgreed,
  required bool marketingAgreed,
  required String termsVersion,
  required String privacyVersion,
  required String locationVersion,
  required String marketingVersion,
});

class TermsAgreementPage extends StatefulWidget {
  final ConsentSaver? saveConsents;

  const TermsAgreementPage({super.key, this.saveConsents});

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
  String? _saveError;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
    _allAgreed = _ageAgreed &&
        _termsAgreed &&
        _privacyAgreed &&
        _locationAgreed &&
        _marketingAgreed;
  }

  /// 동의 기록을 DB에 저장한 뒤 다음 단계로 이동 (세션4 — 동의 증명)
  Future<void> _onProceed() async {
    if (!_canProceed || _isSaving) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      final saveConsents =
          widget.saveConsents ?? di.sl<ProfileService>().saveConsents;
      await saveConsents(
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
      if (mounted) {
        setState(() {
          _saveError = '동의 내용을 저장하지 못했어요';
        });
      }
      return;
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
      backgroundColor: AppTheme.backgroundColor,
      appBar: PetSpaceAppBar.steps(
        title: '약관 동의',
        step: 1,
        totalSteps: 3,
        backgroundColor: AppTheme.backgroundColor,
        onBack: () => context.go('/onboarding/login'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                '안심하고 사용할 수 있도록',
                style: TextStyle(
                  fontSize: AppTheme.fontTitle,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                  color: AppTheme.brandDeep,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '필수 약관과 선택 항목을 구분해 확인해주세요.',
                style: TextStyle(
                  fontSize: AppTheme.fontBody,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 28),

              // 전체 동의
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isSaving ? null : () => _toggleAll(!_allAgreed),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _allAgreed
                            ? AppTheme.primaryColor
                            : AppTheme.neutral300,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      color: _allAgreed
                          ? AppTheme.primaryColor.withValues(alpha: 0.05)
                          : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _allAgreed
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: _allAgreed
                              ? AppTheme.primaryColor
                              : AppTheme.neutral500,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '전체 동의',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 개별 약관 항목들 (스크롤 — 항목이 5개로 늘어 화면 넘침 방지)
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
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
                      if (_saveError != null) ...[
                        const SizedBox(height: 24),
                        _buildSaveError(),
                      ],
                    ],
                  ),
                ),
              ),

              // 안내 문구
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  child: Text(
                    '\'선택\' 항목에 동의하지 않아도 서비스 이용이 가능합니다.\n개인정보 수집 및 이용에 대한 동의를 거부할 권리가 있으나,\n동의 거부시 회원제 서비스 이용이 제한됩니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.neutral600,
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
                        : AppTheme.neutral300,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: AppTheme.neutral300,
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
                          '동의하고 계속',
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

  Widget _buildSaveError() {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withValues(alpha: 0.08),
          border: Border.all(
            color: AppTheme.errorColor.withValues(alpha: 0.28),
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _saveError!,
              style: const TextStyle(
                color: AppTheme.errorColor,
                fontSize: AppTheme.fontBody,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '선택한 항목은 그대로 유지돼요. 네트워크 상태를 확인한 뒤 다시 시도해주세요.',
              style: TextStyle(
                color: AppTheme.textBody,
                fontSize: AppTheme.fontCaption,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isSaving ? null : _onProceed,
              child: const Text('다시 저장하기'),
            ),
          ],
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
          child: Semantics(
            checked: value,
            button: true,
            child: InkWell(
              onTap: _isSaving ? null : () => onChanged(!value),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    Icon(
                      value ? Icons.check_circle : Icons.circle_outlined,
                      color: value ? AppTheme.accentColor : AppTheme.neutral500,
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
                                    : AppTheme.neutral500,
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
          ),
        ),
        if (hasDetail) ...[
          const SizedBox(width: 8),
          SizedBox(
            height: 44,
            child: TextButton(
              onPressed: _isSaving ? null : onDetailTap,
              child: const Text('보기'),
            ),
          ),
        ],
      ],
    );
  }
}
