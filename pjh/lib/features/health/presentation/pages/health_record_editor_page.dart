import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../pets/domain/entities/pet.dart';
import '../../domain/entities/health_record.dart';
import '../bloc/health_bloc.dart';
import '../widgets/health_record_data.dart';
import '../widgets/health_record_form.dart';

class HealthRecordEditorPage extends StatefulWidget {
  final Pet pet;
  final String userId;
  final HealthBloc healthBloc;
  final HealthRecord? record;
  final DateTime Function()? now;

  const HealthRecordEditorPage({
    super.key,
    required this.pet,
    required this.userId,
    required this.healthBloc,
    this.record,
    this.now,
  });

  bool get isEditing => record != null;

  @override
  State<HealthRecordEditorPage> createState() => _HealthRecordEditorPageState();
}

class _HealthRecordEditorPageState extends State<HealthRecordEditorPage> {
  static const _mutationTimeout = Duration(seconds: 20);

  late final HealthRecordFormControllers _controllers;
  final ScrollController _scrollController = ScrollController();
  late HealthRecordType _type;
  late HealthRecordStatus _status;
  late DateTime _recordDate;
  DateTime? _nextDate;
  HealthRecordFormErrors _errors = const HealthRecordFormErrors();
  String? _submitError;
  bool _submitting = false;

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _controllers = HealthRecordFormControllers(record: record);
    _type = record?.recordType ?? HealthRecordType.vaccination;
    _status = record?.status ?? HealthRecordStatus.completed;
    _recordDate = record?.recordDate ?? _dateOnly(_now);
    _nextDate = record?.nextDate;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controllers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.healthBloc,
      child: PopScope(
        canPop: !_submitting,
        child: Scaffold(
          appBar: AppBar(
            leadingWidth: 68.w,
            leading: TextButton(
              key: const Key('health_editor_close'),
              onPressed: _submitting ? null : () => Navigator.pop(context),
              child: Text(widget.isEditing ? '취소' : '닫기'),
            ),
            title: Text(widget.isEditing ? '건강 기록 수정' : '건강 기록 추가'),
            actions: [
              TextButton(
                key: const Key('health_editor_top_submit'),
                onPressed: _submitting ? null : _submit,
                child: Text(widget.isEditing ? '완료' : '저장'),
              ),
              SizedBox(width: 4.w),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    key: const Key('health_editor_scroll'),
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildIntro(context),
                        SizedBox(height: 24.h),
                        HealthRecordForm(
                          selectedType: _type,
                          selectedStatus: _status,
                          controllers: _controllers,
                          recordDate: _recordDate,
                          nextDate: _nextDate,
                          errors: _errors,
                          enabled: !_submitting,
                          onTypeChanged: (value) => setState(() {
                            _type = value;
                            _errors = const HealthRecordFormErrors();
                            _submitError = null;
                          }),
                          onStatusChanged: (value) =>
                              setState(() => _status = value),
                          onBcsChanged: (value) =>
                              setState(() => _controllers.bcs = value),
                          onFrequencyChanged: (value) => setState(
                            () => _controllers.frequency = value,
                          ),
                          onRecordDatePressed: _pickRecordDate,
                          onNextDatePressed: _pickNextDate,
                          onClearNextDate: () =>
                              setState(() => _nextDate = null),
                        ),
                        SizedBox(height: 18.h),
                        _buildNotice(context),
                        if (widget.isEditing) ...[
                          SizedBox(height: 28.h),
                          _buildDeleteAction(context),
                        ],
                      ],
                    ),
                  ),
                ),
                _buildStickySubmit(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntro(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest
            : AppTheme.actionContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 23.r,
            backgroundColor: isDark ? theme.colorScheme.surface : Colors.white,
            foregroundColor:
                isDark ? theme.colorScheme.onSurface : AppTheme.brandDeep,
            child: Text(
              widget.pet.name.characters.first,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: AppTheme.fontHeading.sp,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isEditing ? _typeLabel(_type) : '어떤 기록을 남길까요?',
                  style: TextStyle(
                    color: isDark
                        ? theme.colorScheme.onSurface
                        : AppTheme.brandDeep,
                    fontSize: AppTheme.fontHeading.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  widget.isEditing
                      ? '${_formatDate(_recordDate)} · ${widget.pet.name}'
                      : '${widget.pet.name} · 저장 전까지 입력 내용을 유지합니다.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: AppTheme.fontCaption.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotice(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            color: AppTheme.actionBase,
            size: 20,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              '이 기록은 건강 관리를 돕는 보호자 개인 기록이며 의료 진단이나 수의사의 판단을 대신하지 않습니다.',
              style: TextStyle(
                fontSize: AppTheme.fontCaption.sp,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteAction(BuildContext context) {
    return OutlinedButton.icon(
      key: const Key('health_editor_delete'),
      onPressed: _submitting ? null : _confirmAndDelete,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        foregroundColor: AppTheme.errorColor,
        side: const BorderSide(color: AppTheme.errorColor),
      ),
      icon: const Icon(Icons.delete_outline),
      label: const Text('이 기록 삭제'),
    );
  }

  Widget _buildStickySubmit(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: const Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_submitError != null) ...[
            Semantics(
              liveRegion: true,
              child: Container(
                key: const Key('health_editor_submit_error'),
                width: double.infinity,
                padding: EdgeInsets.all(10.w),
                margin: EdgeInsets.only(bottom: 10.h),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm.r),
                ),
                child: Text(
                  _submitError!,
                  style: TextStyle(
                    color: AppTheme.errorColor,
                    fontSize: AppTheme.fontCaption.sp,
                  ),
                ),
              ),
            ),
          ],
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              key: const Key('health_editor_submit'),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(widget.isEditing ? '변경사항 저장' : '건강 기록 저장'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickRecordDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _recordDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(_now.year + 10, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _recordDate = picked;
      _errors = const HealthRecordFormErrors();
    });
  }

  Future<void> _pickNextDate() async {
    final initial = _nextDate != null && !_nextDate!.isBefore(_recordDate)
        ? _nextDate!
        : _recordDate.add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _recordDate,
      lastDate: DateTime(_now.year + 15, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _nextDate = picked;
      _errors = const HealthRecordFormErrors();
    });
  }

