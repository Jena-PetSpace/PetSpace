import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_state_view.dart';
import '../../../pets/presentation/bloc/pet_bloc.dart';
import '../../../pets/presentation/bloc/pet_state.dart';
import '../../../pets/domain/entities/pet.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/health_record.dart';
import '../controllers/health_emotion_loader.dart';
import '../bloc/health_bloc.dart';
import '../../../emotion/domain/entities/emotion_analysis.dart';
import '../widgets/health_record_card.dart';
import '../widgets/health_record_data.dart';
import 'health_pdf_preview_page.dart';
import 'health_record_editor_page.dart';
import '../widgets/weight_trend_chart.dart';
import '../widgets/emotion_trend_mini_chart.dart';

part '../widgets/health_record_sheets.dart';

class HealthMainPage extends StatelessWidget {
  final HealthBloc? healthBloc;
  final HealthEmotionLoader? emotionLoader;

  const HealthMainPage({
    super.key,
    this.healthBloc,
    this.emotionLoader,
  });

  @override
  Widget build(BuildContext context) {
    final child = _HealthMainView(
      emotionLoader: emotionLoader ?? sl<HealthEmotionLoader>(),
    );
    final provided = healthBloc;
    return provided == null
        ? BlocProvider(create: (_) => sl<HealthBloc>(), child: child)
        : BlocProvider.value(value: provided, child: child);
  }
}

class _HealthMainView extends StatefulWidget {
  final HealthEmotionLoader emotionLoader;

