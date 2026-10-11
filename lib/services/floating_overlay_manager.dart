import 'package:flutter/services.dart';

/// Service that controls the Native Android System Overlay Window (Draw over other apps)
class FloatingOverlayManager {
  static const MethodChannel _channel =
      MethodChannel('com.syncdub.livedub/floating_overlay');

  static VoidCallback? _onPauseResumeCallback;
  static VoidCallback? _onCloseCallback;
  static VoidCallback? _onLanguageCycleCallback;
  static ValueChanged<String>? _onLanguageSelectedCallback;
  static VoidCallback? _onStopDubbingCallback;
  static bool _initialized = false;

  static void initialize({
    required VoidCallback onPauseResume,
    required VoidCallback onClose,
    VoidCallback? onLanguageCycle,
    ValueChanged<String>? onLanguageSelected,
    VoidCallback? onStopDubbing,
  }) {
    _onPauseResumeCallback = onPauseResume;
    _onCloseCallback = onClose;
    _onLanguageCycleCallback = onLanguageCycle;
    _onLanguageSelectedCallback = onLanguageSelected;
    _onStopDubbingCallback = onStopDubbing;

    if (!_initialized) {
      _channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'onPauseResumeToggled':
            _onPauseResumeCallback?.call();
            break;
          case 'onOverlayClosed':
            _onCloseCallback?.call();
            break;
          case 'onLanguageCycleRequested':
            _onLanguageCycleCallback?.call();
            break;
          case 'onStopDubbingRequested':
            _onStopDubbingCallback?.call();
            break;
          case 'onLanguageSelectedFromOverlay':
            final code = call.arguments?['code']?.toString();
            if (code != null) {
              _onLanguageSelectedCallback?.call(code);
            }
            break;
        }
      });
      _initialized = true;
    }
  }

  /// Checks if SYSTEM_ALERT_WINDOW (Display over other apps) permission is granted
  static Future<bool> checkPermission() async {
    try {
      final bool? granted = await _channel.invokeMethod<bool>('checkPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests the user to grant "Display over other apps" permission in Android Settings
  static Future<bool> requestPermission() async {
    try {
      await _channel.invokeMethod('requestPermission');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Shows the system-wide floating overlay over all apps (YouTube, Reels, Home screen)
  static Future<void> showOverlay({
    bool isTranslating = false,
    bool isPaused = false,
    String targetLang = 'HI',
    String targetLangFlag = '🇮🇳',
    String targetLangName = 'Hindi',
  }) async {
    try {
      final hasPerm = await checkPermission();
      if (!hasPerm) {
        requestPermission();
      }
      // Always invoke native showOverlay so the Android Foreground Service starts with mic wakelock
      await _channel.invokeMethod('showOverlay', {
        'isTranslating': isTranslating,
        'isPaused': isPaused,
        'targetLang': targetLang,
        'targetLangFlag': targetLangFlag,
        'targetLangName': targetLangName,
      });
    } catch (_) {}
  }

  /// Updates the live state of the floating overlay (live emerald dot vs paused amber dot)
  static Future<void> updateOverlay({
    bool isTranslating = false,
    bool isPaused = false,
    String targetLang = 'HI',
    String targetLangFlag = '🇮🇳',
    String targetLangName = 'Hindi',
  }) async {
    try {
      await _channel.invokeMethod('updateOverlay', {
        'isTranslating': isTranslating,
        'isPaused': isPaused,
        'targetLang': targetLang,
        'targetLangFlag': targetLangFlag,
        'targetLangName': targetLangName,
      });
    } catch (_) {}
  }

  /// Makes sure the foreground service (mic / media-projection keep-alive) is running
  /// even when the floating bubble itself is disabled by the user.
  static Future<void> ensureForeground() async {
    try {
      await _channel.invokeMethod('ensureForeground');
    } catch (_) {}
  }

  /// Removes only the floating bubble, the foreground service keeps running (live session active).
  static Future<void> removeOverlayKeepService() async {
    try {
      await _channel.invokeMethod('removeOverlayKeepService');
    } catch (_) {}
  }

  /// Hides and destroys the system floating overlay
  static Future<void> hideOverlay() async {
    try {
      await _channel.invokeMethod('hideOverlay');
    } catch (_) {}
  }
}
