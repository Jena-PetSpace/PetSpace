import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'failures.dart';

/// 에러 핸들러 유틸리티
///
/// 다양한 예외를 Failure 타입으로 변환하고,
/// 재시도 로직과 사용자 친화적인 에러 메시지를 제공합니다.
class ErrorHandler {
  /// 예외를 Failure로 변환
  static Failure handleException(dynamic error, [String? context]) {
    // Supabase 에러
    if (error is AuthException) {
      return AuthFailure(message: _getAuthErrorMessage(error));
    }

    if (error is PostgrestException) {
      return _handlePostgrestException(error, context);
    }

    if (error is StorageException) {
      return ServerFailure(message: _getStorageErrorMessage(error));
    }

    // 네트워크 에러
    if (error is SocketException) {
      return const NetworkFailure(
        message: '인터넷 연결을 확인해주세요.\n네트워크 상태를 확인하고 다시 시도해주세요.',
      );
    }

    if (error is TimeoutException) {
      return const TimeoutFailure(
        message: '요청 시간이 초과되었습니다.\n잠시 후 다시 시도해주세요.',
      );
    }

    // HTTP 에러
    if (error is HttpException) {
      return ServerFailure(
        message: '서버 연결에 실패했습니다.\n(${error.message})',
      );
    }

    // 파일 시스템 에러
    if (error is FileSystemException) {
      return const CacheFailure(
        message: '파일 처리 중 오류가 발생했습니다.\n저장 공간을 확인해주세요.',
      );
    }

    // 형식 에러
    if (error is FormatException) {
      return const ValidationFailure(
        message: '데이터 형식이 올바르지 않습니다.\n다시 시도해주세요.',
      );
    }

    // 일반 에러
    final errorMessage = error.toString();

    if (errorMessage.contains('not found') || errorMessage.contains('404')) {
      return NotFoundFailure(
        message:
            context != null ? '$context을(를) 찾을 수 없습니다.' : '요청한 정보를 찾을 수 없습니다.',
      );
    }

    if (errorMessage.contains('unauthorized') || errorMessage.contains('401')) {
      return const UnauthorizedFailure(
        message: '인증이 필요합니다.\n다시 로그인해주세요.',
      );
    }

    if (errorMessage.contains('forbidden') || errorMessage.contains('403')) {
      return const UnauthorizedFailure(
        message: '접근 권한이 없습니다.',
      );
    }

    // 기본 에러
    return GeneralFailure(
      message: context != null
          ? '$context 중 오류가 발생했습니다.\n${_getSafeErrorMessage(error)}'
          : '오류가 발생했습니다.\n${_getSafeErrorMessage(error)}',
    );
  }

  /// 재시도 로직이 포함된 작업 실행
  ///
  /// [operation]: 실행할 비동기 작업
  /// [context]: 에러 컨텍스트 (예: '게시물 조회')
  /// [maxAttempts]: 최대 재시도 횟수 (기본값: 3)
  /// [retryDelay]: 초기 재시도 지연 시간 (기본값: 1초)
  /// [shouldRetry]: 재시도 여부를 판단하는 함수 (선택)
  static Future<Either<Failure, T>> executeWithRetry<T>({
    required Future<T> Function() operation,
    String? context,
    int maxAttempts = 3,
    Duration retryDelay = const Duration(seconds: 1),
    bool Function(dynamic error)? shouldRetry,
  }) async {
    int attempts = 0;
    Duration currentDelay = retryDelay;

    while (attempts < maxAttempts) {
      attempts++;

      try {
        final result = await operation();
        return Right(result);
      } catch (e) {
        // 마지막 시도이거나 재시도하지 않아야 하는 경우
        if (attempts >= maxAttempts ||
            (shouldRetry != null && !shouldRetry(e))) {
          return Left(handleException(e, context));
        }

        // 재시도하지 않아야 하는 에러 타입들
        if (_shouldNotRetry(e)) {
          return Left(handleException(e, context));
        }

        // 지수 백오프로 대기
        await Future.delayed(currentDelay);
        currentDelay *= 2; // 다음 재시도는 두 배로 대기
      }
    }

    // 이 코드는 도달하지 않지만 타입 안정성을 위해 필요
    return Left(
      GeneralFailure(
        message: context != null ? '$context에 실패했습니다.' : '작업에 실패했습니다.',
      ),
    );
  }

  /// 재시도 로직이 포함된 작업 실행 (타임아웃 포함)
  static Future<Either<Failure, T>> executeWithTimeout<T>({
    required Future<T> Function() operation,
    Duration timeout = const Duration(seconds: 30),
    String? context,
    int maxAttempts = 3,
  }) async {
    return executeWithRetry<T>(
      operation: () => operation().timeout(timeout),
      context: context,
      maxAttempts: maxAttempts,
    );
  }

  // Private 헬퍼 메서드들