  const _HealthMainView({required this.emotionLoader});

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
      context.read<HealthBloc>().add(
            LoadHealthRecords(petId: petState.selectedPet!.id, userId: userId),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PetBloc, PetState>(
      listenWhen: (previous, current) =>
          _selectedPetId(previous) != _selectedPetId(current),
      listener: (context, petState) {
        setState(() => _selectedFilter = null);
        if (_selectedPetId(petState) != null) {
          _loadHealthData();
        }
      },
      builder: (context, petState) {
        final selectedPet = petState is PetLoaded ? petState.selectedPet : null;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              '건강',
              style: TextStyle(
                fontSize: AppTheme.fontHeading.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.more_horiz),
                tooltip: '건강 도구',
                onPressed: () => _showHealthToolsSheet(context),
              ),
            ],
          ),
          body: petState is! PetLoaded
              ? const Center(child: CircularProgressIndicator())
              : selectedPet == null
                  ? _buildEmptyPetState()
                  : BlocBuilder<HealthBloc, HealthState>(
                      builder: (context, state) {
                        if (state is HealthLoading) {
                          return _buildLoadingState(selectedPet);
                        }

                        if (state is HealthError) {
                          return _buildErrorState(selectedPet);
                        }

                        if (state is HealthLoaded) {
                          if (state.petId != selectedPet.id) {
                            return _buildLoadingState(selectedPet);
                          }
                          return _buildContent(state, selectedPet);
                        }

                        return const Center(child: CircularProgressIndicator());
                      },
                    ),
        );
      },
    );
  }

  String? _selectedPetId(PetState state) =>
      state is PetLoaded ? state.selectedPet?.id : null;

  Widget _buildContent(HealthLoaded state, Pet pet) {
    final visibleRecords = _selectedFilter == null
        ? state.records
        : state.records
            .where((record) => record.recordType == _selectedFilter)
            .toList();
    final upcomingCare = state.upcomingAlerts
        .where((record) => record.dueDate != null)
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    final selectedLabel =
        _filterTypes.firstWhere((entry) => entry.$1 == _selectedFilter).$2;
    return RefreshIndicator(
      onRefresh: _refreshHealthData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPetBar(pet),
            SizedBox(height: 22.h),
            _buildSectionHeader(
              title: '다음 케어',
              trailing: _upcomingCareSummary(upcomingCare.length),
              trailingKey: const Key('health_next_care_summary'),
            ),
            SizedBox(height: 10.h),
            _buildUpcomingAlerts(upcomingCare),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: ElevatedButton.icon(
                  key: const Key('health_add_record_cta'),
                  onPressed: () => _showAddRecordSheet(context),
                  icon: const Icon(Icons.add),
                  label: const Text('건강 기록 추가'),
                ),
              ),
            ),
            SizedBox(height: 26.h),
            _buildSectionHeader(
              title: '최근 기록',
              trailing: '$selectedLabel ${visibleRecords.length}건',
            ),
            SizedBox(height: 10.h),
            _buildFilterChips(),
            SizedBox(height: 12.h),
            if (state.records.isEmpty)
              _buildEmptyRecordState()
            else if (visibleRecords.isEmpty)
              PetSpaceStateView.empty(
                key: ValueKey('empty-filter-${_selectedFilter?.name}'),
                icon: Icons.filter_alt_off_outlined,
                title: _emptyFilterMessage(),
                message: '다른 기록 유형을 선택하거나 전체 기록으로 돌아가세요.',
                actionLabel: '전체 기록 보기',
                onAction: () => setState(() => _selectedFilter = null),
              )
            else
              Column(
                children: visibleRecords
                    .map(
                      (record) => Padding(
                        padding: EdgeInsets.only(bottom: 10.h),
                        child: Dismissible(
                          key: Key(record.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: EdgeInsets.only(right: 20.w),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMd.r,
                              ),
                            ),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (_) async {
                            final confirmed = await _confirmDelete(
                              context,
                              record,
                            );
                            if (confirmed == true && mounted) {
                              await _requestDelete(record.id);
                            }
                            return false;
                          },
                          child: HealthRecordCard(
                            icon: _getRecordIcon(record.recordType),
                            iconColor: _getRecordColor(record.recordType),
                            title: recordCardDisplayTitle(record),
                            subtitle: recordCardDetail(record),
                            date: _formatDate(record.recordDate),
                            status: _getStatusName(record.status),
                            statusColor: _getStatusColor(record.status),
                            semanticsLabel:
                                '${recordCardDisplayTitle(record)}, '
                                '${recordCardDetail(record)}, '
                                '${_formatDate(record.recordDate)}, '
                                '${_getStatusName(record.status)}, 편집',
                            onTap: () => _showEditRecordSheet(context, record),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            if (state.error != null) ...[
              SizedBox(height: 12.h),
              _buildInlineError(
                '다음 케어 일정을 새로 확인하지 못했어요. 최근 기록은 그대로 유지됩니다.',
              ),
            ],
            SizedBox(height: 28.h),
            _buildSectionHeader(title: '건강 변화', trailing: pet.name),
            SizedBox(height: 10.h),
            if (state.records.any(
              (record) => record.recordType == HealthRecordType.weight,
            )) ...[
              WeightTrendChart(records: state.records),
              SizedBox(height: 12.h),
            ],
            _buildEmotionTrend(),
            SizedBox(height: 12.h),
            _buildPdfCard(pet, state.records.isNotEmpty),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String trailing,
    Key? trailingKey,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: AppTheme.fontHeading.sp,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Flexible(
          child: Text(
            key: trailingKey,
            trailing,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppTheme.fontCaption.sp,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmotionTrend() {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated ? authState.user.uid : null;
    final petState = context.read<PetBloc>().state;
    final petId = petState is PetLoaded ? petState.selectedPet?.id : null;
    if (userId == null || petId == null) return const SizedBox.shrink();
    return EmotionTrendMiniChart(
      key: ValueKey('emotion_trend_$petId'),
      userId: userId,
      petId: petId,
      loader: widget.emotionLoader,
    );
  }

  /// 건강 요약서 PDF 미리보기로 이동(저장·공유는 미리보기 내장 액션).
  /// 펫 미선택·기록 0건 시 안내.
  Future<void> _exportHealthPdf(BuildContext context) async {
    final petState = context.read<PetBloc>().state;
    final pet = petState is PetLoaded ? petState.selectedPet : null;
    if (pet == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('반려동물을 먼저 선택해주세요')));
      return;
    }

    final healthState = context.read<HealthBloc>().state;
    final records =
        healthState is HealthLoaded ? healthState.records : <HealthRecord>[];
    if (records.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('내보낼 건강 기록이 없습니다')));
      return;
    }

    final authState = context.read<AuthBloc>().state;
    final ownerName =
        authState is AuthAuthenticated ? authState.user.displayName : '보호자';
    final userId = authState is AuthAuthenticated ? authState.user.uid : null;

    // 최근 AI 감정 분석 1건(선택, 읽기 전용).
    EmotionAnalysis? latest;
    if (userId != null) {
      latest = await widget.emotionLoader.loadLatest(
        userId: userId,
        petId: pet.id,
      );
    }

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).push(
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

  /// 유형 선택은 아이콘·라벨로 구분하고 선택색은 브랜드 action 하나로 통일한다.
  static const _filterTypeColors = <HealthRecordType?, Color>{
    null: AppTheme.actionBase,
    HealthRecordType.vaccination: AppTheme.actionBase,
    HealthRecordType.checkup: AppTheme.actionBase,
    HealthRecordType.weight: AppTheme.actionBase,
    HealthRecordType.medication: AppTheme.actionBase,
    HealthRecordType.surgery: AppTheme.actionBase,
  };

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      key: const Key('health_record_filter_strip'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < _filterTypes.length; i++) ...[
            if (i > 0) SizedBox(width: 6.w),
            _typeChip(
              key: Key(
                'health_filter_${_filterTypes[i].$1?.name ?? 'all'}',
              ),
              label: _filterTypes[i].$2,
              color: _filterTypeColors[_filterTypes[i].$1]!,
              isSelected: _selectedFilter == _filterTypes[i].$1,
              onTap: () => setState(() => _selectedFilter = _filterTypes[i].$1),
            ),
          ],
        ],
      ),
    );
  }

  /// 라벨 알약 칩 — 필터와 시트의 유형 선택이 공용으로 사용.
  Widget _typeChip({
    Key? key,
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Semantics(
      key: key,
      button: true,
      selected: isSelected,
      label: '$label 기록 필터',
      child: Material(
        color: isSelected ? color : theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm.r),
          side: BorderSide(color: isSelected ? color : AppTheme.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm.r),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: AppTheme.fontCaption.sp,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingAlerts(List<HealthRecord> alerts) {
    final theme = Theme.of(context);
    final alert = alerts.isEmpty ? null : alerts.first;
    final dueDate = alert?.dueDate;
    return Container(
      key: const Key('health_next_care_card'),
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
        border: Border.all(color: AppTheme.border),
        boxShadow:
            theme.brightness == Brightness.dark ? null : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (alert == null || dueDate == null)
            Row(
              key: const Key('health_next_care_empty'),
              children: [
                _careIcon(Icons.event_available_outlined),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '예정된 다음 케어가 없어요',
                        style: TextStyle(
                          fontSize: AppTheme.fontBody.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        '기록에 다음 예정일을 남기면 이곳에서 확인할 수 있어요.',
                        style: TextStyle(
                          fontSize: AppTheme.fontCaption.sp,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            Semantics(
              key: const Key('health_next_care_item'),
              label:
                  '${alert.title}, ${_formatDate(dueDate)}, ${_formatDday(alert.daysUntilDue())}',
              child: Row(
                children: [
                  _careIcon(_getRecordIcon(alert.recordType)),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          key: const Key('health_next_care_title'),
                          alert.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppTheme.fontBody.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          '${_formatDate(dueDate)} · ${_getRecordTypeName(alert.recordType)}',
                          style: TextStyle(
                            fontSize: AppTheme.fontCaption.sp,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: AppTheme.actionContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm.r),
                    ),
                    child: Text(
                      _formatDday(alert.daysUntilDue()),
                      style: TextStyle(
                        fontSize: AppTheme.fontMicro.sp,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.brandDeep,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            Divider(height: 1, color: AppTheme.border.withValues(alpha: 0.8)),
            SizedBox(height: 10.h),
            Text(
              '기록의 다음 예정일을 기준으로 표시합니다. 자동 알림 제공 여부와는 별개입니다.',
              style: TextStyle(
                fontSize: AppTheme.fontMicro.sp,
                height: 1.45,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _upcomingCareSummary(int count) {
    if (count == 0) return '예정 없음';
    if (count == 1) return '가까운 일정 1개';
    return '가까운 일정 $count개 중 1개';
  }

  Widget _careIcon(IconData icon) {
    return Container(
      width: 44.w,
      height: 44.w,
      decoration: BoxDecoration(
        color: AppTheme.actionContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm.r),
      ),
      child: Icon(icon, color: AppTheme.actionBase, size: 22.w),
    );
  }

  Widget _buildPetBar(Pet pet) {
    final theme = Theme.of(context);
    final initial = pet.name.trim().isEmpty ? 'P' : pet.name.characters.first;
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: InkWell(
        key: const Key('health_pet_bar'),
        onTap: () => context.push('/pets'),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22.r,
                  backgroundColor: AppTheme.actionContainer,
                  foregroundColor: AppTheme.brandDeep,
                  child: Text(
                    initial,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${pet.name}의 건강',
                        style: TextStyle(
                          fontSize: AppTheme.fontBody.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        '대표 반려동물 · 다른 반려동물 선택',
                        style: TextStyle(
                          fontSize: AppTheme.fontCaption.sp,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.expand_more),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPdfCard(Pet pet, bool enabled) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: AppTheme.actionContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm.r),
            ),
            alignment: Alignment.center,
            child: Text(
              'PDF',
              style: TextStyle(
                color: AppTheme.brandDeep,
                fontWeight: FontWeight.w700,
                fontSize: AppTheme.fontMicro.sp,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${pet.name} 건강 요약서',
                  style: TextStyle(
                    fontSize: AppTheme.fontBody.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  enabled
                      ? '건강 기록을 미리 확인한 뒤 기기에 저장하거나 공유합니다.'
                      : '기록을 추가하면 건강 요약서를 만들 수 있어요.',
                  style: TextStyle(
                    fontSize: AppTheme.fontCaption.sp,
                    height: 1.4,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  key: const Key('health_pdf_preview_button'),
                  onPressed: enabled ? () => _exportHealthPdf(context) : null,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 44),
                    alignment: Alignment.centerLeft,
                  ),
                  child: const Text('미리보기'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRecordState() {
    return const PetSpaceStateView.empty(
      icon: Icons.health_and_safety_outlined,
      title: '아직 건강 기록이 없어요',
      message: '백신, 검진, 체중, 투약, 수술 기록을 남겨 변화를 확인해보세요.',
    );
  }

  Widget _buildEmptyPetState() {
    return PetSpaceStateView.empty(
      icon: Icons.pets,
      title: '반려동물을 먼저 등록해주세요',
      message: '등록한 반려동물별로 건강 기록과 예정 일정을 나누어 관리해요.',
      actionLabel: '반려동물 등록',
      onAction: () => context.push('/pets'),
    );
  }

  Widget _buildLoadingState(Pet pet) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPetBar(pet),
          SizedBox(height: 22.h),
          _buildSectionHeader(title: '다음 케어', trailing: '확인 중'),
          SizedBox(height: 10.h),
          ...List.generate(
            3,
            (index) => Container(
              key: Key('health_loading_skeleton_$index'),
              height: index == 0 ? 86.h : 60.h,
              margin: EdgeInsets.only(bottom: 12.h),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
                border: Border.all(color: AppTheme.border),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Pet pet) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          _buildPetBar(pet),
          SizedBox(height: 18.h),
          PetSpaceStateView.error(
            icon: Icons.refresh_outlined,
            title: '건강 기록을 불러오지 못했어요',
            message: '선택한 반려동물은 유지됩니다. 연결을 확인한 뒤 다시 시도해주세요.',
            actionLabel: '다시 시도',
            onAction: _loadHealthData,
          ),
        ],
      ),
    );
  }

  Widget _buildInlineError(String message) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm.r),
        ),
        child: Text(
          message,
          style: TextStyle(
            color: AppTheme.errorColor,
            fontSize: AppTheme.fontCaption.sp,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Future<void> _showHealthToolsSheet(BuildContext pageContext) async {
    await showModalBottomSheet<void>(
      context: pageContext,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
              child: Text(
                '건강 도구',
                style: TextStyle(
                  fontSize: AppTheme.fontHeading.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(sheetContext).textTheme.titleLarge?.color,
                ),
              ),
            ),
            ListTile(
              minTileHeight: 56,
              leading: const Icon(
                Icons.notifications_none,
                color: AppTheme.actionBase,
              ),
              title: const Text('건강 알림'),
              subtitle: const Text('예정일 알림 제공 범위와 기기 알림 테스트'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(sheetContext);
                pageContext.push('/health/alert-settings');
              },
            ),
            ListTile(
              minTileHeight: 56,
              leading: const Icon(
                Icons.description_outlined,
                color: AppTheme.actionBase,
              ),
              title: const Text('건강 리포트'),
              subtitle: const Text('선택한 반려동물의 PDF 미리보기'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(sheetContext);
                _exportHealthPdf(pageContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(
    BuildContext context,
    HealthRecord record,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${_getRecordTypeName(record.recordType)} 기록을 삭제할까요?',
          style: TextStyle(fontSize: 18.sp),
        ),
        content: Text(
          '${_formatDate(record.recordDate)}의 ${recordCardSubtitle(record)} 기록을 삭제합니다.\n\n'
          '건강 목록·변화 추이·PDF 리포트에서 제외되며 복구할 수 없습니다.',
          style: TextStyle(fontSize: 14.sp, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('취소', style: TextStyle(fontSize: 14.sp)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: Text('기록 삭제', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshHealthData() async {
    final petId = _selectedPetId(context.read<PetBloc>().state);
    if (petId == null) return;
    final bloc = context.read<HealthBloc>();
    _loadHealthData();
    try {
      await bloc.stream
          .firstWhere(
            (state) =>
                state is HealthError ||
                (state is HealthLoaded && state.petId == petId),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      // The existing page-level loading/error state remains authoritative.
    }
  }

  Future<bool> _requestDelete(String recordId) async {
    final bloc = context.read<HealthBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final operationId =
        'delete-$recordId-${DateTime.now().microsecondsSinceEpoch}';
    bloc.add(
      DeleteHealthRecordEvent(recordId: recordId, operationId: operationId),
    );
    final result = await _waitForMutation(bloc, operationId);
    if (!mounted) return false;
    if (result.phase == HealthMutationPhase.failed) {
      messenger.showSnackBar(
        SnackBar(content: Text(result.message ?? '기록을 삭제하지 못했습니다. 다시 시도해주세요.')),
      );
      return false;
    }
    messenger.showSnackBar(const SnackBar(content: Text('기록을 삭제했어요')));
    return true;
  }

  String _formatDday(int? days) {
    if (days == null) return '일정 없음';
    if (days == 0) return 'D-Day';
    return days > 0 ? 'D-$days' : 'D+${-days}';
  }
}