  HealthRecordFormErrors _validate() {
    String? primary;
    switch (_type) {
      case HealthRecordType.vaccination:
        if (_controllers.vaccineType.text.trim().isEmpty) {
          primary = '백신 종류를 입력해주세요.';
        }
        break;
      case HealthRecordType.checkup:
        break;
      case HealthRecordType.weight:
        if (parseWeightKg(_controllers.weight.text) == null) {
          primary = '0보다 큰 체중을 kg 단위로 입력해주세요.';
        }
        break;
      case HealthRecordType.medication:
        if (_controllers.medicationName.text.trim().isEmpty) {
          primary = '약 이름을 입력해주세요.';
        }
        break;
      case HealthRecordType.surgery:
        if (_controllers.surgeryName.text.trim().isEmpty) {
          primary = '수술명을 입력해주세요.';
        }
        break;
    }
    final costRaw = _controllers.cost.text.trim();
    final cost = costRaw.isNotEmpty && parseCost(costRaw) == null
        ? '비용은 0 이상의 숫자로 입력해주세요.'
        : null;
    final nextDate = _nextDate != null && _nextDate!.isBefore(_recordDate)
        ? '다음 예정일은 기록 날짜보다 빠를 수 없어요.'
        : null;
    return HealthRecordFormErrors(
      primary: primary,
      cost: cost,
      nextDate: nextDate,
    );
  }

