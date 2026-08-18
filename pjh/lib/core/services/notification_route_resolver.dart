/// 알림의 수신 상태와 무관하게 같은 화면으로 이동하도록 라우트를 결정합니다.
///
/// FCM 시스템 알림과 포그라운드 로컬 알림이 이 함수를 함께 사용해야 합니다.
class NotificationRouteResolver {
  const NotificationRouteResolver._();

  static String resolve(
    Map<String, dynamic> data, {
    required String currentUserId,
  }) {
    final type = _text(data['type']);
    final postId = _text(data['post_id']);
    final senderId = _text(data['sender_id']);
    final roomId = _text(data['room_id']);

    switch (type) {
      case 'like':
      case 'comment':
      case 'mention':
        return postId == null
            ? '/notifications'
            : Uri(pathSegments: ['', 'post', postId]).toString();
      case 'follow':
        if (senderId == null) return '/notifications';
        return Uri(
          pathSegments: ['', 'user-profile', senderId],
          queryParameters: {'currentUserId': currentUserId},
        ).toString();
      case 'emotion_analysis':
        return '/ai-history-page';
      case 'health_alert':
        return '/health';
      case 'chat':
        return roomId == null
            ? '/chat'
            : Uri(pathSegments: ['', 'chat', roomId]).toString();
      case 'system':
      case 'admin_new_post':
      default:
        return '/notifications';
    }
  }

  static String? _text(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
