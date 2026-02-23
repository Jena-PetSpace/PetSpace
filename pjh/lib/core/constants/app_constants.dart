class AppConstants {
  // 앱 정보
  static const String appName = '펫페이스';
  static const String appVersion = '1.0.0';

  // API & 네트워크
  static const String baseUrl = 'https://api.meong-nyang-diary.com';
  static const int connectionTimeout = 30000;
  static const int receiveTimeout = 30000;

  // 이미지 관련
  static const double maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int imageQuality = 85;
  static const double cropAspectRatio = 1.0; // 정사각형

  // 감정 분석 관련
  static const List<String> emotionTypes = [
    'happiness',
    'sadness',
    'anxiety',
    'sleepiness',
    'curiosity',
  ];

  // 페이지네이션
  static const int defaultPageSize = 20;
  static const int maxPageSize = 50;

  // 캐시 관련
  static const Duration cacheExpiry = Duration(minutes: 30);
  static const Duration imageCacheExpiry = Duration(days: 7);
}

class ApiEndpoints {
  static const String auth = '/auth';
  static const String users = '/users';
  static const String pets = '/pets';
  static const String emotions = '/emotions';
  static const String posts = '/posts';
  static const String comments = '/comments';
  static const String follows = '/follows';
}

class DatabaseCollections {
  static const String users = 'users';
  static const String pets = 'pets';
  static const String posts = 'posts';
  static const String emotionHistory = 'emotion_history';
  static const String comments = 'comments';
  static const String likes = 'likes';
  static const String follows = 'follows';
}

class StoragePaths {
  static const String profileImages = 'images/users';
  static const String petImages = 'images/pets';
  static const String postImages = 'images/posts';
  static const String emotionImages = 'images/emotions';
}