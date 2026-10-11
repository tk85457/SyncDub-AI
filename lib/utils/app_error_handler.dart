import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AppErrorType {
  auth,
  network,
  microphone,
  audioRouting,
  quota,
  database,
  translationServer,
  permission,
  video,
  rateLimit,
  timeout,
  general,
}

class AppError {
  final String title;
  final String reason;
  final String recoveryAction;
  final AppErrorType type;
  final DateTime timestamp;

  AppError({
    required this.title,
    required this.reason,
    required this.recoveryAction,
    this.type = AppErrorType.general,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Enterprise-grade sanitization: ensures zero internal URLs, JWTs, table names, IPs, or stack traces leak to the user
  factory AppError.fromException(dynamic error, {String? context}) {
    if (error == null) {
      return AppError(
        title: 'Notice',
        reason: 'Operation could not be completed at this time.',
        recoveryAction: 'Please try again',
        type: AppErrorType.general,
      );
    }

    final rawStr = error.toString().toLowerCase();

    // 1. Google Auth & Supabase Auth Exceptions
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid claim') ||
          msg.contains('token has expired') ||
          msg.contains('refresh_token_not_found') ||
          msg.contains('jwt')) {
        return AppError(
          title: 'Session Expired',
          reason:
              'Your security credentials have expired. Please sign in again with Google.',
          recoveryAction: 'Sign in with Google',
          type: AppErrorType.auth,
        );
      }
      if (msg.contains('network') ||
          msg.contains('failed to fetch') ||
          msg.contains('connection')) {
        return AppError(
          title: 'Authentication Server Unreachable',
          reason:
              'Could not connect to the account server. Please check your internet connection.',
          recoveryAction: 'Verify internet & retry',
          type: AppErrorType.network,
        );
      }
      if (msg.contains('user not found') ||
          msg.contains('invalid login credentials')) {
        return AppError(
          title: 'Account Verification Failed',
          reason: 'Google account credentials could not be verified.',
          recoveryAction: 'Try with another Google account',
          type: AppErrorType.auth,
        );
      }
      return AppError(
        title: 'Sign-In Failed',
        reason:
            'Unable to complete sign-in. Please tap Continue with Google again.',
        recoveryAction: 'Retry sign-in',
        type: AppErrorType.auth,
      );
    }

    // 2. PostgrestException (Supabase Database / RLS / Quota Queries)
    if (error is PostgrestException) {
      if (error.code == '42501' ||
          rawStr.contains('policy') ||
          rawStr.contains('permission denied')) {
        return AppError(
          title: 'Access Restricted',
          reason:
              'Your account does not have permission to modify this resource.',
          recoveryAction: 'Contact support if this is unexpected',
          type: AppErrorType.database,
        );
      }
      return AppError(
        title: 'Account Sync Interrupted',
        reason:
            'Could not synchronize your translation balance. Cached balance is active.',
        recoveryAction: 'Syncing automatically in background',
        type: AppErrorType.database,
      );
    }

    // 3. PlatformException (Google Sign-In cancellations, Bluetooth, Mic, Audio)
    if (error is PlatformException) {
      final code = error.code.toLowerCase();
      final msg = (error.message ?? '').toLowerCase();

      if (code == 'sign_in_canceled' ||
          msg.contains('canceled') ||
          msg.contains('cancelled')) {
        return AppError(
          title: 'Sign-In Cancelled',
          reason:
              'Google account selection was closed without selecting an account.',
          recoveryAction: 'Select your Google account to proceed',
          type: AppErrorType.auth,
        );
      }
      if (code.contains('network') || msg.contains('network_error')) {
        return AppError(
          title: 'Network Communication Error',
          reason:
              'Google Play Services could not reach authentication servers. Please verify your internet connection.',
          recoveryAction: 'Check connection & retry',
          type: AppErrorType.network,
        );
      }
      if (code.contains('api_not_connected') ||
          msg.contains('google play services')) {
        return AppError(
          title: 'Google Play Services Updating',
          reason:
              'Google Play Services is temporarily updating on this device.',
          recoveryAction: 'Please retry in a moment',
          type: AppErrorType.auth,
        );
      }
      if (code.contains('audio') ||
          code.contains('permission') ||
          msg.contains('permission')) {
        return AppError(
          title: 'Device Permission Needed',
          reason:
              'Hardware audio routing or microphone access requires authorization.',
          recoveryAction: 'Grant permission in system settings',
          type: AppErrorType.permission,
        );
      }
    }

    // 4. Missing Plugin Exception (e.g. In test or desktop environment)
    if (error is MissingPluginException) {
      return AppError(
        title: 'Hardware Feature Simulating',
        reason:
            'The requested hardware service is using software emulation on this device.',
        recoveryAction: 'Continue normally',
        type: AppErrorType.general,
      );
    }

    // 5. Quota / Credits / Billing
    if (rawStr.contains('quota') ||
        rawStr.contains('insufficient credits') ||
        rawStr.contains('insufficient balance') ||
        rawStr.contains('insufficient quota') ||
        rawStr.contains('insufficient minutes') ||
        RegExp(r'\b4002\b').hasMatch(rawStr) ||
        rawStr.contains('credits remaining') ||
        rawStr.contains('upgrade your plan')) {
      return AppError(
        title: 'Translation Quota Exhausted',
        reason:
            'Your account translation minutes have been used. Upgrade your plan to continue live speech dubbing.',
        recoveryAction: 'Upgrade Plan',
        type: AppErrorType.quota,
      );
    }

    // 6. Network, Socket, TCP, DNS & WebSocket Stream Exceptions
    if (error is SocketException ||
        error is HttpException ||
        rawStr.contains('failed host lookup') ||
        rawStr.contains('connection refused') ||
        rawStr.contains('network is unreachable') ||
        rawStr.contains('no route to host') ||
        rawStr.contains('wsasend') ||
        rawStr.contains('forcibly closed') ||
        rawStr.contains('remote host') ||
        rawStr.contains('connection reset') ||
        rawStr.contains('broken pipe') ||
        rawStr.contains('stream closed') ||
        rawStr.contains('status code 1006') ||
        rawStr.contains('status code 1001') ||
        rawStr.contains('status code 1005') ||
        rawStr.contains('websocket') ||
        rawStr.contains('connection closed') ||
        rawStr.contains('connection error') ||
        rawStr.contains('clientexception') ||
        rawStr.contains('socketexception') ||
        rawStr.contains('software caused connection abort')) {
      return AppError(
        title: 'Connection Interrupted',
        reason:
            'The live translation connection was interrupted. Please check your internet connection and tap Reconnect.',
        recoveryAction: 'Tap to Reconnect',
        type: AppErrorType.network,
      );
    }

    // 7. YouTube & Video Streaming Exceptions
    if (rawStr.contains('requestlimitexceeded') ||
        rawStr.contains('rate limit') ||
        rawStr.contains('too many requests') ||
        rawStr.contains('suspicious') ||
        rawStr.contains('429')) {
      return AppError(
        title: 'Server Temporarily Busy',
        reason:
            'YouTube or translation servers are experiencing temporary rate limits. Please wait a moment and try again.',
        recoveryAction: 'Retry in a moment',
        type: AppErrorType.rateLimit,
      );
    }

    if (rawStr.contains('videounplayable') ||
        rawStr.contains('unplayable') ||
        rawStr.contains('private video') ||
        rawStr.contains('restricted') ||
        rawStr.contains('copyright') ||
        rawStr.contains('video unavailable') ||
        rawStr.contains('sign in to confirm your age')) {
      return AppError(
        title: 'Video Unavailable',
        reason:
            'This video is private, restricted, or age-gated on YouTube. Please try another public video link.',
        recoveryAction: 'Paste another video link',
        type: AppErrorType.video,
      );
    }

    // 8. Timeout Exceptions
    if (error is TimeoutException ||
        rawStr.contains('timed out') ||
        rawStr.contains('deadline exceeded')) {
      return AppError(
        title: 'Connection Timed Out',
        reason:
            'The operation took too long to complete. Network latency may be elevated.',
        recoveryAction: 'Tap to Retry',
        type: AppErrorType.timeout,
      );
    }

    // 8. TLS / SSL Handshake Exceptions
    if (error is HandshakeException ||
        rawStr.contains('handshake') ||
        rawStr.contains('certificate') ||
        rawStr.contains('tls') ||
        rawStr.contains('ssl')) {
      return AppError(
        title: 'Secure Connection Issue',
        reason:
            'Could not establish an encrypted connection to the translation engine. Please check your device date and network.',
        recoveryAction: 'Check date/time & retry',
        type: AppErrorType.network,
      );
    }

    // 9. Server Maintenance / Overload (5xx codes, busy)
    if (RegExp(r'\b(50[0-4]|4500)\b').hasMatch(rawStr) ||
        rawStr.contains('temporarily unavailable') ||
        rawStr.contains('server error') ||
        rawStr.contains('overloaded') ||
        rawStr.contains('service unavailable')) {
      return AppError(
        title: 'Translation Service Busy',
        reason:
            'The AI translation engine is temporarily undergoing high load. Please try again in a few moments.',
        recoveryAction: 'Retry in a moment',
        type: AppErrorType.translationServer,
      );
    }

    // 10. Microphone & Audio Recording Exceptions
    if (rawStr.contains('permission_denied') ||
        rawStr.contains('record_audio') ||
        rawStr.contains('microphone') ||
        rawStr.contains('audio_record')) {
      return AppError(
        title: 'Microphone Permission Needed',
        reason:
            'SyncDub requires microphone access to listen to speech and deliver live dubbed audio.',
        recoveryAction: 'Enable microphone in Settings',
        type: AppErrorType.microphone,
      );
    }

    // 11. Hardware Audio Output Routing Exceptions
    if (rawStr.contains('audio_routing') ||
        rawStr.contains('bluetooth') ||
        rawStr.contains('headset') ||
        rawStr.contains('earpiece')) {
      return AppError(
        title: 'Audio Output Switch Failed',
        reason:
            'Could not switch audio route to the requested accessory. Audio has reverted to phone speaker.',
        recoveryAction: 'Check accessory connection',
        type: AppErrorType.audioRouting,
      );
    }

    // 12. Format & Parsing Exceptions (Bad JSON or invalid responses)
    if (error is FormatException ||
        rawStr.contains('formatexception') ||
        rawStr.contains('jsondecode') ||
        rawStr.contains('unexpected character')) {
      return AppError(
        title: 'Data Format Notice',
        reason:
            'Received an unexpected response format from the server. Safe fallback applied.',
        recoveryAction: 'Please retry the session',
        type: AppErrorType.general,
      );
    }

    // 13. Default Sanitized Fallback - Absolutely ZERO technical leaks
    return AppError(
      title: context != null ? '$context Notice' : 'Notice',
      reason: sanitizeRawMessage(error.toString()),
      recoveryAction: 'Please retry or restart the app',
      type: AppErrorType.general,
    );
  }

