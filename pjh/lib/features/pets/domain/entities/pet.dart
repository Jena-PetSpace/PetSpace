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
  });

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
      ];
}