import '../../domain/entities/follow.dart';

class FollowModel extends Follow {
  const FollowModel({
    required super.id,
    required super.followerId,
    required super.followingId,
    required super.followerName,
    required super.followingName,
    super.followerProfileImage,
    super.followingProfileImage,
    required super.status,
    required super.createdAt,
    super.acceptedAt,
  });

  factory FollowModel.fromJson(Map<String, dynamic> json) {
    return FollowModel(
      id: json['id'] ?? '',
      followerId: json['follower_id'] ?? '',
      followingId: json['following_id'] ?? '',
      followerName: json['follower_name'] ?? '',
      followingName: json['following_name'] ?? '',
      followerProfileImage: json['follower_profile_image'],
      followingProfileImage: json['following_profile_image'],
      status: _parseStatus(json['status']),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      acceptedAt: json['accepted_at'] != null ? DateTime.parse(json['accepted_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'follower_id': followerId,
      'following_id': followingId,
      'follower_name': followerName,
      'following_name': followingName,
      'follower_profile_image': followerProfileImage,
      'following_profile_image': followingProfileImage,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
    };
  }

  Follow toEntity() {
    return Follow(
      id: id,
      followerId: followerId,
      followingId: followingId,
      followerName: followerName,
      followingName: followingName,
      followerProfileImage: followerProfileImage,
      followingProfileImage: followingProfileImage,
      status: status,
      createdAt: createdAt,
      acceptedAt: acceptedAt,
    );
  }

  factory FollowModel.fromEntity(Follow follow) {
    return FollowModel(
      id: follow.id,
      followerId: follow.followerId,
      followingId: follow.followingId,
      followerName: follow.followerName,
      followingName: follow.followingName,
      followerProfileImage: follow.followerProfileImage,
      followingProfileImage: follow.followingProfileImage,
      status: follow.status,
      createdAt: follow.createdAt,
      acceptedAt: follow.acceptedAt,
    );
  }

  @override
  FollowModel copyWith({
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
    return FollowModel(
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

  static FollowStatus _parseStatus(String? statusString) {
    switch (statusString) {
      case 'pending':
        return FollowStatus.pending;
      case 'accepted':
        return FollowStatus.accepted;
      case 'blocked':
        return FollowStatus.blocked;
      default:
        return FollowStatus.pending;
    }
  }
}