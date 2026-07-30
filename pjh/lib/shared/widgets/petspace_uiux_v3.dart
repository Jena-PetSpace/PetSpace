import 'package:flutter/material.dart';

/// 2026-07-30 승인 Wave 화면만 명시적으로 사용하는 opt-in UI 토큰.
///
/// 전역 [ThemeData]와 기존 공용 위젯을 변경하지 않아 홈 탭과 AI 결과 화면의
/// 렌더링을 간접적으로 바꾸지 않는다.
abstract final class PetSpaceV3Tokens {
  static const brandDeep = Color(0xFF1E3A5F);
  static const action = Color(0xFF2F6399);
  static const accent = Color(0xFF36699E);
  static const canvas = Color(0xFFF7F8FA);
  static const paleBlue = Color(0xFFEEF5FB);
  static const surface = Colors.white;
  static const outline = Color(0xFFE5E8EC);
  static const text = Color(0xFF1F2937);
  static const textMuted = Color(0xFF667085);
  static const disabledSurface = Color(0xFFE9EDF2);
  static const disabledText = Color(0xFF98A2B3);
  static const success = Color(0xFF217A4A);
  static const caution = Color(0xFF8A5A00);
  static const destructive = Color(0xFFB42318);

  static const radius = 12.0;
  static const sectionGap = 24.0;
  static const contentPadding = 16.0;
  static const minimumTapTarget = 44.0;
}

/// 흰 surface와 장식적 outline을 사용하는 승인 Wave 전용 카드.
///
/// outline은 상호작용 여부의 유일한 단서가 아니다. 탭 가능한 카드는 호출부가
/// 명확한 텍스트·아이콘을 제공하고 InkWell의 focus/pressed 상태를 함께 쓴다.
class PetSpaceV3Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Color backgroundColor;

  const PetSpaceV3Card({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(PetSpaceV3Tokens.contentPadding),
    this.onTap,
    this.semanticLabel,
    this.backgroundColor = PetSpaceV3Tokens.surface,
  });

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: backgroundColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PetSpaceV3Tokens.radius),
        side: const BorderSide(color: PetSpaceV3Tokens.outline),
      ),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: onTap == null ? 0 : PetSpaceV3Tokens.minimumTapTarget,
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (semanticLabel == null) return card;
    return Semantics(
      label: semanticLabel,
      container: true,
      button: onTap != null,
      enabled: onTap == null ? null : true,
      excludeSemantics: true,
      onTap: onTap,
      child: card,
    );
  }
}

