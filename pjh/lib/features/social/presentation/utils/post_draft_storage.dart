import 'package:shared_preferences/shared_preferences.dart';

class PostDraftStorage {
  static const _keyContent = 'post_draft_content';
  static const _keyHashtags = 'post_draft_hashtags';

  static Future<void> save({
    required String content,
    required List<String> hashtags,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyContent, content);
    await prefs.setStringList(_keyHashtags, hashtags);
  }

  static Future<({String content, List<String> hashtags})?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final content = prefs.getString(_keyContent);
    if (content == null || content.isEmpty) return null;
    final hashtags = prefs.getStringList(_keyHashtags) ?? [];
    return (content: content, hashtags: hashtags);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyContent);
    await prefs.remove(_keyHashtags);
  }
}
