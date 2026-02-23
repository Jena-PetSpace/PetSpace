import 'failures.dart';

/// 앱 전역에서 사용되는 에러 메시지 상수
///
/// 일관된 에러 메시지를 제공하고 다국어 지원을 쉽게 하기 위한 클래스
class ErrorMessages {
  ErrorMessages._(); // private constructor to prevent instantiation

  // 네트워크 에러
  static const String networkError = '인터넷 연결을 확인해주세요.\n네트워크 상태를 확인하고 다시 시도해주세요.';
  static const String timeoutError = '요청 시간이 초과되었습니다.\n잠시 후 다시 시도해주세요.';
  static const String serverError = '서버와 연결할 수 없습니다.\n잠시 후 다시 시도해주세요.';

  // 인증 에러
  static const String authRequired = '로그인이 필요한 서비스입니다.\n로그인 후 이용해주세요.';
  static const String sessionExpired = '로그인 세션이 만료되었습니다.\n다시 로그인해주세요.';
  static const String invalidCredentials = '이메일 또는 비밀번호가 올바르지 않습니다.\n다시 확인해주세요.';
  static const String emailNotVerified = '이메일 인증이 필요합니다.\n이메일을 확인해주세요.';
  static const String emailAlreadyExists = '이미 가입된 이메일입니다.\n다른 이메일을 사용하거나 로그인해주세요.';
  static const String weakPassword = '비밀번호가 너무 약합니다.\n8자 이상의 강력한 비밀번호를 사용해주세요.';
  static const String invalidEmail = '올바른 이메일 주소를 입력해주세요.';

  // 권한 에러
  static const String unauthorized = '접근 권한이 없습니다.';
  static const String forbidden = '이 작업을 수행할 권한이 없습니다.';

  // 데이터 에러
  static const String notFound = '요청한 정보를 찾을 수 없습니다.';
  static const String alreadyExists = '이미 존재하는 데이터입니다.';
  static const String invalidData = '데이터 형식이 올바르지 않습니다.\n다시 시도해주세요.';
  static const String missingRequiredData = '필수 정보가 누락되었습니다.\n모든 필수 항목을 입력해주세요.';

  // 파일/이미지 에러
  static const String fileNotFound = '파일을 찾을 수 없습니다.';
  static const String fileTooLarge = '파일 크기가 너무 큽니다.\n10MB 이하의 파일을 업로드해주세요.';
  static const String unsupportedFileType = '지원하지 않는 파일 형식입니다.\nJPG, PNG 파일만 업로드 가능합니다.';
  static const String fileUploadFailed = '파일 업로드에 실패했습니다.\n다시 시도해주세요.';
  static const String imageProcessingFailed = '이미지 처리 중 오류가 발생했습니다.\n다른 이미지를 선택해주세요.';

  // 스토리지 에러
  static const String storageError = '저장 공간 오류가 발생했습니다.\n저장 공간을 확인해주세요.';
  static const String cacheFailed = '데이터 캐싱에 실패했습니다.';

  // AI 분석 에러
  static const String analysisError = '감정 분석 중 오류가 발생했습니다.\n다시 시도해주세요.';
  static const String aiServiceUnavailable = 'AI 서비스를 사용할 수 없습니다.\n잠시 후 다시 시도해주세요.';
  static const String invalidImage = '이미지를 분석할 수 없습니다.\n다른 이미지를 선택해주세요.';

  // 소셜 기능 에러
  static const String postCreateFailed = '게시물 작성에 실패했습니다.\n다시 시도해주세요.';
  static const String postNotFound = '게시물을 찾을 수 없습니다.';
  static const String commentFailed = '댓글 작성에 실패했습니다.\n다시 시도해주세요.';
  static const String likeFailed = '좋아요 처리에 실패했습니다.\n다시 시도해주세요.';
  static const String followFailed = '팔로우 처리에 실패했습니다.\n다시 시도해주세요.';

  // 반려동물 에러
  static const String petNotFound = '반려동물 정보를 찾을 수 없습니다.';
  static const String petCreateFailed = '반려동물 등록에 실패했습니다.\n다시 시도해주세요.';
  static const String petUpdateFailed = '반려동물 정보 수정에 실패했습니다.\n다시 시도해주세요.';
  static const String petDeleteFailed = '반려동물 삭제에 실패했습니다.\n다시 시도해주세요.';

  // 프로필 에러
  static const String profileNotFound = '사용자 프로필을 찾을 수 없습니다.';
  static const String profileUpdateFailed = '프로필 업데이트에 실패했습니다.\n다시 시도해주세요.';

  // 데이터베이스 에러
  static const String databaseError = '데이터베이스 오류가 발생했습니다.\n잠시 후 다시 시도해주세요.';
  static const String uniqueConstraintViolation = '이미 존재하는 데이터입니다.';
  static const String foreignKeyViolation = '연관된 데이터가 존재하지 않습니다.\n먼저 필요한 데이터를 생성해주세요.';

  // 일반 에러
  static const String unknownError = '알 수 없는 오류가 발생했습니다.\n잠시 후 다시 시도해주세요.';
  static const String operationFailed = '작업에 실패했습니다.\n다시 시도해주세요.';
  static const String rateLimitExceeded = '너무 많은 요청을 시도했습니다.\n잠시 후 다시 시도해주세요.';

