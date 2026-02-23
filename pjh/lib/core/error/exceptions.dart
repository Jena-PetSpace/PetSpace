class ServerException implements Exception {
  final String message;

  const ServerException(this.message);
}

class CacheException implements Exception {
  final String message;

  const CacheException(this.message);
}

class NetworkException implements Exception {
  final String message;

  const NetworkException(this.message);
}

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);
}

class ValidationException implements Exception {
  final String message;

  const ValidationException(this.message);
}

class AIServiceException implements Exception {
  final String message;

  const AIServiceException(this.message);
}

class ImageProcessingException implements Exception {
  final String message;

  const ImageProcessingException(this.message);
}

class ImageException implements Exception {
  final String message;

  const ImageException(this.message);
}

class AnalysisException implements Exception {
  final String message;

  const AnalysisException(this.message);
}