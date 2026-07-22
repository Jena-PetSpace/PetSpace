part of '../pages/health_main_page.dart';

/// 기존 호출부 이름을 유지하면서 기록 입력을 root full-screen task로 전환한다.
extension _HealthMainSheets on _HealthMainViewState {
  static const _mutationWaitTimeout = Duration(seconds: 20);

  Future<void> _showAddRecordSheet(BuildContext context) async {
    final petState = context.read<PetBloc>().state;
    final pet = petState is PetLoaded ? petState.selectedPet : null;
    final healthState = context.read<HealthBloc>().state;
    final healthBloc = context.read<HealthBloc>();
    final messenger = ScaffoldMessenger.of(context);
    if (pet == null ||
        healthState is! HealthLoaded ||
        healthState.petId != pet.id ||
        healthState.mutation.phase == HealthMutationPhase.pending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('건강 기록을 불러온 뒤 다시 시도해주세요.')),
      );
      return;
    }

    final saved = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => HealthRecordEditorPage(
          pet: pet,
          userId: healthState.userId ?? pet.userId,
          healthBloc: healthBloc,
        ),
      ),
    );
    if (!mounted || saved != true) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('건강 기록을 저장했어요.')),
    );
  }

  Future<void> _showEditRecordSheet(
    BuildContext context,
    HealthRecord record,
  ) async {
    final petState = context.read<PetBloc>().state;
    final pet = petState is PetLoaded ? petState.selectedPet : null;
    final healthState = context.read<HealthBloc>().state;
    final healthBloc = context.read<HealthBloc>();
    final messenger = ScaffoldMessenger.of(context);
    if (pet == null ||
        healthState is! HealthLoaded ||
        healthState.petId != record.petId ||
        healthState.mutation.phase == HealthMutationPhase.pending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('건강 기록을 불러온 뒤 다시 시도해주세요.')),
      );
      return;
    }

    final saved = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => HealthRecordEditorPage(
          pet: pet,
          userId: healthState.userId ?? pet.userId,
          healthBloc: healthBloc,
          record: record,
        ),
      ),
    );
    if (!mounted || saved != true) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('건강 기록 변경을 반영했어요.')),
    );
  }

  Future<HealthMutationState> _waitForMutation(
    HealthBloc bloc,
    String operationId,
  ) {
    return bloc.stream
        .where((state) => state is HealthLoaded)
        .cast<HealthLoaded>()
        .map((loaded) => loaded.mutation)
        .firstWhere(
          (mutation) =>
              mutation.matches(operationId) &&
              mutation.phase != HealthMutationPhase.pending,
        )
        .timeout(
          _mutationWaitTimeout,
          onTimeout: () => HealthMutationState(
            operationId: operationId,
            phase: HealthMutationPhase.failed,
            message: '처리 결과를 확인하지 못했어요. 다시 시도해주세요.',
          ),
        );
  }

  IconData _getRecordIcon(HealthRecordType type) => switch (type) {
        HealthRecordType.vaccination => Icons.vaccines_outlined,
        HealthRecordType.checkup => Icons.health_and_safety_outlined,
        HealthRecordType.weight => Icons.monitor_weight_outlined,
        HealthRecordType.medication => Icons.medication_outlined,
        HealthRecordType.surgery => Icons.local_hospital_outlined,
      };

  Color _getRecordColor(HealthRecordType _) => AppTheme.actionBase;

  String _getRecordTypeName(HealthRecordType type) => switch (type) {
        HealthRecordType.vaccination => '예방접종',
        HealthRecordType.checkup => '건강검진',
        HealthRecordType.weight => '체중',
        HealthRecordType.medication => '투약',
        HealthRecordType.surgery => '수술',
      };

  String _getStatusName(HealthRecordStatus status) => switch (status) {
        HealthRecordStatus.scheduled => '예정',
        HealthRecordStatus.completed => '완료',
        HealthRecordStatus.overdue => '지남',
        HealthRecordStatus.cancelled => '취소',
      };

  Color _getStatusColor(HealthRecordStatus status) => switch (status) {
        HealthRecordStatus.scheduled => AppTheme.actionBase,
        HealthRecordStatus.completed => AppTheme.successColor,
        HealthRecordStatus.overdue => AppTheme.errorColor,
        HealthRecordStatus.cancelled => AppTheme.textMuted,
      };

  String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}
