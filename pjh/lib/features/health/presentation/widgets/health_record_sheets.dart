part of '../pages/health_main_page.dart';

extension _HealthMainSheets on _HealthMainViewState {
  void _showAddRecordSheet(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final typeFields = _TypeFieldState();
    HealthRecordType selectedType = HealthRecordType.vaccination;
    DateTime selectedDate = DateTime.now();
    DateTime? nextDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // 탭바·FAB 위(루트 내비게이터)에 띄워 저장 버튼 가림 방지
      useRootNavigator: true,
      useSafeArea: true,
      // 긴 폼(투약·검진 등)도 화면을 다 덮지 않고 내부 스크롤
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
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

                // 타입별 전용 입력
                _buildTypeFields(selectedType, typeFields, setSheetState),
                SizedBox(height: 12.h),

                // 제목 (선택 — 체중은 자동 생성)
                TextField(
                  controller: titleController,
                  style: TextStyle(fontSize: 14.sp),
                  decoration: InputDecoration(
                    labelText: '제목 (선택)',
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
                      final typeError =
                          _validateTypeFields(selectedType, typeFields);
                      if (typeError != null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(typeError)),
                        );
                        return;
                      }

                      final petState = context.read<PetBloc>().state;
                      if (petState is! PetLoaded ||
                          petState.selectedPet == null) {
                        return;
                      }

                      final data = _composeData(selectedType, typeFields);
                      // 제목: 입력값 우선, 체중은 자동 생성, 그 외 비면 타입명.
                      String title = titleController.text.trim();
                      if (title.isEmpty) {
                        if (selectedType == HealthRecordType.weight) {
                          title = weightTitle(
                              parseWeightKg(typeFields.weight.text)!);
                        } else {
                          title = _getRecordTypeName(selectedType);
                        }
                      }

                      final record = HealthRecord(
                        id: '',
                        petId: petState.selectedPet!.id,
                        userId: '',
                        recordType: selectedType,
                        title: title,
                        description: descController.text.trim().isEmpty
                            ? null
                            : descController.text.trim(),
                        recordDate: selectedDate,
                        nextDate: nextDate,
                        status: selectedDate.isAfter(DateTime.now())
                            ? HealthRecordStatus.scheduled
                            : HealthRecordStatus.completed,
                        data: data,
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
    final typeFields = _TypeFieldState()..hydrate(record.data);
    HealthRecordType selectedType = record.recordType;
    DateTime selectedDate = record.recordDate;
    DateTime? nextDate = record.nextDate;
    HealthRecordStatus selectedStatus = record.status;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // 탭바·FAB 위(루트 내비게이터)에 띄워 저장 버튼 가림 방지
      useRootNavigator: true,
      useSafeArea: true,
      // 긴 폼(투약·검진 등)도 화면을 다 덮지 않고 내부 스크롤
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
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
                Row(
                  children: [
                    Expanded(
                      child: Text('건강 기록 수정',
                          style: TextStyle(
                              fontSize: 18.sp, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: AppTheme.highlightColor,
                      tooltip: '기록 삭제',
                      onPressed: () async {
                        final confirmed = await _confirmDeleteFromEdit(ctx);
                        if (confirmed != true || !ctx.mounted) return;
                        // 스와이프 삭제와 동일한 이벤트 → 동일 Repository 경로 재사용
                        context.read<HealthBloc>().add(
                            DeleteHealthRecordEvent(recordId: record.id));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('기록을 삭제했어요')),
                        );
                      },
                    ),
                  ],
                ),
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

                // 타입별 전용 입력
                _buildTypeFields(selectedType, typeFields, setSheetState),
                SizedBox(height: 12.h),

                TextField(
                  controller: titleController,
                  style: TextStyle(fontSize: 14.sp),
                  decoration: InputDecoration(
                    labelText: '제목 (선택)',
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
                      final typeError =
                          _validateTypeFields(selectedType, typeFields);
                      if (typeError != null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(typeError)),
                        );
                        return;
                      }

                      final data = _composeData(selectedType, typeFields);
                      String title = titleController.text.trim();
                      if (title.isEmpty) {
                        if (selectedType == HealthRecordType.weight) {
                          title = weightTitle(
                              parseWeightKg(typeFields.weight.text)!);
                        } else {
                          title = _getRecordTypeName(selectedType);
                        }
                      }

                      final updated = HealthRecord(
                        id: record.id,
                        petId: record.petId,
                        userId: record.userId,
                        recordType: selectedType,
                        title: title,
                        description: descController.text.trim().isEmpty
                            ? null
                            : descController.text.trim(),
                        recordDate: selectedDate,
                        nextDate: nextDate,
                        status: selectedStatus,
                        data: data,
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

  /// 수정 시트의 삭제 확인 다이얼로그. 확인 색은 경고 앰버(AppTheme.highlightColor).
  Future<bool?> _confirmDeleteFromEdit(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('기록 삭제', style: TextStyle(fontSize: 18.sp)),
        content: Text('이 기록을 삭제할까요?\n삭제한 기록은 복구할 수 없어요.',
            style: TextStyle(fontSize: 14.sp)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('취소', style: TextStyle(fontSize: 14.sp)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: AppTheme.highlightColor),
            child: Text('삭제', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
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

  /// 타입별 전용 입력 필드. 공통 필드(메모·날짜·상태) 위에 노출된다.
  /// 값은 [s]의 컨트롤러/필드에 담기고, 저장 시 buildHealthRecordData로 data Map 구성.
  Widget _buildTypeFields(
    HealthRecordType type,
    _TypeFieldState s,
    void Function(void Function()) setSheetState,
  ) {
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 14.sp),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
        );

    switch (type) {
      case HealthRecordType.weight:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: s.weight,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 14.sp),
              decoration: deco('체중 (kg)'),
            ),
            SizedBox(height: 12.h),
            Text('BCS (선택, 1~9)',
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600)),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 6.w,
              children: List.generate(9, (i) {
                final v = i + 1;
                return ChoiceChip(
                  label: Text('$v', style: TextStyle(fontSize: 12.sp)),
                  selected: s.bcs == v,
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                  onSelected: (_) =>
                      setSheetState(() => s.bcs = s.bcs == v ? null : v),
                );
              }),
            ),
          ],
        );
      case HealthRecordType.vaccination:
        return TextField(
          controller: s.vaccineType,
          style: TextStyle(fontSize: 14.sp),
          decoration: deco('백신 종류'),
        );
      case HealthRecordType.medication:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: s.medName,
              style: TextStyle(fontSize: 14.sp),
              decoration: deco('약 이름'),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: s.dosage,
              style: TextStyle(fontSize: 14.sp),
              decoration: deco('용량 (선택)'),
            ),
            SizedBox(height: 12.h),
            Text('반복 주기',
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600)),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 6.w,
              children: medicationFrequencies.map((f) {
                return ChoiceChip(
                  label: Text(f, style: TextStyle(fontSize: 12.sp)),
                  selected: s.frequency == f,
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                  onSelected: (_) => setSheetState(
                      () => s.frequency = s.frequency == f ? null : f),
                );
              }).toList(),
            ),
          ],
        );
      case HealthRecordType.checkup:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: s.hospital,
              style: TextStyle(fontSize: 14.sp),
              decoration: deco('병원 (선택)'),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: s.result,
              style: TextStyle(fontSize: 14.sp),
              decoration: deco('결과/소견 (선택)'),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: s.cost,
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 14.sp),
              decoration: deco('비용 (선택, 원)'),
            ),
          ],
        );
      case HealthRecordType.surgery:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: s.surgeryName,
              style: TextStyle(fontSize: 14.sp),
              decoration: deco('수술명'),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: s.hospital,
              style: TextStyle(fontSize: 14.sp),
              decoration: deco('병원 (선택)'),
            ),
          ],
        );
    }
  }

  /// 타입별 필수 검증. 통과 시 null, 실패 시 안내 메시지 반환.
  String? _validateTypeFields(HealthRecordType type, _TypeFieldState s) {
    switch (type) {
      case HealthRecordType.weight:
        if (parseWeightKg(s.weight.text) == null) {
          return '체중(kg)을 올바르게 입력해주세요';
        }
        return null;
      case HealthRecordType.medication:
        if (s.medName.text.trim().isEmpty) return '약 이름을 입력해주세요';
        return null;
      case HealthRecordType.surgery:
        if (s.surgeryName.text.trim().isEmpty) return '수술명을 입력해주세요';
        return null;
      case HealthRecordType.vaccination:
      case HealthRecordType.checkup:
        return null;
    }
  }

  /// [s]에서 타입별 data Map 구성.
  Map<String, dynamic> _composeData(HealthRecordType type, _TypeFieldState s) {
    return buildHealthRecordData(
      type: type,
      weightKg: parseWeightKg(s.weight.text),
      bcs: s.bcs,
      vaccineType: s.vaccineType.text,
      hospital: s.hospital.text,
      medName: s.medName.text,
      dosage: s.dosage.text,
      frequency: s.frequency,
      endDate: s.endDate,
      result: s.result.text,
      cost: parseCost(s.cost.text),
      surgeryName: s.surgeryName.text,
    );
  }
}

