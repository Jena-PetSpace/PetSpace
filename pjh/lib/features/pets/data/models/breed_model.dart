import '../../domain/entities/breed.dart';

class BreedModel {
  final String id;
  final String species;
  final String nameKo;
  final String? nameEn;
  final String? description;
  final String? originCountry;
  final String? size;
  final List<String>? temperament;
  final int? lifespanMin;
  final int? lifespanMax;
  final bool isActive;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BreedModel({
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

  /// Supabase JSON → Model
  factory BreedModel.fromJson(Map<String, dynamic> json) {
    return BreedModel(
      id: json['id'] as String,
      species: json['species'] as String,
      nameKo: json['name_ko'] as String,
      nameEn: json['name_en'] as String?,
      description: json['description'] as String?,
      originCountry: json['origin_country'] as String?,
      size: json['size'] as String?,
      temperament: json['temperament'] != null
          ? List<String>.from(json['temperament'] as List)
          : null,
      lifespanMin: json['lifespan_min'] as int?,
      lifespanMax: json['lifespan_max'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      displayOrder: json['display_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Model → Supabase JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'species': species,
      'name_ko': nameKo,
      'name_en': nameEn,
      'description': description,
      'origin_country': originCountry,
      'size': size,
      'temperament': temperament,
      'lifespan_min': lifespanMin,
      'lifespan_max': lifespanMax,
      'is_active': isActive,
      'display_order': displayOrder,
      // created_at, updated_at은 DB에서 자동 관리
    };
  }

  /// Model → Entity
  Breed toEntity() {
    return Breed(
      id: id,
      species: species,
      nameKo: nameKo,
      nameEn: nameEn,
      description: description,
      originCountry: originCountry,
      size: _parseBreedSize(size),
      temperament: temperament,
      lifespanMin: lifespanMin,
      lifespanMax: lifespanMax,
      isActive: isActive,
      displayOrder: displayOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Entity → Model
  factory BreedModel.fromEntity(Breed breed) {
    return BreedModel(
      id: breed.id,
      species: breed.species,
      nameKo: breed.nameKo,
      nameEn: breed.nameEn,
      description: breed.description,
      originCountry: breed.originCountry,
      size: breed.size?.name,
      temperament: breed.temperament,
      lifespanMin: breed.lifespanMin,
      lifespanMax: breed.lifespanMax,
      isActive: breed.isActive,
      displayOrder: breed.displayOrder,
      createdAt: breed.createdAt,
      updatedAt: breed.updatedAt,
    );
  }

  /// String → BreedSize enum 변환
  static BreedSize? _parseBreedSize(String? size) {
    if (size == null) return null;

    switch (size) {
      case 'small':
        return BreedSize.small;
      case 'medium':
        return BreedSize.medium;
      case 'large':
        return BreedSize.large;
      case 'extra_large':
        return BreedSize.extraLarge;
      default:
        return null;
    }
  }
}
