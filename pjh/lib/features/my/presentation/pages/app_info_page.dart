import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/services/app_package_info.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_page_scaffold.dart';
import '../../../../shared/widgets/petspace_state_view.dart';

typedef AppPackageInfoLoader = Future<AppPackageInfo> Function();

class AppInfoPage extends StatefulWidget {
  final AppPackageInfoLoader packageInfoLoader;

  const AppInfoPage({
    super.key,
    this.packageInfoLoader = AppPackageInfo.load,
  });

  @override
  State<AppInfoPage> createState() => _AppInfoPageState();
}

class _AppInfoPageState extends State<AppInfoPage> {
  late Future<AppPackageInfo> _packageInfo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _packageInfo = widget.packageInfoLoader();
  }

  void _retry() {
    setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PetSpacePageScaffold(
      title: '앱 정보',
      body: FutureBuilder<AppPackageInfo>(
        future: _packageInfo,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const PetSpaceStateView.loading();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return PetSpaceStateView.error(
              message: '앱 정보를 불러오지 못했어요.',
              actionLabel: '다시 시도',
              onAction: _retry,
            );
          }

          return ListView(
            key: const Key('app_info_content'),
            padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 32.h),
            children: [
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg.r),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64.w,
                      height: 64.w,
                      decoration: const BoxDecoration(
                        color: AppTheme.actionContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.pets_outlined,
                        size: 30.w,
                        color: AppTheme.actionBase,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      '펫페이스',
                      style: TextStyle(
                        fontSize: AppTheme.fontTitle.sp,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '반려동물의 일상과 AI 참고 분석을 한곳에서',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppTheme.fontBody.sp,
                        height: 1.45,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 18.w,
                  vertical: 16.h,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '버전',
                        style: TextStyle(
                          fontSize: AppTheme.fontBody.sp,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Flexible(
                      child: Text(
                        snapshot.data!.displayVersion,
                        key: const Key('app_info_version'),
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: AppTheme.fontBody.sp,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
