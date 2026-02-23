import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class KakaoConsentPage extends StatefulWidget {
  const KakaoConsentPage({super.key});

  @override
  State<KakaoConsentPage> createState() => _KakaoConsentPageState();
}

class _KakaoConsentPageState extends State<KakaoConsentPage> {
  bool _allAgreed = false;
  bool _profileAgreed = false; // 필수: 프로필 정보
  bool _emailAgreed = false; // 선택: 이메일

  bool get _canProceed => _profileAgreed;

  void _toggleAll(bool? value) {
    setState(() {
      _allAgreed = value ?? false;
      _profileAgreed = _allAgreed;
      _emailAgreed = _allAgreed;
    });
  }

  void _updateAllAgreedState() {
    setState(() {
      _allAgreed = _profileAgreed && _emailAgreed;
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
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () {
            // 로그아웃 처리하고 로그인 페이지로
            context.go('/onboarding/login');
          },
        ),
        title: const Text(
          '동의 화면 미리보기',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 상단 카카오 브랜딩
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              color: Colors.grey[50],
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE500),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(
                        Icons.chat_bubble,
                        size: 32,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'kakao',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 앱 정보 및 사용자 정보
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 앱 정보
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.pets,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '멍냥 다이어리',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '(주)재나',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // 전체 동의
                    GestureDetector(
                      onTap: () => _toggleAll(!_allAgreed),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _allAgreed ? Colors.orange : Colors.grey.shade300,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _allAgreed ? Icons.check_circle : Icons.circle_outlined,
                              color: _allAgreed ? Colors.orange : Colors.grey,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              '전체 동의하기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '전체 동의는 선택 항목에 대한 동의를 포함하고 있으며, 선택 항목에 동의하지 않아도 서비스 이용이 가능합니다.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 개별 동의 항목들
                    _buildConsentItem(
                      isRequired: true,
                      label: '프로필 정보(닉네임/프로필 사진)',
                      value: _profileAgreed,
                      onChanged: (value) {
                        setState(() {
                          _profileAgreed = value ?? false;
                          _updateAllAgreedState();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildConsentItem(
                      isRequired: false,
                      label: '카카오계정(이메일)',
                      value: _emailAgreed,
                      onChanged: (value) {
                        setState(() {
                          _emailAgreed = value ?? false;
                          _updateAllAgreedState();
                        });
                      },
                    ),
                    const SizedBox(height: 32),

                    // 카카오 로그인 동의 안내
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '카카오 로그인 동의',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '멍냥 다이어리 서비스 제공을 위해 권한받은 정보를 수집 및 이용합니다. 또한 지속적인 서비스 제공을 위해 카카오에게 정보를 요청합니다. 해당 정보는 동의 철회 시 지체없이 파기됩니다.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Text(
                                '[필수] 카카오 개인정보 제3자 제공 동의',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () {
                                  // 상세 내용 보기
                                },
                                child: Text(
                                  '보기',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 하단 버튼
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _canProceed
                      ? () {
                          // 동의 완료 후 이용약관 페이지로 이동
                          context.go('/onboarding/terms');
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canProceed ? const Color(0xFFFEE500) : Colors.grey[300],
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: const Text(
                    '동의하고 계속하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentItem({
    required bool isRequired,
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Icon(
            value ? Icons.check_circle : Icons.circle_outlined,
            color: value ? Colors.orange : Colors.grey,
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
                    text: isRequired ? '[필수] ' : '[선택] ',
                    style: TextStyle(
                      color: isRequired ? Colors.orange : Colors.grey,
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
    );
  }
}