  /// Sanitizer function that aggressively scrubs all technical jargon and leaks
  static String sanitizeRawMessage(String raw) {
    var sanitized = raw.trim();

    // Strip "Exception: " prefix from standard Dart exceptions if present
    if (sanitized.startsWith('Exception: ')) {
      sanitized = sanitized.substring('Exception: '.length).trim();
    }

    // Check if the raw string contains low-level technical exception traces or socket drops
    final rawLower = sanitized.toLowerCase();
    if (rawLower.contains('socketexception') ||
        rawLower.contains('httpexception') ||
        rawLower.contains('clientexception') ||
        rawLower.contains('failed host lookup') ||
        rawLower.contains('tcp') ||
        rawLower.contains('wsasend') ||
        rawLower.contains('connection reset') ||
        rawLower.contains('connection refused') ||
        rawLower.contains('broken pipe') ||
        rawLower.contains('connection was forcibly') ||
        rawLower.contains('remote host') ||
        rawLower.contains('bad state: stream has already been listened to') ||
        rawLower.contains('nullpointer') ||
        rawLower.contains('errno =') ||
        rawLower.contains('dart:') ||
        rawLower.contains('kotlin') ||
        rawLower.contains('android.') ||
        rawLower.contains('com.syncdub') ||
        rawLower.contains('stack trace')) {
      return 'The connection was temporarily interrupted. Please tap to try again.';
    }

    // 1. Scrub complete URLs
    sanitized = sanitized.replaceAll(
      RegExp(r'(https?|wss?|ftp)://[^\s/$.?#].[^\s]*', caseSensitive: false),
      '',
    );

    // 2. Scrub IP Addresses (IPv4 and IPv6) & Ports
    sanitized = sanitized.replaceAll(
      RegExp(r'\[?\b(?:[0-9a-fA-F]{1,4}:){2,7}[0-9a-fA-F]{0,4}\]?(:\d+)?'),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d+)?\b'),
      '',
    );

