import 'package:equatable/equatable.dart';

/// 품종 크기
enum BreedSize {
  small,
  medium,
  large,
  extraLarge;

  String get displayName {
    switch (this) {
      case BreedSize.small:
        return '소형';
      case BreedSize.medium:
        return '중형';
      case BreedSize.large:
        return '대형';
      case BreedSize.extraLarge:
        return '초대형';
    }
  }
}

/// 반려동물 품종 엔티티
class Breed extends Equatable {
  final String id;
  final String species; // 'dog' or 'cat'
  final String nameKo;
  final String? nameEn;
  final String? description;
  final String? originCountry;
  final BreedSize? size;
  final List<String>? temperament;
  final int? lifespanMin;
  final int? lifespanMax;
  final bool isActive;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Breed({
    required this.id,
    required this.species,
    required this.nameKo,
    this.nameEn,
    this.description,
    this.originCountry,
    this.size,
    this.temperament,
    this.lifespanMin,
    this.lifespanMax,
    this.isActive = true,
    this.displayOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 전체 이름 (한글 + 영문)
  String get fullName {
    if (nameEn != null && nameEn!.isNotEmpty) {
      return '$nameKo ($nameEn)';
    }
    return nameKo;
  }

  /// 수명 범위 문자열
  String? get lifespanDisplay {
    if (lifespanMin != null && lifespanMax != null) {
      return '$lifespanMin-$lifespanMax년';
    } else if (lifespanMin != null) {
      return '약 $lifespanMin년';
    } else if (lifespanMax != null) {
      return '최대 $lifespanMax년';
    }
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        species,
        nameKo,
        nameEn,
        description,
        originCountry,
        size,
        temperament,
        lifespanMin,
        lifespanMax,
        isActive,
        displayOrder,
        createdAt,
        updatedAt,
      ];

  Breed copyWith({
    String? id,
    String? species,
    String? nameKo,
    String? nameEn,
    String? description,
    String? originCountry,
    BreedSize? size,
    List<String>? temperament,
    int? lifespanMin,
    int? lifespanMax,
    bool? isActive,
    int? displayOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Breed(
      id: id ?? this.id,
      species: species ?? this.species,
      nameKo: nameKo ?? this.nameKo,
      nameEn: nameEn ?? this.nameEn,
      description: description ?? this.description,
      originCountry: originCountry ?? this.originCountry,
      size: size ?? this.size,
      temperament: temperament ?? this.temperament,
      lifespanMin: lifespanMin ?? this.lifespanMin,
      lifespanMax: lifespanMax ?? this.lifespanMax,
      isActive: isActive ?? this.isActive,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