/// 타입별 전용 입력 상태(컨트롤러·선택값). add/edit 시트에서 공유.
class _TypeFieldState {
  final weight = TextEditingController();
  int? bcs;
  final vaccineType = TextEditingController();
  final hospital = TextEditingController();
  final medName = TextEditingController();
  final dosage = TextEditingController();
  String? frequency;
  DateTime? endDate;
  final result = TextEditingController();
  final cost = TextEditingController();
  final surgeryName = TextEditingController();

  /// 기존 레코드의 data로 초기화(수정 시트용). null-safe.
  void hydrate(Map<String, dynamic> d) {
    final w = d['weight_kg'];
    if (w is num) weight.text = w.toString();
    final b = d['bcs'];
    if (b is num) bcs = b.toInt();
    vaccineType.text = (d['vaccine_type'] as String?) ?? '';
    hospital.text = (d['hospital'] as String?) ?? '';
    medName.text = (d['med_name'] as String?) ?? '';
    dosage.text = (d['dosage'] as String?) ?? '';
    frequency = d['frequency'] as String?;
    final e = d['end_date'];
    if (e is String) endDate = DateTime.tryParse(e);
    result.text = (d['result'] as String?) ?? '';
    final c = d['cost'];
    if (c is num) cost.text = c.toInt().toString();
    surgeryName.text = (d['surgery_name'] as String?) ?? '';
  }
}
