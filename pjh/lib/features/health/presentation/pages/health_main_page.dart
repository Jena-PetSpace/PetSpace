import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../pets/presentation/bloc/pet_bloc.dart';
import '../../../pets/presentation/bloc/pet_state.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/health_record.dart';
import '../bloc/health_bloc.dart';
import '../../../emotion/domain/entities/emotion_analysis.dart';
import '../../../emotion/domain/repositories/emotion_repository.dart';
import '../widgets/health_record_card.dart';
import '../widgets/health_record_data.dart';
import 'health_pdf_preview_page.dart';
import '../widgets/weight_trend_chart.dart';
import '../widgets/emotion_trend_mini_chart.dart';

part '../widgets/health_record_sheets.dart';


class HealthMainPage extends StatelessWidget {
  const HealthMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<HealthBloc>(),
      child: const _HealthMainView(),
    );
  }
}

class _HealthMainView extends StatefulWidget {
  const _HealthMainView();

  @override
  State<_HealthMainView> createState() => _HealthMainViewState();
}

class _HealthMainViewState extends State<_HealthMainView> {
  HealthRecordType? _selectedFilter; // null = 전체

  /// 필터 칩·빈 상태 문구가 공유하는 유형 표시명. (type, label)
  static const _filterTypes = <(HealthRecordType?, String)>[
    (null, '전체'),
    (HealthRecordType.vaccination, '백신'),
    (HealthRecordType.checkup, '검진'),
    (HealthRecordType.weight, '체중'),
    (HealthRecordType.medication, '투약'),
    (HealthRecordType.surgery, '수술'),
  ];

  @override
  void initState() {
    super.initState();
    _loadHealthData();
  }

