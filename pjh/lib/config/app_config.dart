import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = '멍x냥 다이어리';
  static const String appVersion = '1.0.0';
  static const int buildNumber = 1;

  // Environment configurations
  static const bool isProduction = kReleaseMode;
  static const bool isDebug = kDebugMode;

  // API configurations
  static String get baseUrl {
    if (isProduction) {
      return 'https://api.meongnyangdiary.com';
    } else {
      return 'https://dev-api.meongnyangdiary.com';
    }
  }

  // Supabase configurations
  static String get supabaseProjectId {
    if (isProduction) {
      return 'meongnyangdiary-prod';
    } else {
      return 'meongnyangdiary-dev';
    }
  }

  // Analytics configurations
  static const bool enableAnalytics = true;
  static const bool enableCrashlytics = true;

  // Feature flags
  static const bool enableEmotionAnalysis = true;
  static const bool enableSocialFeatures = true;
  static const bool enableOfflineMode = true;
  static const bool enablePushNotifications = true;

  // Cache configurations
  static const int maxCacheSize = 100 * 1024 * 1024; // 100MB
  static const Duration cacheTimeout = Duration(hours: 1);
  static const Duration imageCacheTimeout = Duration(days: 7);

  // UI configurations
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration debounceDelay = Duration(milliseconds: 500);

  // Limits
  static const int maxImagesPerPost = 5;
  static const int maxCommentLength = 500;
  static const int maxPostLength = 2000;
  static const int maxUsernameLength = 30;

  // Pagination
  static const int defaultPageSize = 20;
  static const int postsPageSize = 15;
  static const int commentsPageSize = 10;
  static const int notificationsPageSize = 25;

  // Performance
  static const int imageQuality = 85;
  static const int maxImageWidth = 1920;
  static const int maxImageHeight = 1920;
  static const int thumbnailSize = 300;

  // Security
  static const Duration sessionTimeout = Duration(days: 30);
  static const int maxLoginAttempts = 5;
  static const Duration loginLockoutDuration = Duration(minutes: 15);

  // Support
  static const String supportEmail = 'support@meongnyangdiary.com';
  static const String privacyPolicyUrl = 'https://meongnyangdiary.com/privacy';
  static const String termsOfServiceUrl = 'https://meongnyangdiary.com/terms';

  // App Store URLs
  static const String appStoreUrl = 'https://apps.apple.com/app/meongnyangdiary';
  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=com.meongnyangdiary';

  // Social Media
  static const String instagramUrl = 'https://instagram.com/meongnyangdiary';
  static const String facebookUrl = 'https://facebook.com/meongnyangdiary';

  // Development settings
  static bool get showDebugInfo => isDebug;
  static bool get enableLogging => isDebug || isProduction;
  static bool get enableTestMode => isDebug;
}

enum Environment {
  development,
  staging,
  production,
}

class EnvironmentConfig {
  static Environment get current {
    if (kReleaseMode) {
      return Environment.production;
    } else if (kProfileMode) {
      return Environment.staging;
    } else {
      return Environment.development;
    }
  }

  static String get environmentName {
    switch (current) {
      case Environment.development:
        return 'Development';
      case Environment.staging:
        return 'Staging';
      case Environment.production:
        return 'Production';
    }
  }

  static Map<String, dynamic> get config {
    switch (current) {
      case Environment.development:
        return {
          'baseUrl': 'https://dev-api.meongnyangdiary.com',
          'supabaseProjectId': 'meongnyangdiary-dev',
          'enableAnalytics': false,
          'enableCrashlytics': false,
          'showDebugBanner': true,
          'logLevel': 'debug',
        };
      case Environment.staging:
        return {
          'baseUrl': 'https://staging-api.meongnyangdiary.com',
          'supabaseProjectId': 'meongnyangdiary-staging',
          'enableAnalytics': true,
          'enableCrashlytics': true,
          'showDebugBanner': false,
          'logLevel': 'info',
        };
      case Environment.production:
        return {
          'baseUrl': 'https://api.meongnyangdiary.com',
          'supabaseProjectId': 'meongnyangdiary-prod',
          'enableAnalytics': true,
          'enableCrashlytics': true,
          'showDebugBanner': false,
          'logLevel': 'error',
        };
    }
  }
}