  Future<void> _submit() async {
    final errors = _validate();
    if (errors.hasAny) {
      setState(() {
        _errors = errors;
        _submitError = '입력한 내용을 확인해주세요.';
      });
      unawaited(
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
      return;
    }

    final current = widget.healthBloc.state;
    if (current is! HealthLoaded ||
        current.petId != widget.pet.id ||
        current.mutation.phase == HealthMutationPhase.pending) {
      setState(() => _submitError = '건강 기록을 불러온 뒤 다시 시도해주세요.');
      return;
    }

    final weight = parseWeightKg(_controllers.weight.text);
    final titleInput = _controllers.title.text.trim();
    final record = widget.record;
    final value = HealthRecord(
      id: record?.id ?? '',
      petId: widget.pet.id,
      userId:
          record?.userId.isNotEmpty == true ? record!.userId : widget.userId,
      recordType: _type,
      title: titleInput.isEmpty ? _defaultTitle(weight) : titleInput,
      description: _controllers.memo.text.trim().isEmpty
          ? null
          : _controllers.memo.text.trim(),
      recordDate: _recordDate,
      nextDate: _nextDate,
      status: _status,
      data: buildHealthRecordData(
        type: _type,
        weightKg: weight,
        bcs: _controllers.bcs,
        vaccineType: _controllers.vaccineType.text,
        hospital: _controllers.hospital.text,
        medName: _controllers.medicationName.text,
        dosage: _controllers.dosage.text,
        frequency: _controllers.frequency,
        result: _controllers.checkupResult.text,
        cost: parseCost(_controllers.cost.text),
        surgeryName: _controllers.surgeryName.text,
      ),
      createdAt: record?.createdAt ?? _now,
      updatedAt: _now,
    );
    final operationId =
        '${widget.isEditing ? 'update' : 'add'}-${_now.microsecondsSinceEpoch}';

    setState(() {
      _submitting = true;
      _submitError = null;
      _errors = const HealthRecordFormErrors();
    });
    if (widget.isEditing) {
      widget.healthBloc.add(
        UpdateHealthRecordEvent(record: value, operationId: operationId),
      );
    } else {
      widget.healthBloc.add(
        AddHealthRecordEvent(record: value, operationId: operationId),
      );
    }
    final outcome = await _waitForMutation(operationId);
    if (!mounted) return;
    if (outcome.phase == HealthMutationPhase.succeeded) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _submitting = false;
      _submitError = outcome.message ?? '기록을 저장하지 못했어요. 입력 내용은 유지되니 다시 시도해주세요.';
    });
  }

  Future<void> _confirmAndDelete() async {
    final record = widget.record;
    if (record == null) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      builder: (sheetContext) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_typeLabel(record.recordType)} 기록을 삭제할까요?',
              style: TextStyle(
                fontSize: AppTheme.fontHeading.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '${_formatDate(record.recordDate)}의 ${recordCardSubtitle(record)} 기록을 삭제합니다.',
              style: TextStyle(
                fontSize: AppTheme.fontBody.sp,
                color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 14.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
              ),
              child: const Text(
                '삭제 후 이 기록은 건강 목록·변화 추이·PDF 리포트에서 제외됩니다. 삭제한 기록은 복구할 수 없습니다.',
              ),
            ),
            SizedBox(height: 18.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetContext, false),
                    child: const Text('취소'),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: ElevatedButton(
                    key: const Key('health_delete_confirm'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorColor,
                    ),
                    onPressed: () => Navigator.pop(sheetContext, true),
                    child: const Text('기록 삭제'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final operationId = 'delete-${record.id}-${_now.microsecondsSinceEpoch}';
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    widget.healthBloc.add(
      DeleteHealthRecordEvent(
        recordId: record.id,
        operationId: operationId,
      ),
    );
    final outcome = await _waitForMutation(operationId);
    if (!mounted) return;
    if (outcome.phase == HealthMutationPhase.succeeded) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _submitting = false;
      _submitError = outcome.message ?? '기록을 삭제하지 못했어요. 다시 시도해주세요.';
    });
  }

  Future<HealthMutationState> _waitForMutation(String operationId) {
    return widget.healthBloc.stream
        .where((state) => state is HealthLoaded)
        .cast<HealthLoaded>()
        .map((state) => state.mutation)
        .firstWhere(
          (mutation) =>
              mutation.matches(operationId) &&
              mutation.phase != HealthMutationPhase.pending,
        )
        .timeout(
          _mutationTimeout,
          onTimeout: () => HealthMutationState(
            operationId: operationId,
            phase: HealthMutationPhase.failed,
            message: '처리 결과를 확인하지 못했어요. 입력 내용은 유지되니 다시 시도해주세요.',
          ),
        );
  }

  String _defaultTitle(double? weight) => switch (_type) {
        HealthRecordType.vaccination => _controllers.vaccineType.text.trim(),
        HealthRecordType.checkup => '건강검진',
        HealthRecordType.weight => weightTitle(weight!),
        HealthRecordType.medication => _controllers.medicationName.text.trim(),
        HealthRecordType.surgery => _controllers.surgeryName.text.trim(),
      };

  String _typeLabel(HealthRecordType type) => switch (type) {
        HealthRecordType.vaccination => '예방접종',
        HealthRecordType.checkup => '건강검진',
        HealthRecordType.weight => '체중',
        HealthRecordType.medication => '투약',
        HealthRecordType.surgery => '수술',
      };

  String _formatDate(DateTime value) =>
      '${value.year}년 ${value.month}월 ${value.day}일';

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
