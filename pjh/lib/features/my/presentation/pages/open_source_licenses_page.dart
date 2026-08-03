import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_page_scaffold.dart';
import '../../../../shared/widgets/petspace_state_view.dart';

class AppLicenseEntry {
  final String packageName;
  final String licenseText;

  const AppLicenseEntry({
    required this.packageName,
    required this.licenseText,
  });
}

typedef AppLicenseLoader = Future<List<AppLicenseEntry>> Function();

Future<List<AppLicenseEntry>> loadAppLicenses() async {
  final grouped = <String, Set<String>>{};
  await for (final entry in LicenseRegistry.licenses) {
    final text = entry.paragraphs
        .map((paragraph) => paragraph.text)
        .where((paragraph) => paragraph.trim().isNotEmpty)
        .join('\n\n');
    for (final package in entry.packages) {
      grouped.putIfAbsent(package, () => <String>{}).add(text);
    }
  }

  final entries = grouped.entries
      .map(
        (entry) => AppLicenseEntry(
          packageName: entry.key,
          licenseText: entry.value.join('\n\n'),
        ),
      )
      .toList()
    ..sort((a, b) => a.packageName.compareTo(b.packageName));
  return entries;
}

class OpenSourceLicensesPage extends StatefulWidget {
  final AppLicenseLoader licenseLoader;

  const OpenSourceLicensesPage({
    super.key,
    this.licenseLoader = loadAppLicenses,
  });

  @override
  State<OpenSourceLicensesPage> createState() => _OpenSourceLicensesPageState();
}

class _OpenSourceLicensesPageState extends State<OpenSourceLicensesPage> {
  late Future<List<AppLicenseEntry>> _licenses;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _licenses = widget.licenseLoader();
  }

  void _retry() {
    setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return PetSpacePageScaffold(
      title: '오픈소스 라이선스',
      body: FutureBuilder<List<AppLicenseEntry>>(
        future: _licenses,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const PetSpaceStateView.loading();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return PetSpaceStateView.error(
              message: '라이선스를 불러오지 못했어요.',
              actionLabel: '다시 시도',
              onAction: _retry,
            );
          }
          if (snapshot.data!.isEmpty) {
            return const PetSpaceStateView.empty(
              message: '표시할 오픈소스 라이선스가 없어요.',
            );
          }

          return ListView.separated(
            key: const Key('open_source_license_list'),
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 32.h),
            itemCount: snapshot.data!.length + 1,
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 6.h),
                  child: Text(
                    '펫페이스가 사용하는 패키지와 라이선스 원문을 확인할 수 있어요.',
                    style: TextStyle(
                      fontSize: AppTheme.fontBody.sp,
                      height: 1.45,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              final entry = snapshot.data![index - 1];
              return _LicenseTile(entry: entry);
            },
          );
        },
      ),
    );
  }
}

class _LicenseTile extends StatelessWidget {
  final AppLicenseEntry entry;

  const _LicenseTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('license_package_${entry.packageName}'),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _LicenseDetailPage(entry: entry),
            ),
          );
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    entry.packageName,
                    style: TextStyle(
                      fontSize: AppTheme.fontBody.sp,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LicenseDetailPage extends StatelessWidget {
  final AppLicenseEntry entry;

  const _LicenseDetailPage({required this.entry});

  @override
  Widget build(BuildContext context) {
    return PetSpacePageScaffold(
      title: entry.packageName,
      body: SelectionArea(
        child: SingleChildScrollView(
          key: const Key('open_source_license_detail'),
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 32.h),
          child: Text(
            entry.licenseText,
            style: TextStyle(
              fontSize: AppTheme.fontCaption.sp,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