  void _loadHealthData() {
    final petState = context.read<PetBloc>().state;
    if (petState is PetLoaded && petState.selectedPet != null) {
      final authState = context.read<AuthBloc>().state;
      final userId = authState is AuthAuthenticated ? authState.user.uid : null;
      context.read<HealthBloc>().add(LoadHealthRecords(
            petId: petState.selectedPet!.id,
            userId: userId,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PetBloc, PetState>(
      builder: (context, petState) {
        final petName = petState is PetLoaded
            ? petState.selectedPet?.name ?? '반려동물'
            : '반려동물';

        return Scaffold(
          appBar: AppBar(
            title: Column(
              children: [
                Text(
                  '건강관리',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
                Text(
                  '$petName의 건강 기록',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'PDF 내보내기',
                onPressed: () => _exportHealthPdf(context),
              ),
            ],
          ),
          floatingActionButton: Semantics(
            label: '건강 기록 추가',
            button: true,
            child: FloatingActionButton(
              onPressed: () => _showAddRecordSheet(context),
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
          body: BlocBuilder<HealthBloc, HealthState>(
            builder: (context, state) {
              if (state is HealthLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is HealthError) {
                return _buildErrorState(state.message);
              }

              if (state is HealthLoaded) {
                return _buildContent(state, petName);
              }

              // HealthInitial - 반려동물이 없는 경우
              return _buildEmptyPetState();
            },
          ),
        );
      },
    );
  }

  Widget _buildContent(HealthLoaded state, String petName) {
    return RefreshIndicator(
      onRefresh: () async => _loadHealthData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 예정된 알림
            if (state.upcomingAlerts.isNotEmpty) ...[
              _buildUpcomingAlerts(state.upcomingAlerts),
              SizedBox(height: 20.h),
            ],

            // 감정 분석 추이
            Text(
              '감정 분석 추이',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleMedium?.color,
              ),
            ),
            SizedBox(height: 12.h),
            Builder(
              builder: (context) {
                final authState = context.read<AuthBloc>().state;
                final userId =
                    authState is AuthAuthenticated ? authState.user.uid : null;
                final petState = context.read<PetBloc>().state;
                final petId = petState is PetLoaded
                    ? petState.selectedPet?.id
                    : null;
                if (userId == null) return const SizedBox.shrink();
                return EmotionTrendMiniChart(
                  key: ValueKey('emotion_trend_$petId'),
                  userId: userId,
                  petId: petId,
                );
              },
            ),
            SizedBox(height: 20.h),

            // 건강 기록 리스트
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '건강 기록',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleMedium?.color,
                  ),
                ),
                Text(
                  '${state.records.length}건',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),

            // 유형별 필터 칩
            _buildFilterChips(),
            SizedBox(height: 12.h),

            // 체중 필터 선택 시 추이 차트 노출 (감정 트렌드와 위치 충돌 없음)
            if (_selectedFilter == HealthRecordType.weight) ...[
              WeightTrendChart(records: state.records),
              SizedBox(height: 12.h),
            ],

            if (state.records.isEmpty)
              _buildEmptyRecordState()
            else ...[
              Builder(
                builder: (context) {
                  final filtered = _selectedFilter == null
                      ? state.records
                      : state.records.where((r) => r.recordType == _selectedFilter).toList();
                  if (filtered.isEmpty) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.h),
                      child: Center(
                        child: Text(
                          _emptyFilterMessage(),
                          style: TextStyle(fontSize: 13.sp, color: AppTheme.secondaryTextColor),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: filtered.map((record) => Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: Dismissible(
                        key: Key(record.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(right: 20.w),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) => _confirmDelete(context),
                        onDismissed: (_) {
                          context.read<HealthBloc>().add(DeleteHealthRecordEvent(recordId: record.id));
                        },
                        child: GestureDetector(
                          onTap: () => _showEditRecordSheet(context, record),
                          child: HealthRecordCard(
                            icon: _getRecordIcon(record.recordType),
                            iconColor: _getRecordColor(record.recordType),
                            title: _getRecordTypeName(record.recordType),
                            subtitle: recordCardSubtitle(record),
                            date: _formatDate(record.recordDate),
                            status: _getStatusName(record.status),
                            statusColor: _getStatusColor(record.status),
                          ),
                        ),
                      ),
                    )).toList(),
                  );
                },
              ),

            if (state.error != null)
              Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: Text(
                  state.error!,
                  style: TextStyle(color: AppTheme.errorColor, fontSize: 12.sp),
                ),
              ),

            SizedBox(height: 80.h),
            ], // else [...] 닫힘
          ],
        ),
      ),
    );
  }

  /// 건강 요약서 PDF 미리보기로 이동(저장·공유는 미리보기 내장 액션).
  /// 펫 미선택·기록 0건 시 안내.
  Future<void> _exportHealthPdf(BuildContext context) async {
    final petState = context.read<PetBloc>().state;
    final pet = petState is PetLoaded ? petState.selectedPet : null;
    if (pet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('반려동물을 먼저 선택해주세요')),
      );
      return;
    }

    final healthState = context.read<HealthBloc>().state;
    final records =
        healthState is HealthLoaded ? healthState.records : <HealthRecord>[];
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내보낼 건강 기록이 없습니다')),
      );
      return;
    }

    final authState = context.read<AuthBloc>().state;
    final ownerName =
        authState is AuthAuthenticated ? authState.user.displayName : '보호자';
    final userId =
        authState is AuthAuthenticated ? authState.user.uid : null;

    // 최근 AI 감정 분석 1건(선택, 읽기 전용).
    EmotionAnalysis? latest;
    if (userId != null) {
      final res = await sl<EmotionRepository>().getAnalysisHistory(
        userId: userId,
        petId: pet.id,
        limit: 1,
      );
      latest = res.fold((_) => null, (list) => list.isEmpty ? null : list.first);
    }

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HealthPdfPreviewPage(
          pet: pet,
          ownerName: ownerName,
          records: records,
          latestAnalysis: latest,
        ),
      ),
    );
  }

  /// 선택된 필터 기준 빈 상태 문구. 전체(필터 없음)는 별도 문구로 통일.
  String _emptyFilterMessage() {
    final filter = _selectedFilter;
    if (filter == null) return '아직 기록이 없어요';
    final label = _filterTypes.firstWhere((t) => t.$1 == filter).$2;
    return '$label 기록이 없어요';
  }

  /// 유형 칩 색 — 필터·기록 유형 선택(시트)이 공유.
  static const _filterTypeColors = <HealthRecordType?, Color>{
    null: AppTheme.primaryColor,
    HealthRecordType.vaccination: AppTheme.successColor,
    HealthRecordType.checkup: AppTheme.accentColor,
    HealthRecordType.weight: AppTheme.highlightColor,
    HealthRecordType.medication: AppTheme.secondaryColor,
    HealthRecordType.surgery: AppTheme.errorColor,
  };

  Widget _buildFilterChips() {
    return SizedBox(
      height: 36.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: _filterTypes.length,
        separatorBuilder: (_, __) => SizedBox(width: 6.w),
        itemBuilder: (context, i) {
          final (type, label) = _filterTypes[i];
          return _typeChip(
            label: label,
            color: _filterTypeColors[type]!,
            isSelected: _selectedFilter == type,
            onTap: () => setState(() => _selectedFilter = type),
          );
        },
      ),
    );
  }

  /// 라벨 알약 칩 — 필터와 시트의 유형 선택이 공용으로 사용.
  Widget _typeChip({
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: isSelected ? color : AppTheme.dividerColor,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.secondaryTextColor,
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingAlerts(List<HealthRecord> alerts) {
    return Card(
      color: AppTheme.highlightColor.withValues(alpha: 0.1),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active,
                    color: AppTheme.highlightColor, size: 20.w),
                SizedBox(width: 8.w),
                Text(
                  '다가오는 일정',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                    color: AppTheme.highlightColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            ...alerts.take(3).map((alert) => Padding(
                  padding: EdgeInsets.only(top: 4.h),
                  child: Text(
                    '${alert.title} - D${alert.daysUntilNext != null ? (alert.daysUntilNext! >= 0 ? "-${alert.daysUntilNext}" : "+${-alert.daysUntilNext!}") : ""}',
                    style: TextStyle(fontSize: 13.sp),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRecordState() {
    return const EmptyStateWidget(
      icon: Icons.health_and_safety_outlined,
      title: '아직 기록이 없어요',
      subtitle: '반려동물의 건강 변화를 추적해보세요!\n오른쪽 아래 + 버튼으로 첫 기록을 남길 수 있어요',
    );
  }

  Widget _buildEmptyPetState() {
    return EmptyStateWidget(
      icon: Icons.pets,
      title: '반려동물을 먼저 등록해주세요',
      subtitle: '반려동물을 등록하면\n건강 기록과 AI 분석을 시작할 수 있어요!',
      actionLabel: '반려동물 등록',
      onAction: () => context.push('/pets'),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64.w, color: AppTheme.errorColor),
          SizedBox(height: 16.h),
          Text(message,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
              textAlign: TextAlign.center),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _loadHealthData,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('기록 삭제', style: TextStyle(fontSize: 18.sp)),
        content: Text('이 건강 기록을 삭제하시겠습니까?', style: TextStyle(fontSize: 14.sp)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('취소', style: TextStyle(fontSize: 14.sp)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: Text('삭제', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }
}
