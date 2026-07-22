import 'package:equatable/equatable.dart';

class BlockedUser extends Equatable {
  final String id;
  final String blockId;
  final String displayName;
  final String? username;
  final String? photoUrl;
  final DateTime blockedAt;

  const BlockedUser({
    required this.id,
    required this.blockId,
    required this.displayName,
    this.username,
    this.photoUrl,
    required this.blockedAt,
  });

  @override
  List<Object?> get props => [
        id,
        blockId,
        displayName,
        username,
        photoUrl,
        blockedAt,
      ];
}

class BlockedUsersCursor extends Equatable {
  final DateTime blockedAt;
  final String blockId;

  const BlockedUsersCursor({required this.blockedAt, required this.blockId});

  @override
  List<Object> get props => [blockedAt, blockId];
}

class BlockedUsersPage extends Equatable {
  final List<BlockedUser> users;
  final BlockedUsersCursor? nextCursor;

  const BlockedUsersPage({required this.users, required this.nextCursor});

  @override
  List<Object?> get props => [users, nextCursor];
}
