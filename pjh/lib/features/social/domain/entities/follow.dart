import 'package:equatable/equatable.dart';

enum FollowStatus { pending, accepted, blocked }

class Follow extends Equatable {
  final String id;
  final String followerId;
  final String followingId;
  final String followerName;
  final String followingName;
  final String? followerProfileImage;
  final String? followingProfileImage;
  final FollowStatus status;
  final DateTime createdAt;
  final DateTime? acceptedAt;

  const Follow({
    required this.id,
    required this.followerId,
    required this.followingId,
    required this.followerName,
    required this.followingName,
    this.followerProfileImage,
    this.followingProfileImage,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
  });

  Follow copyWith({
    String? id,
    String? followerId,
    String? followingId,
    String? followerName,
    String? followingName,
    String? followerProfileImage,
    String? followingProfileImage,
    FollowStatus? status,
    DateTime? createdAt,
    DateTime? acceptedAt,
  }) {
    return Follow(
      id: id ?? this.id,
      followerId: followerId ?? this.followerId,
      followingId: followingId ?? this.followingId,
      followerName: followerName ?? this.followerName,
      followingName: followingName ?? this.followingName,
      followerProfileImage: followerProfileImage ?? this.followerProfileImage,
      followingProfileImage: followingProfileImage ?? this.followingProfileImage,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        followerId,
        followingId,
        followerName,
        followingName,
        followerProfileImage,
        followingProfileImage,
        status,
        createdAt,
        acceptedAt,
      ];
}