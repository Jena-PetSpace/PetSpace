import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/app_config.dart';
import '../../../../core/services/app_package_info.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_page_scaffold.dart';
import '../../../../shared/widgets/petspace_settings_components.dart';

Future<bool> _launchSupportEmail(Uri uri) async {
  if (!await canLaunchUrl(uri)) return false;
  return launchUrl(uri);
}

class HelpPage extends StatefulWidget {
  final Future<AppPackageInfo> Function() packageInfoLoader;
  final Future<bool> Function(Uri uri) emailLauncher;

  const HelpPage({
    super.key,
    this.packageInfoLoader = AppPackageInfo.load,
    this.emailLauncher = _launchSupportEmail,
  });

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  late final Future<AppPackageInfo> _packageInfo;

  static const List<_FaqItem> _faqItems = [
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
  ];

  @override
  void initState() {
    super.initState();
    _packageInfo = widget.packageInfoLoader();
  }

  @override
  Widget build(BuildContext context) {
    return PetSpacePageScaffold(
      title: '도움말',
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
        children: [
          PetSpaceSettingsSection(
            title: '자주 묻는 질문',
            children: [
              for (final item in _faqItems) _buildFaqTile(context, item),
            ],
          ),
          SizedBox(height: 24.h),
          PetSpaceSettingsSection(
            title: '문의하기',
            children: [
              PetSpaceSettingsTile(
                key: const Key('help_support_email'),
                icon: Icons.email_outlined,
                title: '이메일 문의',
                subtitle: AppConfig.supportEmail,
                onTap: () async {
                  final uri = Uri(
                    scheme: 'mailto',
                    path: AppConfig.supportEmail,
                  );
                  if (!await widget.emailLauncher(uri) && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('이메일 앱을 열 수 없습니다')),
                    );
                  }
                },
              ),
            ],
          ),
          SizedBox(height: 24.h),
          FutureBuilder<AppPackageInfo>(
            future: _packageInfo,
            builder: (context, snapshot) => Text(
              key: const Key('help_app_version'),
              snapshot.hasData
                  ? '앱 버전: ${snapshot.data!.displayVersion}'
                  : snapshot.hasError
                      ? '앱 버전: 확인할 수 없음'
                      : '앱 버전을 확인하고 있어요',
              style: TextStyle(
                fontSize: AppTheme.fontCaption.sp,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : AppTheme.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 32.h),
        ],
      ),
    );
  }

  Widget _buildFaqTile(BuildContext context, _FaqItem item) {
    // 다크모드는 Theme의 text를 우선하고 라이트모드 시각값은 유지한다.
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color bodyColor =
        isDark ? theme.colorScheme.onSurface : AppTheme.primaryTextColor;
    final Color answerColor =
        isDark ? theme.colorScheme.onSurface : AppTheme.textBody;
    final Color mutedColor =
        isDark ? theme.colorScheme.onSurfaceVariant : AppTheme.textMuted;
    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: mutedColor,
      collapsedIconColor: mutedColor,
      tilePadding: EdgeInsets.symmetric(horizontal: 16.w),
      childrenPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      title: Text(
        item.question,
        style: TextStyle(
          fontSize: AppTheme.fontBody.sp,
          fontWeight: FontWeight.w500,
          color: bodyColor,
        ),
      ),
      children: [
        Text(
          item.answer,
          style: TextStyle(
            fontSize: AppTheme.fontCaption.sp,
            color: answerColor,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});
}
