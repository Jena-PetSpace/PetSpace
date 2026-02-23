import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String username;
  final String displayName;
  final String? profileImageUrl;
  final String? bio;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final bool isVerified;
  final bool isPrivate;
  final List<String> interests;

  const User({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    this.profileImageUrl,
    this.bio,
    required this.createdAt,
    required this.lastActiveAt,
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
    this.isVerified = false,
    this.isPrivate = false,
    this.interests = const [],
  });

  User copyWith({
    String? id,
    String? email,
    String? username,
    String? displayName,
    String? profileImageUrl,
    String? bio,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    int? followersCount,
    int? followingCount,
    int? postsCount,
    bool? isVerified,
    bool? isPrivate,
    List<String>? interests,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      postsCount: postsCount ?? this.postsCount,
      isVerified: isVerified ?? this.isVerified,
      isPrivate: isPrivate ?? this.isPrivate,
      interests: interests ?? this.interests,
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        username,
        displayName,
        profileImageUrl,
        bio,
        createdAt,
        lastActiveAt,
        followersCount,
        followingCount,
        postsCount,
        isVerified,
        isPrivate,
        interests,
      ];
}