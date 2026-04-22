import 'package:equatable/equatable.dart';

class BookmarkCollection extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String emoji;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int postCount;

  const BookmarkCollection({
    required this.id,
    required this.userId,
    required this.name,
    this.emoji = '📁',
    required this.createdAt,
    required this.updatedAt,
    this.postCount = 0,
  });

  BookmarkCollection copyWith({
    String? id,
    String? userId,
    String? name,
    String? emoji,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? postCount,
  }) {
    return BookmarkCollection(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      postCount: postCount ?? this.postCount,
    );
  }

  @override
  List<Object?> get props => [id, userId, name, emoji, createdAt, updatedAt, postCount];
}
