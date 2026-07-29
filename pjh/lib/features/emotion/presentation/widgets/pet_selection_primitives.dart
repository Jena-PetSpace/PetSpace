import 'package:flutter/material.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../pets/domain/entities/pet.dart';

String petSelectionMeta(Pet pet) {
  return '${pet.typeDisplayName} · ${pet.breed ?? '품종 미상'} · ${pet.displayAge}';
}

/// AI 분석과 분석 기록에서 함께 쓰는 반려동물 아바타 규칙.
///
/// 실제 사진을 우선하고, 사진이 없거나 로드에 실패하면 브랜드 아이콘으로
/// 대체한다. 인앱 UI에서는 플랫폼별 렌더링이 달라지는 이모지를 사용하지 않는다.
class PetSelectionAvatar extends StatelessWidget {
  final Pet? pet;
  final double size;
  final IconData fallbackIcon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const PetSelectionAvatar({
    super.key,
    required this.pet,
    required this.size,
    this.fallbackIcon = Icons.pets,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = pet?.avatarUrl?.trim();
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return Semantics(
        image: true,
        label: '${pet!.name} 프로필 사진',
        child: ClipOval(
          child: Image.network(
            avatarUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback(),
          ),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            AppTheme.primaryColor.withValues(alpha: pet == null ? 0.06 : 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        fallbackIcon,
        color: foregroundColor ?? AppTheme.primaryColor,
        size: size * 0.48,
      ),
    );
  }
}