    // 3. Scrub JWT tokens & Bearer tokens
    sanitized = sanitized.replaceAll(
      RegExp(r'eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}(\.[a-zA-Z0-9_-]+)?'),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'Bearer\s+[a-zA-Z0-9_\-\.]+', caseSensitive: false),
      '',
    );

    // 4. Scrub Google Client IDs & Secrets
    sanitized = sanitized.replaceAll(
      RegExp(r'\d{6,}-[a-z0-9]+\.apps\.googleusercontent\.com'),
      '',
    );

    // 5. Scrub Database Schemas, Tables, Columns & SQL terms
    sanitized = sanitized.replaceAll(
      RegExp(r'public\.[a-zA-Z0-9_]+'),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(
        r'\b(SELECT|INSERT|UPDATE|DELETE|FROM|WHERE|JOIN|DROP|ALTER|TABLE|CONSTRAINT|RELATION)\b',
        caseSensitive: false,
      ),
      '',
    );

    // 6. Scrub Local File Paths & Stack traces
    sanitized = sanitized.replaceAll(
      RegExp(r'[a-zA-Z]:\\[^\s]+\.dart(:\d+:\d+)?'),
      '',
    );
    sanitized = sanitized.replaceAll(RegExp(r'/data/user/\d+/[^\s]+'), '');
    sanitized = sanitized.replaceAll(RegExp(r'#\d+\s+[^\n]+'), '');

    // 7. Scrub technical Exception class names
    sanitized = sanitized.replaceAll(
      RegExp(
        r'(Exception|Error|PlatformException|ClientException|SocketException|HttpException|FormatException):',
        caseSensitive: false,
      ),
      '',
    );
    sanitized = sanitized.replaceAll(RegExp(r'[<>{}\[\]\(\)]'), ' ');

    // Clean up whitespace
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (sanitized.isEmpty || sanitized.length > 90 || sanitized.contains('->')) {
      return 'The requested operation could not be completed. Please try again.';
    }

    // Capitalize first letter
    return '${sanitized[0].toUpperCase()}${sanitized.substring(1)}';
  }
}

/// Convenience facade for AppError sanitization
class AppErrorHandler {
  static AppError sanitize(dynamic error, {String? context}) {
    return AppError.fromException(error, context: context);
  }
}
