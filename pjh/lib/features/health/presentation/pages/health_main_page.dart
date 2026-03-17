import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../pets/presentation/bloc/pet_bloc.dart';
import '../../../pets/presentation/bloc/pet_state.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/health_record.dart';
import '../bloc/health_bloc.dart';
import '../widgets/health_record_card.dart';
import '../widgets/emotion_trend_mini_chart.dart';

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
  @override
  void initState() {
    super.initState();
    _loadHealthData();
  }

  void _loadHealthData() {
    final petState = context.read<PetBloc>().state;
    if (petState is PetLoaded && petState.selectedPet != null) {
      final authState = context.read<AuthBloc>().state;
      final userId =
          authState is AuthAuthenticated ? authState.user.uid : null;
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
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                Text(
                  '$petName의 건강 기록',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
              ],
            ),
            centerTitle: true,
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddRecordSheet(context),
            backgroundColor: AppTheme.primaryColor,
            child: const Icon(Icons.add, color: Colors.white),
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

            // 주간 감정 트렌드
            Text(
              '주간 감정 트렌드',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
              ),
            ),
            SizedBox(height: 12.h),
            const EmotionTrendMiniChart(),
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
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                Text(
                  '${state.records.length}건',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),

            if (state.records.isEmpty)
              _buildEmptyRecordState()
            else
              ...state.records.map((record) => Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: Dismissible(
                      key: Key(record.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.only(right: 20.w),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) => _confirmDelete(context),
                      onDismissed: (_) {
                        context
                            .read<HealthBloc>()
                            .add(DeleteHealthRecordEvent(recordId: record.id));
                      },
                      child: HealthRecordCard(
                        icon: _getRecordIcon(record.recordType),
                        iconColor: _getRecordColor(record.recordType),
                        title: _getRecordTypeName(record.recordType),
                        subtitle: record.title,
                        date: _formatDate(record.recordDate),
                        status: _getStatusName(record.status),
                        statusColor: _getStatusColor(record.status),
                      ),
                    ),
                  )),

            if (state.error != null)
              Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: Text(
                  state.error!,
                  style: TextStyle(color: Colors.red, fontSize: 12.sp),
                ),
              ),

            SizedBox(height: 80.h),
          ],
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
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40.h),
        child: Column(
          children: [
            Icon(Icons.health_and_safety_outlined,
                size: 64.w, color: Colors.grey[300]),
            SizedBox(height: 16.h),
            Text(
              '건강 기록이 없습니다',
              style: TextStyle(fontSize: 16.sp, color: Colors.grey[500]),
            ),
            SizedBox(height: 8.h),
            Text(
              '+ 버튼을 눌러 기록을 추가해보세요',
              style: TextStyle(fontSize: 13.sp, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPetState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pets, size: 64.w, color: Colors.grey[300]),
          SizedBox(height: 16.h),
          Text(
            '반려동물을 먼저 등록해주세요',
            style: TextStyle(fontSize: 16.sp, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64.w, color: Colors.red),
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
        content:
            Text('이 건강 기록을 삭제하시겠습니까?', style: TextStyle(fontSize: 14.sp)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('취소', style: TextStyle(fontSize: 14.sp)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('삭제', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  void _showAddRecordSheet(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    HealthRecordType selectedType = HealthRecordType.vaccination;
    DateTime selectedDate = DateTime.now();
    DateTime? nextDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 20.h,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20.h,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('건강 기록 추가',
                    style: TextStyle(
                        fontSize: 18.sp, fontWeight: FontWeight.bold)),
                SizedBox(height: 20.h),

                // 기록 타입
                Text('기록 유형',
                    style: TextStyle(
                        fontSize: 14.sp, fontWeight: FontWeight.w600)),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 8.w,
                  children: HealthRecordType.values.map((type) {
                    final isSelected = type == selectedType;
                    return ChoiceChip(
                      label: Text(_getRecordTypeName(type),
                          style: TextStyle(fontSize: 12.sp)),
                      selected: isSelected,
                      selectedColor:
                          AppTheme.primaryColor.withValues(alpha: 0.2),
                      onSelected: (_) =>
                          setSheetState(() => selectedType = type),
                    );
                  }).toList(),
                ),
                SizedBox(height: 16.h),

                // 제목
                TextField(
                  controller: titleController,
                  style: TextStyle(fontSize: 14.sp),
                  decoration: InputDecoration(
                    labelText: '제목',
                    labelStyle: TextStyle(fontSize: 14.sp),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),

                // 메모
                TextField(
                  controller: descController,
                  style: TextStyle(fontSize: 14.sp),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: '메모 (선택)',
                    labelStyle: TextStyle(fontSize: 14.sp),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),

                // 날짜
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text('기록 날짜: ${_formatDate(selectedDate)}',
                      style: TextStyle(fontSize: 14.sp)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setSheetState(() => selectedDate = picked);
                    }
                  },
                ),

                // 다음 예정일
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: Text(
                    nextDate != null
                        ? '다음 예정일: ${_formatDate(nextDate!)}'
                        : '다음 예정일 (선택)',
                    style: TextStyle(fontSize: 14.sp),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setSheetState(() => nextDate = picked);
                    }
                  },
                ),
                SizedBox(height: 20.h),

                // 저장 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (titleController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('제목을 입력해주세요')),
                        );
                        return;
                      }

                      final petState = context.read<PetBloc>().state;
                      if (petState is! PetLoaded ||
                          petState.selectedPet == null) {
                        return;
                      }

                      final record = HealthRecord(
                        id: '',
                        petId: petState.selectedPet!.id,
                        userId: '',
                        recordType: selectedType,
                        title: titleController.text.trim(),
                        description: descController.text.trim().isEmpty
                            ? null
                            : descController.text.trim(),
                        recordDate: selectedDate,
                        nextDate: nextDate,
                        status: selectedDate.isAfter(DateTime.now())
                            ? HealthRecordStatus.scheduled
                            : HealthRecordStatus.completed,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );

                      context
                          .read<HealthBloc>()
                          .add(AddHealthRecordEvent(record: record));
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text('저장',
                        style: TextStyle(
                            fontSize: 16.sp, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getRecordIcon(HealthRecordType type) {
    switch (type) {
      case HealthRecordType.vaccination:
        return Icons.vaccines;
      case HealthRecordType.checkup:
        return Icons.health_and_safety;
      case HealthRecordType.weight:
        return Icons.monitor_weight;
      case HealthRecordType.medication:
        return Icons.medication;
      case HealthRecordType.surgery:
        return Icons.local_hospital;
    }
  }

  Color _getRecordColor(HealthRecordType type) {
    switch (type) {
      case HealthRecordType.vaccination:
        return AppTheme.highlightColor;
      case HealthRecordType.checkup:
        return AppTheme.successColor;
      case HealthRecordType.weight:
        return AppTheme.accentColor;
      case HealthRecordType.medication:
        return Colors.orange;
      case HealthRecordType.surgery:
        return Colors.red;
    }
  }

  String _getRecordTypeName(HealthRecordType type) {
    switch (type) {
      case HealthRecordType.vaccination:
        return '예방접종';
      case HealthRecordType.checkup:
        return '건강검진';
      case HealthRecordType.weight:
        return '체중기록';
      case HealthRecordType.medication:
        return '투약';
      case HealthRecordType.surgery:
        return '수술';
    }
  }

  String _getStatusName(HealthRecordStatus status) {
    switch (status) {
      case HealthRecordStatus.scheduled:
        return '예정';
      case HealthRecordStatus.completed:
        return '완료';
      case HealthRecordStatus.overdue:
        return '지남';
      case HealthRecordStatus.cancelled:
        return '취소';
    }
  }

  Color _getStatusColor(HealthRecordStatus status) {
    switch (status) {
      case HealthRecordStatus.scheduled:
        return AppTheme.highlightColor;
      case HealthRecordStatus.completed:
        return AppTheme.successColor;
      case HealthRecordStatus.overdue:
        return Colors.red;
      case HealthRecordStatus.cancelled:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}
