import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  final String id;
  final String? displayName;
  final String? avatarUrl;
  final String? provider;
  final bool isOnboardingCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    this.displayName,
    this.avatarUrl,
    this.provider,
    this.isOnboardingCompleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  UserProfile copyWith({
    String? id,
    String? displayName,
    String? avatarUrl,
    String? provider,
    bool? isOnboardingCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      provider: provider ?? this.provider,
      isOnboardingCompleted: isOnboardingCompleted ?? this.isOnboardingCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        displayName,
        avatarUrl,
        provider,
        isOnboardingCompleted,
        createdAt,
        updatedAt,
      ];
}