  // 액션 메시지 (에러 해결 제안)
  static const String retryAction = '다시 시도하기';
  static const String loginAction = '로그인하기';
  static const String goBackAction = '돌아가기';
  static const String contactSupportAction = '문의하기';
}

/// 컨텍스트별 에러 메시지 생성 헬퍼
class ErrorMessageBuilder {
  ErrorMessageBuilder._();

  /// 작업 실패 메시지 생성
  static String operationFailed(String operation) {
    return '$operation에 실패했습니다.\n다시 시도해주세요.';
  }

  /// 아이템을 찾을 수 없음 메시지 생성
  static String notFound(String item) {
    return '$item을(를) 찾을 수 없습니다.';
  }

  /// 아이템이 이미 존재함 메시지 생성
  static String alreadyExists(String item) {
    return '$item이(가) 이미 존재합니다.';
  }

  /// 필수 필드 누락 메시지 생성
  static String missingField(String field) {
    return '$field을(를) 입력해주세요.';
  }

  /// 잘못된 형식 메시지 생성
  static String invalidFormat(String field) {
    return '올바른 $field 형식을 입력해주세요.';
  }

  /// 권한 부족 메시지 생성
  static String insufficientPermission(String action) {
    return '$action 권한이 없습니다.';
  }

  /// 제한 초과 메시지 생성
  static String limitExceeded(String resource, int limit) {
    return '$resource은(는) 최대 $limit개까지만 가능합니다.';
  }

  /// 상세 에러 메시지 생성 (context + 상세 메시지)
  static String detailedError(String context, String details) {
    return '$context 중 오류가 발생했습니다.\n$details';
  }

  /// 네트워크 에러 (컨텍스트 포함)
  static String networkError(String operation) {
    return '$operation을(를) 위해 인터넷 연결이 필요합니다.\n네트워크 상태를 확인해주세요.';
  }
}

/// 에러 심각도 수준
enum ErrorSeverity {
  /// 정보성 메시지 (파란색)
  info,

  /// 경고 (노란색)
  warning,

  /// 에러 (빨간색)
  error,

  /// 치명적 에러 (진한 빨간색)
  critical,
}

/// 에러 카테고리 (로깅 및 분석용)
enum ErrorCategory {
  network,
  auth,
  database,
  storage,
  validation,
  permission,
  ai,
  unknown,
}

/// 에러 정보를 담는 클래스
class ErrorInfo {
  final String message;
  final ErrorSeverity severity;
  final ErrorCategory category;
  final String? technicalDetails;
  final String? suggestedAction;
  final bool canRetry;

  const ErrorInfo({
    required this.message,
    required this.severity,
    required this.category,
    this.technicalDetails,
    this.suggestedAction,
    this.canRetry = true,
  });

  /// Failure로부터 ErrorInfo 생성
  factory ErrorInfo.fromFailure(Failure failure) {
    if (failure is NetworkFailure) {
      return ErrorInfo(
        message: failure.message,
        severity: ErrorSeverity.warning,
        category: ErrorCategory.network,
        suggestedAction: ErrorMessages.retryAction,
        canRetry: true,
      );
    }

    if (failure is AuthFailure) {
      return ErrorInfo(
        message: failure.message,
        severity: ErrorSeverity.error,
        category: ErrorCategory.auth,
        suggestedAction: ErrorMessages.loginAction,
        canRetry: false,
      );
    }

    if (failure is UnauthorizedFailure) {
      return ErrorInfo(
        message: failure.message,
        severity: ErrorSeverity.error,
        category: ErrorCategory.permission,
        suggestedAction: ErrorMessages.loginAction,
        canRetry: false,
      );
    }

    if (failure is ValidationFailure) {
      return ErrorInfo(
        message: failure.message,
        severity: ErrorSeverity.warning,
        category: ErrorCategory.validation,
        suggestedAction: ErrorMessages.goBackAction,
        canRetry: false,
      );
    }

    if (failure is DatabaseFailure || failure is ServerFailure) {
      return ErrorInfo(
        message: failure.message,
        severity: ErrorSeverity.error,
        category: ErrorCategory.database,
        suggestedAction: ErrorMessages.retryAction,
        canRetry: true,
      );
    }

    if (failure is TimeoutFailure) {
      return ErrorInfo(
        message: failure.message,
        severity: ErrorSeverity.warning,
        category: ErrorCategory.network,
        suggestedAction: ErrorMessages.retryAction,
        canRetry: true,
      );
    }

    if (failure is AnalysisFailure) {
      return ErrorInfo(
        message: failure.message,
        severity: ErrorSeverity.error,
        category: ErrorCategory.ai,
        suggestedAction: ErrorMessages.retryAction,
        canRetry: true,
      );
    }

    // GeneralFailure 또는 기타
    return ErrorInfo(
      message: failure.message,
      severity: ErrorSeverity.error,
      category: ErrorCategory.unknown,
      suggestedAction: ErrorMessages.retryAction,
      canRetry: true,
    );
  }
}
