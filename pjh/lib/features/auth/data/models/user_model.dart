// Firebase 의존성 제거 - Supabase로 전환

import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.uid,
    required super.email,
    required super.displayName,
    super.photoURL,
    required super.createdAt,
    required super.updatedAt,
    required super.pets,
    required super.following,
    required super.followers,
    required super.settings,
    super.isOnboardingCompleted = false,
    super.emailConfirmedAt,
  });

  factory UserModel.fromEntity(User user) {
    return UserModel(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoURL: user.photoURL,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
      pets: user.pets,
      following: user.following,
      followers: user.followers,
      settings: UserSettingsModel.fromEntity(user.settings),
      isOnboardingCompleted: user.isOnboardingCompleted,
      emailConfirmedAt: user.emailConfirmedAt,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? data['id'] ?? '',
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? data['display_name'] ?? data['full_name'] ?? '',
      photoURL: data['photoURL'] ?? data['photo_url'] ?? data['avatar_url'],
      createdAt: data['createdAt'] != null ? DateTime.parse(data['createdAt']) : DateTime.now(),
      updatedAt: data['updatedAt'] != null ? DateTime.parse(data['updatedAt']) : DateTime.now(),
      pets: List<String>.from(data['pets'] ?? []),
      following: List<String>.from(data['following'] ?? []),
      followers: List<String>.from(data['followers'] ?? []),
      settings: UserSettingsModel.fromMap(data['settings'] ?? {}),
      isOnboardingCompleted: data['isOnboardingCompleted'] ?? data['is_onboarding_completed'] ?? false,
      emailConfirmedAt: data['emailConfirmedAt'] != null ? DateTime.parse(data['emailConfirmedAt']) : null,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? map['full_name'] ?? '',
      photoURL: map['photoURL'] ?? map['avatar_url'],
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : DateTime.now(),
      pets: List<String>.from(map['pets'] ?? []),
      following: List<String>.from(map['following'] ?? []),
      followers: List<String>.from(map['followers'] ?? []),
      settings: UserSettingsModel.fromMap(map['settings'] ?? {}),
      isOnboardingCompleted: map['isOnboardingCompleted'] ?? map['is_onboarding_completed'] ?? false,
      emailConfirmedAt: map['emailConfirmedAt'] != null ? DateTime.parse(map['emailConfirmedAt']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': uid, // 'uid' 대신 'id' 사용 (Supabase 스키마와 일치)
      'display_name': displayName, // display_name 컬럼 사용
      'photo_url': photoURL, // photo_url 컬럼 사용
      'email': email, // email 컬럼 추가
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_onboarding_completed': isOnboardingCompleted, // 온보딩 완료 상태
      'pets': pets, // 반려동물 ID 목록
      'following': following, // 팔로잉 목록
      'followers': followers, // 팔로워 목록
      'settings': (settings as UserSettingsModel).toMap(), // 사용자 설정
    };
  }

  @override
  UserModel copyWith({
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
    return UserModel(
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
}

class UserSettingsModel extends UserSettings {
  const UserSettingsModel({
    required super.notificationsEnabled,
    required super.privacyLevel,
    required super.showEmotionAnalysisToPublic,
  });

  factory UserSettingsModel.fromEntity(UserSettings settings) {
    return UserSettingsModel(
      notificationsEnabled: settings.notificationsEnabled,
      privacyLevel: settings.privacyLevel,
      showEmotionAnalysisToPublic: settings.showEmotionAnalysisToPublic,
    );
  }

  factory UserSettingsModel.fromMap(Map<String, dynamic> map) {
    return UserSettingsModel(
      notificationsEnabled: map['notificationsEnabled'] ?? true,
      privacyLevel: _parsePrivacyLevel(map['privacyLevel']),
      showEmotionAnalysisToPublic: map['showEmotionAnalysisToPublic'] ?? true,
    );
  }

  static PrivacyLevel _parsePrivacyLevel(String? value) {
    switch (value) {
      case 'followersOnly':
        return PrivacyLevel.followersOnly;
      case 'private':
        return PrivacyLevel.private;
      default:
        return PrivacyLevel.public;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationsEnabled': notificationsEnabled,
      'privacyLevel': privacyLevel.name,
      'showEmotionAnalysisToPublic': showEmotionAnalysisToPublic,
    };
  }

  @override
  UserSettingsModel copyWith({
    bool? notificationsEnabled,
    PrivacyLevel? privacyLevel,
    bool? showEmotionAnalysisToPublic,
  }) {
    return UserSettingsModel(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      showEmotionAnalysisToPublic:
          showEmotionAnalysisToPublic ?? this.showEmotionAnalysisToPublic,
    );
  }
}