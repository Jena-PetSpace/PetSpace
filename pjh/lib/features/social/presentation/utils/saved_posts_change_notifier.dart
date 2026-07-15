import 'package:flutter/foundation.dart';

enum SavedPostsChangeType { saved, unsaved, moved }

@immutable
class SavedPostsChange {
  final SavedPostsChangeType type;
  final String postId;
  final bool wasSaved;
  final bool isSaved;
  final String? oldCollectionId;
  final String? newCollectionId;
  final int revision;

  const SavedPostsChange({
    required this.type,
    required this.postId,
    required this.wasSaved,
    required this.isSaved,
    this.oldCollectionId,
    this.newCollectionId,
    required this.revision,
  });
}

class SavedPostsChangeNotifier extends ChangeNotifier {
  static final SavedPostsChangeNotifier instance =
      SavedPostsChangeNotifier._production();

  SavedPostsChangeNotifier._production();
  SavedPostsChangeNotifier.forTest();

  int _revision = 0;
  SavedPostsChange? _lastChange;

  SavedPostsChange? get lastChange => _lastChange;
  int get revision => _revision;

  void publish({
    required SavedPostsChangeType type,
    required String postId,
    required bool wasSaved,
    required bool isSaved,
    String? oldCollectionId,
    String? newCollectionId,
  }) {
    _revision++;
    _lastChange = SavedPostsChange(
      type: type,
      postId: postId,
      wasSaved: wasSaved,
      isSaved: isSaved,
      oldCollectionId: oldCollectionId,
      newCollectionId: newCollectionId,
      revision: _revision,
    );
    notifyListeners();
  }

  @visibleForTesting
  void clear() {
    _revision = 0;
    _lastChange = null;
  }
}
