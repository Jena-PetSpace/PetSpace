import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String uid;
  String get id => uid; // id getter for compatibility
  final String email;
  final String displayName;
  final String? photoURL;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> pets; // 반려동물 ID 목록
  final List<String> following; // 팔로잉 사용자 ID 목록
  final List<String> followers; // 팔로워 사용자 ID 목록
  final UserSettings settings;
  final bool isOnboardingCompleted; // 온보딩 완료 여부
  final DateTime? emailConfirmedAt; // 이메일 인증 완료 시각 (null이면 미인증)

  const User({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoURL,
    required this.createdAt,
    required this.updatedAt,
    required this.pets,
    required this.following,
    required this.followers,
    required this.settings,
    this.isOnboardingCompleted = false,
    this.emailConfirmedAt,
  });

  // 이메일 인증 여부 확인
  bool get isEmailConfirmed => emailConfirmedAt != null;

  User copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? pets,
    List<String>? following,
    List<String>? followers,
    UserSettings? settings,
    bool? isOnboardingCompleted,
    DateTime? emailConfirmedAt,
  }) {
    return User(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pets: pets ?? this.pets,
      following: following ?? this.following,
      followers: followers ?? this.followers,
      settings: settings ?? this.settings,
      isOnboardingCompleted: isOnboardingCompleted ?? this.isOnboardingCompleted,
      emailConfirmedAt: emailConfirmedAt ?? this.emailConfirmedAt,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        email,
        displayName,
        photoURL,
        createdAt,
        updatedAt,
        pets,
        following,
        followers,
        settings,
        isOnboardingCompleted,
        emailConfirmedAt,
      ];
}

class UserSettings extends Equatable {
  final bool notificationsEnabled;
  final PrivacyLevel privacyLevel;
  final bool showEmotionAnalysisToPublic;

  const UserSettings({
    required this.notificationsEnabled,
    required this.privacyLevel,
    required this.showEmotionAnalysisToPublic,
  });

  UserSettings copyWith({
    bool? notificationsEnabled,
    PrivacyLevel? privacyLevel,
    bool? showEmotionAnalysisToPublic,
  }) {
    return UserSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      showEmotionAnalysisToPublic:
          showEmotionAnalysisToPublic ?? this.showEmotionAnalysisToPublic,
    );
  }

  @override
  List<Object?> get props => [
        notificationsEnabled,
        privacyLevel,
        showEmotionAnalysisToPublic,
      ];
}

enum PrivacyLevel {
  public,
  followersOnly,
  private,
}