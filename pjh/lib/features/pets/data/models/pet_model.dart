import '../../domain/entities/pet.dart';

class PetModel extends Pet {
  const PetModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.type,
    super.breed,
    super.birthDate,
    super.gender,
    super.avatarUrl,
    super.description,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Entity를 Model로 변환
  factory PetModel.fromEntity(Pet pet) {
    return PetModel(
      id: pet.id,
      userId: pet.userId,
      name: pet.name,
      type: pet.type,
      breed: pet.breed,
      birthDate: pet.birthDate,
      gender: pet.gender,
      avatarUrl: pet.avatarUrl,
      description: pet.description,
      createdAt: pet.createdAt,
      updatedAt: pet.updatedAt,
    );
  }

  /// Supabase JSON에서 Model로 변환
  factory PetModel.fromJson(Map<String, dynamic> json) {
    return PetModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      type: _parsePetType(json['type'] as String?),
      breed: json['breed'] as String?,
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'] as String)
          : null,
      gender: _parsePetGender(json['gender'] as String?),
      avatarUrl: json['avatar_url'] as String?,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.parse(json['created_at'] as String),
    );
  }

  /// Model을 Supabase JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'type': _petTypeToString(type),
      'breed': breed,
      'birth_date': birthDate?.toIso8601String(),
      'gender': gender != null ? _petGenderToString(gender!) : null,
      'avatar_url': avatarUrl,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// INSERT용 JSON (id 제외, created_at/updated_at 자동 생성)
  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'name': name,
      'type': _petTypeToString(type),
      'breed': breed,
      'birth_date': birthDate?.toIso8601String(),
      'gender': gender != null ? _petGenderToString(gender!) : null,
      'avatar_url': avatarUrl,
      'description': description,
    };
  }

  /// UPDATE용 JSON (수정 가능한 필드만)
  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'type': _petTypeToString(type),
      'breed': breed,
      'birth_date': birthDate?.toIso8601String(),
      'gender': gender != null ? _petGenderToString(gender!) : null,
      'avatar_url': avatarUrl,
      'description': description,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// PetType을 문자열로 변환 (TRD 문서: species VARCHAR(10) CHECK (species IN ('dog', 'cat')))
  static String _petTypeToString(PetType type) {
    switch (type) {
      case PetType.dog:
        return 'dog';
      case PetType.cat:
        return 'cat';
    }
  }

  /// 문자열을 PetType으로 변환
  static PetType _parsePetType(String? species) {
    switch (species?.toLowerCase()) {
      case 'dog':
        return PetType.dog;
      case 'cat':
        return PetType.cat;
      default:
        return PetType.dog; // 기본값
    }
  }

  /// PetGender를 문자열로 변환
  static String _petGenderToString(PetGender gender) {
    switch (gender) {
      case PetGender.male:
        return 'male';
      case PetGender.female:
        return 'female';
    }
  }

  /// 문자열을 PetGender로 변환
  static PetGender? _parsePetGender(String? gender) {
    switch (gender?.toLowerCase()) {
      case 'male':
        return PetGender.male;
      case 'female':
        return PetGender.female;
      default:
        return null;
    }
  }

  @override
  PetModel copyWith({
    String? id,
    String? userId,
    String? name,
    PetType? type,
    String? breed,
    DateTime? birthDate,
    PetGender? gender,
    String? avatarUrl,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PetModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      breed: breed ?? this.breed,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
