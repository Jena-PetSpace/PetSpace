// Firebase 의존성 제거 - Supabase로 전환

import '../../domain/entities/social_user.dart';

class SocialUserModel {
  final String id;
  final String displayName;
  final String email;
  final String? username;
  final String? profileImageUrl;
  final String? bio;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPrivate;

  const SocialUserModel({
    required this.id,
    required this.displayName,
    required this.email,
    this.username,
    this.profileImageUrl,
    this.bio,
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isPrivate = false,
  });

  factory SocialUserModel.fromJson(Map<String, dynamic> json) {
    return SocialUserModel(
      id: json['id'] ?? '',
      displayName: json['displayName'] ?? '',
      email: json['email'] ?? '',
      username: json['username'],
      profileImageUrl: json['profileImageUrl'],
      bio: json['bio'],
      followersCount: json['followersCount'] ?? 0,
      followingCount: json['followingCount'] ?? 0,
      postsCount: json['postsCount'] ?? 0,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      updatedAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      isPrivate: json['isPrivate'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'username': username,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'postsCount': postsCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isPrivate': isPrivate,
    };
  }

  SocialUser toEntity() {
    return SocialUser(
      id: id,
      displayName: displayName,
      email: email,
      username: username,
      profileImageUrl: profileImageUrl,
      bio: bio,
      followersCount: followersCount,
      followingCount: followingCount,
      postsCount: postsCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isPrivate: isPrivate,
    );
  }

  factory SocialUserModel.fromEntity(SocialUser user) {
    return SocialUserModel(
      id: user.id,
      displayName: user.displayName,
      email: user.email,
      username: user.username,
      profileImageUrl: user.profileImageUrl,
      bio: user.bio,
      followersCount: user.followersCount,
      followingCount: user.followingCount,
      postsCount: user.postsCount,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
      isPrivate: user.isPrivate,
    );
  }

  SocialUserModel copyWith({
    String? id,
    String? displayName,
    String? email,
    String? username,
    String? profileImageUrl,
    String? bio,
    int? followersCount,
    int? followingCount,
    int? postsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPrivate,
  }) {
    return SocialUserModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      username: username ?? this.username,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      postsCount: postsCount ?? this.postsCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPrivate: isPrivate ?? this.isPrivate,
    );
  }
}