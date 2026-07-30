import 'package:shared_preferences/shared_preferences.dart';

typedef FeedPostDraft = ({String content, List<String> hashtags});
typedef CommunityPostDraft = ({
  String title,
  String content,
  String category,
});

class PostDraftStorage {
  static const _legacyContent = 'post_draft_content';
  static const _legacyHashtags = 'post_draft_hashtags';

  static const _feedContent = 'post_draft_v2_feed_content';
  static const _feedHashtags = 'post_draft_v2_feed_hashtags';
  static const _communityTitle = 'post_draft_v2_community_title';
  static const _communityContent = 'post_draft_v2_community_content';
  static const _communityCategory = 'post_draft_v2_community_category';

  static Future<void> saveFeed({
    required String content,
    required List<String> hashtags,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_feedContent, content);
    await prefs.setStringList(_feedHashtags, hashtags);
  }

  static Future<FeedPostDraft?> loadFeed() async {
    final prefs = await SharedPreferences.getInstance();
    final hasV2 =
        prefs.containsKey(_feedContent) || prefs.containsKey(_feedHashtags);
    final content =
        prefs.getString(hasV2 ? _feedContent : _legacyContent) ?? '';
    final hashtags =
        prefs.getStringList(hasV2 ? _feedHashtags : _legacyHashtags) ?? [];
    if (content.isEmpty && hashtags.isEmpty) return null;
    return (content: content, hashtags: hashtags);
  }

  static Future<void> clearFeed() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_feedContent),
      prefs.remove(_feedHashtags),
      prefs.remove(_legacyContent),
      prefs.remove(_legacyHashtags),
    ]);
  }

  static Future<void> saveCommunity({
    required String title,
    required String content,
    required String category,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_communityTitle, title);
    await prefs.setString(_communityContent, content);
    await prefs.setString(_communityCategory, category);
  }

  static Future<CommunityPostDraft?> loadCommunity() async {
    final prefs = await SharedPreferences.getInstance();
    final title = prefs.getString(_communityTitle) ?? '';
    final content = prefs.getString(_communityContent) ?? '';
    final category = prefs.getString(_communityCategory) ?? '';
    if (title.isEmpty && content.isEmpty && category.isEmpty) return null;
    return (title: title, content: content, category: category);
  }

  static Future<void> clearCommunity() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_communityTitle),
      prefs.remove(_communityContent),
      prefs.remove(_communityCategory),
    ]);
  }
}
