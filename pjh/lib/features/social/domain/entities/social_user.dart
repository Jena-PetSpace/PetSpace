import 'package:equatable/equatable.dart';

class SocialUser extends Equatable {
  final String id;
  final String email;
  final String displayName;
  final String? username;
  final String? profileImageUrl;
  final String? bio;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPrivate;
  final int postsCount;
  final int followersCount;
  final int followingCount;

  const SocialUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.username,
    this.profileImageUrl,
    this.bio,
    required this.createdAt,
    required this.updatedAt,
    this.isPrivate = false,
    this.postsCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
  });

  SocialUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? username,
    String? profileImageUrl,
    String? bio,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPrivate,
    int? postsCount,
    int? followersCount,
    int? followingCount,
  }) {
    return SocialUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPrivate: isPrivate ?? this.isPrivate,
      postsCount: postsCount ?? this.postsCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        displayName,
        username,
        profileImageUrl,
        bio,
        createdAt,
        updatedAt,
        isPrivate,
        postsCount,
        followersCount,
        followingCount,
      ];
}