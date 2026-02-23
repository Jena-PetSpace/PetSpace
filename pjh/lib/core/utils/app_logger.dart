import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  File? _logFile;

  Future<void> initialize() async {
    if (!kReleaseMode) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        _logFile = File('${directory.path}/app_logs.txt');
        await _logFile!.create(recursive: true);
      } catch (e) {
        debugPrint('Failed to initialize log file: $e');
      }
    }
  }

  void debug(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    _log(LogLevel.debug, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  void info(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    _log(LogLevel.info, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  void warning(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    _log(LogLevel.warning, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  void error(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  void fatal(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    _log(LogLevel.fatal, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  void _log(
    LogLevel level,
    String message, {
    String? tag,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final tagStr = tag != null ? '[$tag] ' : '';
    final logMessage = '$timestamp ${level.name.toUpperCase()} $tagStr$message';

    // Console output
    if (!kReleaseMode) {
      switch (level) {
        case LogLevel.debug:
          developer.log(logMessage, name: 'DEBUG');
          break;
        case LogLevel.info:
          developer.log(logMessage, name: 'INFO');
          break;
        case LogLevel.warning:
          developer.log(logMessage, name: 'WARNING');
          break;
        case LogLevel.error:
        case LogLevel.fatal:
          developer.log(
            logMessage,
            name: level == LogLevel.error ? 'ERROR' : 'FATAL',
            error: error,
            stackTrace: stackTrace,
          );
          break;
      }
    }

    // File output (debug mode only)
    if (!kReleaseMode && _logFile != null) {
      try {
        final fullMessage = StringBuffer(logMessage);
        if (error != null) {
          fullMessage.write('\nError: $error');
        }
        if (stackTrace != null) {
          fullMessage.write('\nStackTrace: $stackTrace');
        }
        fullMessage.write('\n');

        _logFile!.writeAsStringSync(
          fullMessage.toString(),
          mode: FileMode.append,
          flush: true,
        );
      } catch (e) {
        debugPrint('Failed to write to log file: $e');
      }
    }

    // Send to crash reporting service in production
    if (kReleaseMode && (level == LogLevel.error || level == LogLevel.fatal)) {
      _sendToCrashlytics(message, error, stackTrace);
    }
  }

  void _sendToCrashlytics(String message, dynamic error, StackTrace? stackTrace) {
    // Implement Supabase error logging here
    // Can use Supabase Edge Functions or integrate with third-party services like Sentry
    // supabase.functions.invoke('log-error', body: {'message': message, 'error': error.toString()});
  }

  Future<void> clearLogs() async {
    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!.delete();
      await _logFile!.create();
    }
  }

  Future<String?> getLogs() async {
    if (_logFile != null && await _logFile!.exists()) {
      try {
        return await _logFile!.readAsString();
      } catch (e) {
        debugPrint('Failed to read log file: $e');
      }
    }
    return null;
  }

  Future<int> getLogFileSize() async {
    if (_logFile != null && await _logFile!.exists()) {
      try {
        final stat = await _logFile!.stat();
        return stat.size;
      } catch (e) {
        debugPrint('Failed to get log file size: $e');
      }
    }
    return 0;
  }

  // Analytics logging
  void logUserAction(String action, {Map<String, dynamic>? parameters}) {
    info('User Action: $action', tag: 'ANALYTICS');
    if (parameters != null) {
      info('Parameters: $parameters', tag: 'ANALYTICS');
    }

    // Send to analytics service
    _sendToAnalytics(action, parameters);
  }

  void logScreenView(String screenName, {Map<String, dynamic>? parameters}) {
    info('Screen View: $screenName', tag: 'ANALYTICS');

    // Send to analytics service
    _sendToAnalytics('screen_view', {'screen_name': screenName, ...?parameters});
  }

  void logPerformance(String operation, Duration duration, {Map<String, dynamic>? parameters}) {
    info('Performance: $operation took ${duration.inMilliseconds}ms', tag: 'PERFORMANCE');

    // Send to analytics service
    _sendToAnalytics('performance', {
      'operation': operation,
      'duration_ms': duration.inMilliseconds,
      ...?parameters,
    });
  }

  void _sendToAnalytics(String event, Map<String, dynamic>? parameters) {
    // Implement Supabase analytics logging here
    // Can use Supabase database or Edge Functions for custom analytics
    // supabase.from('analytics_events').insert({'event': event, 'parameters': parameters});
  }

  // API logging
  void logApiRequest(String method, String url, {Map<String, dynamic>? headers, dynamic body}) {
    debug('API Request: $method $url', tag: 'API');
    if (headers != null) {
      debug('Headers: $headers', tag: 'API');
    }
    if (body != null) {
      debug('Body: $body', tag: 'API');
    }
  }

  void logApiResponse(String method, String url, int statusCode, {dynamic response, Duration? duration}) {
    final durationStr = duration != null ? ' (${duration.inMilliseconds}ms)' : '';
    info('API Response: $method $url - $statusCode$durationStr', tag: 'API');
    if (response != null && !kReleaseMode) {
      debug('Response: $response', tag: 'API');
    }
  }

  void logApiError(String method, String url, dynamic error, {StackTrace? stackTrace}) {
    this.error('API Error: $method $url', tag: 'API', error: error, stackTrace: stackTrace);
  }
}

enum LogLevel {
  debug,
  info,
  warning,
  error,
  fatal,
}

// Extension for easy logging from any class
extension LoggerExtension on Object {
  AppLogger get logger => AppLogger();

  void logDebug(String message) {
    logger.debug(message, tag: runtimeType.toString());
  }

  void logInfo(String message) {
    logger.info(message, tag: runtimeType.toString());
  }

  void logWarning(String message) {
    logger.warning(message, tag: runtimeType.toString());
  }

  void logError(String message, {dynamic error, StackTrace? stackTrace}) {
    logger.error(message, tag: runtimeType.toString(), error: error, stackTrace: stackTrace);
  }
}