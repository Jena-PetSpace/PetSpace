import 'package:equatable/equatable.dart';

enum PostLikeRelation { self, following, notFollowing }

class PostLikesCursor extends Equatable {
  final DateTime createdAt;
  final String likeId;

  const PostLikesCursor({required this.createdAt, required this.likeId});

  @override
  List<Object?> get props => [createdAt, likeId];
}

class PostLikeUser extends Equatable {
  final String likeId;
  final String userId;
  final String displayName;
  final String? username;
  final String? photoUrl;
  final PostLikeRelation relation;

  const PostLikeUser({
    required this.likeId,
    required this.userId,
    required this.displayName,
    this.username,
    this.photoUrl,
    required this.relation,
  });

  PostLikeUser copyWith({
    String? likeId,
    String? userId,
    String? displayName,
    String? username,
    String? photoUrl,
    PostLikeRelation? relation,
  }) {
    return PostLikeUser(
      likeId: likeId ?? this.likeId,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      relation: relation ?? this.relation,
    );
  }

  @override
  List<Object?> get props => [
        likeId,
        userId,
        displayName,
        username,
        photoUrl,
        relation,
      ];
}

class PostLikesPage extends Equatable {
  final List<PostLikeUser> items;
  final bool hasMore;
  final PostLikesCursor? nextCursor;

  const PostLikesPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  @override
  List<Object?> get props => [items, hasMore, nextCursor];
}
