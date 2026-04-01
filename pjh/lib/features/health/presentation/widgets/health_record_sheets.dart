part of '../pages/health_main_page.dart';

extension _HealthMainSheets on _HealthMainViewState {
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

  void _showEditRecordSheet(BuildContext context, HealthRecord record) {
    final titleController = TextEditingController(text: record.title);
    final descController =
        TextEditingController(text: record.description ?? '');
    HealthRecordType selectedType = record.recordType;
    DateTime selectedDate = record.recordDate;
    DateTime? nextDate = record.nextDate;
    HealthRecordStatus selectedStatus = record.status;

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
                Text('건강 기록 수정',
                    style: TextStyle(
                        fontSize: 18.sp, fontWeight: FontWeight.bold)),
                SizedBox(height: 20.h),

                Text('기록 유형',
                    style: TextStyle(
                        fontSize: 14.sp, fontWeight: FontWeight.w600)),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 8.w,
                  children: HealthRecordType.values.map((type) {
                    return ChoiceChip(
                      label: Text(_getRecordTypeName(type),
                          style: TextStyle(fontSize: 12.sp)),
                      selected: type == selectedType,
                      selectedColor:
                          AppTheme.primaryColor.withValues(alpha: 0.2),
                      onSelected: (_) =>
                          setSheetState(() => selectedType = type),
                    );
                  }).toList(),
                ),
                SizedBox(height: 16.h),

                TextField(
                  controller: titleController,
                  style: TextStyle(fontSize: 14.sp),
                  decoration: InputDecoration(
                    labelText: '제목',
                    labelStyle: TextStyle(fontSize: 14.sp),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r)),
                  ),
                ),
                SizedBox(height: 12.h),

                TextField(
                  controller: descController,
                  style: TextStyle(fontSize: 14.sp),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: '메모 (선택)',
                    labelStyle: TextStyle(fontSize: 14.sp),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r)),
                  ),
                ),
                SizedBox(height: 12.h),

                // 상태
                Text('상태',
                    style: TextStyle(
                        fontSize: 14.sp, fontWeight: FontWeight.w600)),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 8.w,
                  children: HealthRecordStatus.values.map((status) {
                    return ChoiceChip(
                      label: Text(_getStatusName(status),
                          style: TextStyle(fontSize: 12.sp)),
                      selected: status == selectedStatus,
                      selectedColor:
                          _getStatusColor(status).withValues(alpha: 0.2),
                      onSelected: (_) =>
                          setSheetState(() => selectedStatus = status),
                    );
                  }).toList(),
                ),
                SizedBox(height: 12.h),

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
                      initialDate: nextDate ??
                          DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setSheetState(() => nextDate = picked);
                  },
                ),
                SizedBox(height: 20.h),

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

                      final updated = HealthRecord(
                        id: record.id,
                        petId: record.petId,
                        userId: record.userId,
                        recordType: selectedType,
                        title: titleController.text.trim(),
                        description: descController.text.trim().isEmpty
                            ? null
                            : descController.text.trim(),
                        recordDate: selectedDate,
                        nextDate: nextDate,
                        status: selectedStatus,
                        createdAt: record.createdAt,
                        updatedAt: DateTime.now(),
                      );

                      context
                          .read<HealthBloc>()
                          .add(UpdateHealthRecordEvent(record: updated));
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r)),
                    ),
                    child: Text('수정 완료',
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
