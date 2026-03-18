import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('도움말'),
      ),
      body: ListView(
        children: [
          _buildSection('자주 묻는 질문', [
            _FaqItem(
              question: '감정 분석은 어떻게 하나요?',
              answer: '홈 화면에서 "감정 분석" 버튼을 눌러 반려동물 사진을 촬영하거나 갤러리에서 선택하세요. '
                  'AI가 반려동물의 감정 상태를 분석해줍니다.',
            ),
            _FaqItem(
              question: '반려동물은 몇 마리까지 등록할 수 있나요?',
              answer: '현재 제한 없이 여러 마리의 반려동물을 등록할 수 있습니다.',
            ),
            _FaqItem(
              question: '게시물을 삭제하면 복구할 수 있나요?',
              answer: '삭제된 게시물은 복구할 수 없습니다. 삭제 전 확인 메시지를 꼭 확인해주세요.',
            ),
            _FaqItem(
              question: '다른 사용자를 차단하면 어떻게 되나요?',
              answer: '차단한 사용자는 내 게시물을 볼 수 없고, 메시지를 보낼 수 없습니다.',
            ),
          ]),
          const Divider(),
          _buildSection('문의하기', []),
          ListTile(
            leading: Icon(Icons.email, size: 24.w),
            title: Text('이메일 문의', style: TextStyle(fontSize: 14.sp)),
            subtitle:
                Text('support@petspace.app', style: TextStyle(fontSize: 12.sp)),
            trailing: Icon(Icons.chevron_right, size: 20.w),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('이메일 앱을 열 수 없습니다')),
              );
            },
          ),
          const Divider(),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Text(
              '앱 버전: 1.0.0',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<_FaqItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...items.map((item) => ExpansionTile(
              title: Text(item.question, style: TextStyle(fontSize: 14.sp)),
              children: [
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  child: Text(
                    item.answer,
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
                  ),
                ),
              ],
            )),
      ],
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});
}