/// 승인 Wave의 단일 주요 행동에 사용하는 고정 대비 CTA.
class PetSpaceV3PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const PetSpaceV3PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final background =
        enabled ? PetSpaceV3Tokens.action : PetSpaceV3Tokens.disabledSurface;
    final foreground = enabled ? Colors.white : PetSpaceV3Tokens.disabledText;

    return Semantics(
      label: loading ? '$label, 처리 중' : label,
      button: true,
      enabled: enabled,
      liveRegion: loading,
      excludeSemantics: true,
      onTap: enabled ? onPressed : null,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(PetSpaceV3Tokens.radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 52,
              minWidth: double.infinity,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading)
                    SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  else if (icon != null)
                    Icon(icon, size: 20, color: foreground),
                  if (loading || icon != null) const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 15,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum PetSpaceV3StateKind {
  initial,
  empty,
  searchEmpty,
  blockedHidden,
  network,
  server,
  permission,
  session,
}

/// 장식 이모지 없이 상태와 복구 행동을 명확히 구분하는 승인 Wave 전용 상태 UI.
///
/// 작은 화면에서도 복구 행동을 유지하기 위해 내부 스크롤을 소유한다. 화면
/// 본문의 직접 자식으로 쓸 때는 [Expanded]처럼 유한한 높이를 제공하고, 다른
/// 수직 scrollable 안에는 중첩하지 않는다.
class PetSpaceV3StateView extends StatelessWidget {
  final PetSpaceV3StateKind kind;
  final String title;
  final String message;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  const PetSpaceV3StateView({
    super.key,
    required this.kind,
    required this.title,
    required this.message,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  bool get _isUrgent =>
      kind == PetSpaceV3StateKind.network ||
      kind == PetSpaceV3StateKind.server ||
      kind == PetSpaceV3StateKind.permission ||
      kind == PetSpaceV3StateKind.session;

  IconData? get _icon => switch (kind) {
        PetSpaceV3StateKind.initial => null,
        PetSpaceV3StateKind.empty => null,
        PetSpaceV3StateKind.searchEmpty => null,
        PetSpaceV3StateKind.blockedHidden => null,
        PetSpaceV3StateKind.network => Icons.wifi_off_rounded,
        PetSpaceV3StateKind.server => Icons.cloud_off_outlined,
        PetSpaceV3StateKind.permission => Icons.lock_outline_rounded,
        PetSpaceV3StateKind.session => Icons.logout_rounded,
      };

  Color get _accent => switch (kind) {
        PetSpaceV3StateKind.initial => PetSpaceV3Tokens.action,
        PetSpaceV3StateKind.empty => PetSpaceV3Tokens.action,
        PetSpaceV3StateKind.searchEmpty => PetSpaceV3Tokens.action,
        PetSpaceV3StateKind.blockedHidden => PetSpaceV3Tokens.textMuted,
        PetSpaceV3StateKind.network => PetSpaceV3Tokens.caution,
        PetSpaceV3StateKind.server => PetSpaceV3Tokens.destructive,
        PetSpaceV3StateKind.permission => PetSpaceV3Tokens.caution,
        PetSpaceV3StateKind.session => PetSpaceV3Tokens.action,
      };

  @override
  Widget build(BuildContext context) {
    final status = Semantics(
      container: true,
      liveRegion: _isUrgent,
      label: '$title. $message',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_icon != null) ...[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(
                  PetSpaceV3Tokens.radius,
                ),
              ),
              child: Icon(_icon, color: _accent, size: 24),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: PetSpaceV3Tokens.text,
              fontSize: 18,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: PetSpaceV3Tokens.textMuted,
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ],
      ),
    );

    return SingleChildScrollView(
      primary: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            status,
            if (primaryActionLabel != null && onPrimaryAction != null) ...[
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 220,
                  maxWidth: 320,
                ),
                child: PetSpaceV3PrimaryButton(
                  label: primaryActionLabel!,
                  onPressed: onPrimaryAction,
                ),
              ),
            ],
            if (secondaryActionLabel != null && onSecondaryAction != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onSecondaryAction,
                style: TextButton.styleFrom(
                  foregroundColor: PetSpaceV3Tokens.action,
                  disabledForegroundColor: PetSpaceV3Tokens.disabledText,
                  minimumSize: const Size(
                    PetSpaceV3Tokens.minimumTapTarget,
                    PetSpaceV3Tokens.minimumTapTarget,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                child: Text(
                  secondaryActionLabel!,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PetSpaceV3SectionHeader extends StatelessWidget {
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const PetSpaceV3SectionHeader({
    super.key,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: PetSpaceV3Tokens.text,
            fontSize: 18,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(
            description!,
            style: const TextStyle(
              color: PetSpaceV3Tokens.textMuted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
    final action = actionLabel != null && onAction != null
        ? TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: PetSpaceV3Tokens.action,
              disabledForegroundColor: PetSpaceV3Tokens.disabledText,
              minimumSize: const Size(
                PetSpaceV3Tokens.minimumTapTarget,
                PetSpaceV3Tokens.minimumTapTarget,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(actionLabel!, textAlign: TextAlign.center),
          )
        : null;
    final usesLargeText = MediaQuery.textScalerOf(context).scale(18) >= 27;

    if (usesLargeText && action != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: action),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: heading),
        if (action != null) ...[
          const SizedBox(width: 12),
          action,
        ],
      ],
    );
  }
}
