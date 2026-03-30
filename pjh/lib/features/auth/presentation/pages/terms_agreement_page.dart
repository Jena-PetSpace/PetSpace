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

  bool get _canProceed => _ageAgreed && _termsAgreed && _privacyAgreed;

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
      _allAgreed =
          _ageAgreed && _termsAgreed && _privacyAgreed && _marketingAgreed;
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
                        content: '멍냥다이어리(PetSpace) 서비스 이용약관\n\n'
                            '제1조 (목적)\n'
                            '본 약관은 멍냥다이어리(이하 "서비스")가 제공하는 반려동물 다이어리, 소셜 커뮤니티, AI 감정 분석 등 모든 서비스의 이용 조건 및 절차, 회사와 회원 간의 권리·의무를 규정함을 목적으로 합니다.\n\n'
                            '제2조 (서비스 개요)\n'
                            '서비스는 다음 기능을 제공합니다.\n'
                            '① 반려동물 다이어리 작성 및 관리\n'
                            '② 반려동물 사진·게시물 공유 소셜 기능\n'
                            '③ AI 기반 반려동물 감정 분석\n'
                            '④ 반려동물 건강·일상 기록 관리\n\n'
                            '제3조 (회원 가입 및 탈퇴)\n'
                            '① 만 14세 이상인 자가 본 약관에 동의하고 회원정보를 기입하여 가입할 수 있습니다.\n'
                            '② 회원은 언제든지 앱 내 설정에서 탈퇴를 요청할 수 있으며, 회사는 즉시 처리합니다.\n'
                            '③ 탈퇴 시 회원의 게시물 및 개인정보는 관련 법령에 따라 일정 기간 보관 후 파기됩니다.\n\n'
                            '제4조 (이용 규칙)\n'
                            '회원은 다음 행위를 하여서는 안 됩니다.\n'
                            '① 타인의 정보 도용 또는 허위 정보 등록\n'
                            '② 동물 학대, 혐오, 불법적인 콘텐츠 게시\n'
                            '③ 서비스의 정상적 운영을 방해하는 행위\n'
                            '④ 타인의 저작권 등 지적재산권을 침해하는 행위\n'
                            '⑤ 상업적 광고·스팸을 무단으로 게시하는 행위\n\n'
                            '제5조 (게시물의 권리 및 책임)\n'
                            '① 회원이 작성한 게시물의 저작권은 해당 회원에게 귀속됩니다.\n'
                            '② 회사는 서비스 운영·홍보 목적으로 회원 게시물을 사용할 수 있습니다.\n'
                            '③ 회원은 자신의 게시물에 대한 법적 책임을 부담합니다.\n\n'
                            '제6조 (서비스 변경 및 중단)\n'
                            '① 회사는 운영상·기술상 필요에 따라 서비스를 변경하거나 중단할 수 있습니다.\n'
                            '② 서비스 변경·중단 시 사전에 앱 내 공지합니다.\n\n'
                            '제7조 (면책조항)\n'
                            '① 회사는 천재지변, 시스템 장애 등 불가항력으로 인한 서비스 중단에 대해 책임을 지지 않습니다.\n'
                            '② AI 감정 분석 결과는 참고용이며, 의학적 진단을 대체하지 않습니다.\n'
                            '③ 회원 간 분쟁에 대해 회사는 개입 의무를 지지 않습니다.\n\n'
                            '시행일: 2026년 3월 30일',
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
                        content: '멍냥다이어리(PetSpace) 개인정보 처리방침\n\n'
                            '1. 수집하는 개인정보 항목\n'
                            '필수: 이메일 주소, 비밀번호, 닉네임\n'
                            '선택: 프로필 사진, 반려동물 정보(이름, 품종, 생년월일, 성별, 사진), 게시물 사진 및 내용\n\n'
                            '2. 개인정보 수집 및 이용 목적\n'
                            '① 회원 가입 및 본인 확인, 계정 관리\n'
                            '② 반려동물 다이어리 및 소셜 서비스 제공\n'
                            '③ AI 감정 분석 서비스 제공 (반려동물 사진·텍스트 기반)\n'
                            '④ 서비스 개선 및 신규 기능 개발을 위한 통계 분석\n'
                            '⑤ 공지사항 및 서비스 관련 안내 전달\n\n'
                            '3. 개인정보 보유 및 이용 기간\n'
                            '① 회원 탈퇴 시 즉시 파기합니다. 단, 관련 법령에 따라 일정 기간 보관이 필요한 경우 해당 기간 동안 보관합니다.\n'
                            '② 전자상거래법에 따른 계약·거래 기록: 5년\n'
                            '③ 통신비밀보호법에 따른 로그인 기록: 3개월\n\n'
                            '4. 개인정보의 제3자 제공\n'
                            '서비스 제공을 위해 다음 제3자에게 개인정보를 제공합니다.\n'
                            '① Supabase (미국): 데이터 저장·인증·파일 호스팅 (이메일, 닉네임, 게시물, 사진)\n'
                            '② Google Gemini AI (미국): AI 감정 분석 (반려동물 사진·텍스트 데이터, 비식별 처리 후 전송)\n'
                            '③ Firebase Cloud Messaging (미국): 푸시 알림 발송 (기기 토큰)\n'
                            '※ 상기 외 제3자에게 개인정보를 제공하지 않으며, 새로운 제공이 필요한 경우 사전 동의를 받습니다.\n\n'
                            '5. 이용자의 권리\n'
                            '① 언제든지 본인의 개인정보를 열람·수정할 수 있습니다.\n'
                            '② 회원 탈퇴를 통해 개인정보 삭제를 요청할 수 있습니다.\n'
                            '③ 개인정보 수집·이용 동의를 철회할 수 있습니다.\n'
                            '④ 개인정보 관련 문의: petspace.help@gmail.com\n\n'
                            '6. 개인정보의 안전성 확보 조치\n'
                            '① 비밀번호 암호화 저장\n'
                            '② SSL/TLS 암호화 통신\n'
                            '③ 접근 권한 제한 및 접근 기록 관리\n\n'
                            '시행일: 2026년 3월 30일',
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
                        content: '마케팅 정보 수신 동의\n\n'
                            '멍냥다이어리(PetSpace)에서 제공하는 다양한 혜택과 정보를 받아보실 수 있습니다.\n\n'
                            '1. 수신 내용\n'
                            '① 이벤트 및 프로모션 안내\n'
                            '② 신규 기능 업데이트 소식\n'
                            '③ 반려동물 맞춤 콘텐츠 추천\n'
                            '④ 서비스 활용 팁 및 유용한 정보\n\n'
                            '2. 수신 방법\n'
                            '앱 푸시 알림\n\n'
                            '3. 동의 철회 방법\n'
                            '앱 내 설정 > 알림 설정에서 마케팅 알림을 언제든지 끌 수 있습니다. 동의 철회 시 마케팅 정보 발송이 즉시 중단됩니다.\n\n'
                            '※ 본 동의는 선택사항이며, 동의하지 않아도 서비스 이용에 제한이 없습니다.',
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
                  onPressed: _canProceed
                      ? () {
                          // 프로필 설정 페이지로 이동
                          context.go('/onboarding/profile');
                        }
                      : null,
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
                        color:
                            isRequired ? AppTheme.highlightColor : Colors.grey,
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