  static Failure _handlePostgrestException(
    PostgrestException error,
    String? context,
  ) {
    final code = error.code;
    final message = error.message;

    // 고유 제약 조건 위반
    if (code == '23505') {
      return ValidationFailure(
        message:
            context != null ? '$context: 이미 존재하는 데이터입니다.' : '이미 존재하는 데이터입니다.',
      );
    }

    // 외래 키 제약 조건 위반
    if (code == '23503') {
      return const ValidationFailure(
        message: '연관된 데이터가 존재하지 않습니다.\n먼저 필요한 데이터를 생성해주세요.',
      );
    }

    // NULL 제약 조건 위반
    if (code == '23502') {
      return const ValidationFailure(
        message: '필수 정보가 누락되었습니다.\n모든 필수 항목을 입력해주세요.',
      );
    }

    // 권한 에러
    if (code == '42501') {
      return const UnauthorizedFailure(
        message: '이 작업을 수행할 권한이 없습니다.',
      );
    }

    // 기본 데이터베이스 에러
    return DatabaseFailure(
      message: context != null
          ? '$context 중 데이터베이스 오류가 발생했습니다.\n$message'
          : '데이터베이스 오류가 발생했습니다.\n$message',
    );
  }

  static String _getAuthErrorMessage(AuthException error) {
    final message = error.message.toLowerCase();

    if (message.contains('invalid login credentials') ||
        message.contains('invalid email or password')) {
      return '이메일 또는 비밀번호가 올바르지 않습니다.';
    }

    if (message.contains('email not confirmed')) {
      return '이메일 인증이 필요합니다.\n이메일을 확인해주세요.';
    }

    if (message.contains('user already registered') ||
        message.contains('email already exists')) {
      return '이미 가입된 이메일입니다.';
    }

    if (message.contains('weak password')) {
      return '비밀번호가 너무 약합니다.\n8자 이상의 강력한 비밀번호를 사용해주세요.';
    }

    if (message.contains('invalid email')) {
      return '올바른 이메일 주소를 입력해주세요.';
    }

    if (message.contains('refresh token')) {
      return '로그인 세션이 만료되었습니다.\n다시 로그인해주세요.';
    }

    if (message.contains('rate limit')) {
      return '너무 많은 요청을 시도했습니다.\n잠시 후 다시 시도해주세요.';
    }

    return '인증 중 오류가 발생했습니다.\n${error.message}';
  }

  static String _getStorageErrorMessage(StorageException error) {
    final message = error.message.toLowerCase();

    if (message.contains('not found')) {
      return '파일을 찾을 수 없습니다.';
    }

    if (message.contains('unauthorized') || message.contains('permission')) {
      return '파일에 접근할 권한이 없습니다.';
    }

    if (message.contains('size') || message.contains('too large')) {
      return '파일 크기가 너무 큽니다.\n10MB 이하의 파일을 업로드해주세요.';
    }

    if (message.contains('format') || message.contains('type')) {
      return '지원하지 않는 파일 형식입니다.';
    }

    return '파일 업로드 중 오류가 발생했습니다.\n${error.message}';
  }

  static String _getSafeErrorMessage(dynamic error) {
    try {
      final errorStr = error.toString();
      // 민감한 정보나 너무 긴 에러 메시지 필터링
      if (errorStr.length > 200) {
        return '${errorStr.substring(0, 200)}...';
      }
      return errorStr;
    } catch (e) {
      return '알 수 없는 오류가 발생했습니다.';
    }
  }

  static bool _shouldNotRetry(dynamic error) {
    // 재시도하지 않아야 하는 에러들
    if (error is AuthException) return true;
    if (error is ValidationFailure) return true;
    if (error is UnauthorizedFailure) return true;
    if (error is FormatException) return true;

    // PostgrestException 중 일부는 재시도 불필요
    if (error is PostgrestException) {
      final code = error.code;
      // 제약 조건 위반, 권한 에러 등은 재시도 불필요
      if (code == '23505' ||
          code == '23503' ||
          code == '23502' ||
          code == '42501') {
        return true;
      }
    }

    return false;
  }
}

/// Repository에서 쉽게 사용할 수 있는 헬퍼 함수들
extension RepositoryErrorHandling on Future<dynamic> {
  /// 표준 에러 핸들링으로 작업 실행
  Future<Either<Failure, T>> handleErrors<T>(String context) async {
    return ErrorHandler.executeWithRetry<T>(
      operation: () async => await this as T,
      context: context,
    );
  }

  /// 타임아웃이 포함된 에러 핸들링으로 작업 실행
  Future<Either<Failure, T>> handleErrorsWithTimeout<T>(
    String context, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    return ErrorHandler.executeWithTimeout<T>(
      operation: () async => await this as T,
      timeout: timeout,
      context: context,
    );
  }
}
