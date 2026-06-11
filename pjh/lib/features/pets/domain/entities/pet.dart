import 'package:equatable/equatable.dart';

enum PetType { dog, cat }

enum PetGender { male, female }

class Pet extends Equatable {
  final String id;
  final String userId;
  final String name;
  final PetType type;
  final String? breed;
  final DateTime? birthDate;
  final PetGender? gender;
  final String? avatarUrl;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// MBTI 최신 결과 type_code 캐시(pets.current_mbti_type). 빠른 표시용.
  /// null 이면 "검사 안 함"으로 간주(홈/MY 에서 CTA 노출).
  final String? currentMbtiType;
  final DateTime? currentMbtiUpdatedAt;

  /// 펫 여권(F2_pet_passport) 필드. 모두 nullable → 미적용/미입력 안전.
  /// 여권번호: 등록 시 1회 생성('P'+영문2+숫자5), 수정 시 유지.
  final String? passportNo;

  /// 여권 영문 성(수동 입력).
  final String? passportSurname;

  /// 여권 영문 이름(수동 입력).
  final String? passportGivenName;

  /// 여권 표기용 한글성명(수동 입력, 기존 name 과 별개).
  final String? nameHanguel;

  /// 국가코드(ISO 3166-1 alpha-3). 기본 KOR.
  final String? countryCode;

  const Pet({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.breed,
    this.birthDate,
    this.gender,
    this.avatarUrl,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.currentMbtiType,
    this.currentMbtiUpdatedAt,
    this.passportNo,
    this.passportSurname,
    this.passportGivenName,
    this.nameHanguel,
    this.countryCode,
  });

  /// 국가코드(null/공백 시 기본 KOR).
  String get countryCodeOrDefault =>
      (countryCode == null || countryCode!.trim().isEmpty)
          ? 'KOR'
          : countryCode!.trim().toUpperCase();

  Pet copyWith({
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
    String? currentMbtiType,
    DateTime? currentMbtiUpdatedAt,
    String? passportNo,
    String? passportSurname,
    String? passportGivenName,
    String? nameHanguel,
    String? countryCode,
  }) {
    return Pet(
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
      currentMbtiType: currentMbtiType ?? this.currentMbtiType,
      currentMbtiUpdatedAt: currentMbtiUpdatedAt ?? this.currentMbtiUpdatedAt,
      passportNo: passportNo ?? this.passportNo,
      passportSurname: passportSurname ?? this.passportSurname,
      passportGivenName: passportGivenName ?? this.passportGivenName,
      nameHanguel: nameHanguel ?? this.nameHanguel,
      countryCode: countryCode ?? this.countryCode,
    );
  }

  int? get ageInMonths {
    if (birthDate == null) return null;
    final now = DateTime.now();
    return (now.year - birthDate!.year) * 12 + now.month - birthDate!.month;
  }

  String get displayAge {
    final months = ageInMonths;
    if (months == null) return '나이 미상';

    if (months < 12) {
      return '$months개월';
    } else {
      final years = months ~/ 12;
      final remainingMonths = months % 12;
      if (remainingMonths == 0) {
        return '$years살';
      } else {
        return '$years살 $remainingMonths개월';
      }
    }
  }

  String get typeDisplayName {
    switch (type) {
      case PetType.dog:
        return '강아지';
      case PetType.cat:
        return '고양이';
    }
  }

  String? get genderDisplayName {
    if (gender == null) return null;
    switch (gender!) {
      case PetGender.male:
        return '수컷';
      case PetGender.female:
        return '암컷';
    }
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        type,
        breed,
        birthDate,
        gender,
        avatarUrl,
        description,
        createdAt,
        updatedAt,
        currentMbtiType,
        currentMbtiUpdatedAt,
        passportNo,
        passportSurname,
        passportGivenName,
        nameHanguel,
        countryCode,
      ];
}
