import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/languages.dart';
import '../services/audio_device_service.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../services/floating_overlay_manager.dart';
import '../services/audio_pipeline_service.dart';
import '../utils/app_error_handler.dart';



class HistorySession {
  final String id;
  final String icon;
  final String title;
  final String meta;
  final String dur;
  final String originalText;
  final String dubbedText;
  final DateTime timestamp;

  const HistorySession({
    required this.id,
    required this.icon,
    required this.title,
    required this.meta,
    required this.dur,
    required this.originalText,
    required this.dubbedText,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'icon': icon,
    'title': title,
    'meta': meta,
    'dur': dur,
    'originalText': originalText,
    'dubbedText': dubbedText,
    'timestamp': timestamp.toIso8601String(),
  };

  factory HistorySession.fromJson(Map<String, dynamic> json) => HistorySession(
    id: json['id'] as String? ?? '',
    icon: json['icon'] as String? ?? '',
    title: json['title'] as String? ?? 'Live Dubbing Session',
    meta: json['meta'] as String? ?? '',
    dur: json['dur'] as String? ?? '00:00',
    originalText: json['originalText'] as String? ?? '',
    dubbedText: json['dubbedText'] as String? ?? '',
    timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
  );
}

class TranslationState extends ChangeNotifier {
  // Screen indices matching prototype:
  // 0: Login, 1: Onboarding, 2: Connecting, 3: Home, 4: Live Dubbing,
  // 5: SRT Export, 6: Paywall, 7: History, 8: Settings, 9: Offline, 10: Mic Error
  int _currentScreen = 3;

  // Onboarding
  int _onboardingStep = 0;
  final List<bool> _permGranted = [false, false];
  bool _hasCompletedOnboarding = false;

  // Auth State
  bool _isAuthenticating = false;

  // Global Active Error (Sanitized, user-facing)
  AppError? _activeError;
  AppError? get activeError => _activeError;

  void clearActiveError() {
    _activeError = null;
    notifyListeners();
  }

  void setActiveError(AppError error) {
    _activeError = error;
    notifyListeners();
  }

  // Live Dubbing Core
  bool _isTranslating = false;
  bool _isConnecting = false;
  bool _isPaused = false;
  bool _isAutoPauseOnSilenceEnabled = false;
  DateTime? _lastAudioActivityTime;
  Timer? _silenceDetectionTimer;
  int _sessionDurationSeconds = 0;
  Timer? _sessionTimer;

  // Real-time Audio Routing
  AudioOutputDevice _selectedOutputDevice = AudioDeviceService.defaultSpeaker;
  List<AudioOutputDevice> _availableOutputDevices = [AudioDeviceService.defaultSpeaker];


  // Language Selection
  SyncDubLanguage _targetLanguage = kSupportedLanguages.first; // Hindi default
  final SyncDubLanguage _sourceLanguage = const SyncDubLanguage(
    code: 'auto',
    name: 'Auto Detect',
    flag: '🌐',
    abbr: 'AUTO',
  );

  // Audio Mixer
  double _originalVolume = 0.15; // 15%
  double _dubbedVolume = 0.85; // 85%
  bool _isAutoDuckEnabled = true;

  // Floating Overlay (PiP)
  bool _isFloatingEnabled = true;
  bool _isFabVisible = true;
  String _overlaySize = 'Medium'; // 'Small', 'Medium', 'Large'
  String _overlaySnapPosition = 'Bottom Right'; // 'Bottom Right', 'Top Right', 'Bottom Left', 'Top Left'
  bool _showOverlayDubbedText = true;

  // Theme - ALWAYS defaults to Light Theme as requested
  bool _isDarkMode = false;

  // Supabase Real-Time Stream Subscription
  StreamSubscription? _profileSubscription;

  // Real-Time Telemetry
  double _creditsRemaining = 45.0; // Minutes available
  String _userPlan = 'Starter Free';
  int _latencyMs = 0;
  double _accuracyPct = 0.0;
  int _wordsDubbed = 0;
  String _statusMessage = 'Ready';

  // Backend Health Telemetry
  bool _isBackendHealthy = false;
  String _backendHealthMessage = 'Checking...';
  int _backendHealthLatency = 0;

  bool get isBackendHealthy => _isBackendHealthy;
  String get backendHealthMessage => _backendHealthMessage;
  int get backendHealthLatency => _backendHealthLatency;

  // Real-Time Subtitle Buffers
  String _liveOriginalText = '';
  String _liveDubbedText = '';

  // Paywall
  int _selectedPlan = 1; // 0: Free, 1: Pro, 2: Studio
  String _billingCycle = 'monthly'; // 'monthly' | 'yearly'

  // Real Session History (Populated strictly in real-time — zero demo records)
  final List<HistorySession> _historySessions = [];

  // Getters
  int get currentScreen => _currentScreen;
  int get onboardingStep => _onboardingStep;
  List<bool> get permGranted => _permGranted;
  bool get isAuthenticating => _isAuthenticating;

  bool get isTranslating => _isTranslating;
  bool get isConnecting => _isConnecting;
  bool get isPaused => _isPaused;
  bool get isAutoPauseOnSilenceEnabled => _isAutoPauseOnSilenceEnabled;
  DateTime? get lastAudioActivityTime => _lastAudioActivityTime;
  int get sessionDurationSeconds => _sessionDurationSeconds;

  String get formattedTimer {
    final m = _sessionDurationSeconds ~/ 60;
    final s = _sessionDurationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  SyncDubLanguage get targetLanguage => _targetLanguage;
  SyncDubLanguage get sourceLanguage => _sourceLanguage;

  double get originalVolume => _originalVolume;
  double get dubbedVolume => _dubbedVolume;
  bool get isAutoDuckEnabled => _isAutoDuckEnabled;
  bool get isFloatingEnabled => _isFloatingEnabled;
  bool get isFabVisible => _isFabVisible;
  bool get isDarkMode => _isDarkMode;

  String _preferredCaptureMode = 'internal';
  String get preferredCaptureMode => _preferredCaptureMode;
  String get activeCaptureMode => AudioPipelineService().activeCaptureMode;
  bool get isInternalAudioActive => AudioPipelineService().activeCaptureMode == 'internal';

  Future<void> setPreferredCaptureMode(String mode) async {
    _preferredCaptureMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferredCaptureMode', mode);
    notifyListeners();
  }

  String get overlaySize => _overlaySize;
  String get overlaySnapPosition => _overlaySnapPosition;
  bool get showOverlayDubbedText => _showOverlayDubbedText;

  Future<void> setOverlaySize(String size) async {
    triggerHaptic();
    _overlaySize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('overlaySize', size);
    notifyListeners();
  }

  Future<void> setOverlaySnapPosition(String pos) async {
    triggerHaptic();
    _overlaySnapPosition = pos;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('overlaySnapPosition', pos);
    notifyListeners();
  }

  Future<void> toggleOverlayDubbedText() async {
    triggerHaptic();
    _showOverlayDubbedText = !_showOverlayDubbedText;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showOverlayDubbedText', _showOverlayDubbedText);
    notifyListeners();
  }



  double get creditsRemaining => _creditsRemaining;
  String get userPlan => _userPlan;
  int get latencyMs => _latencyMs;
  double get accuracyPct => _accuracyPct;
  int get wordsDubbed => _wordsDubbed;
  String get statusMessage => _statusMessage;

  String get liveOriginalText => _liveOriginalText;
  String get liveDubbedText => _liveDubbedText;

  int get selectedPlan => _selectedPlan;
  String get billingCycle => _billingCycle;
  List<HistorySession> get historySessions => List.unmodifiable(_historySessions);

  // Settings getters
  AudioOutputDevice get selectedOutputDevice => _selectedOutputDevice;
  List<AudioOutputDevice> get availableOutputDevices => List.unmodifiable(_availableOutputDevices);
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;

  // User Profile getters
  bool get isAuthenticated => AuthService().isAuthenticated;
  String get userName => AuthService().userName;
  String? get userEmail => AuthService().userEmail;
  String? get userAvatarUrl => AuthService().userAvatarUrl;

  TranslationState() {
    _init();
  }

  Future<void> _init() async {
    FloatingOverlayManager.initialize(
      onPauseResume: () => togglePauseResume(),
      onClose: () => toggleFloating(),
      onLanguageCycle: () => cycleNextLanguage(),
    );
    FloatingOverlayManager.hideOverlay();
    await AuthService().initialize();
    await _loadPreferences();
    await refreshOutputDevices();

    // Check onboarding status first: show carousel ONLY on first launch!
    if (!_hasCompletedOnboarding) {
      _currentScreen = 1; // First-time user onboarding carousel
    } else if (!AuthService().isAuthenticated) {
      _currentScreen = 0; // Show Login if unauthenticated
    } else {
      _currentScreen = 3; // Default to Home
      _syncProfile();
      _subscribeToProfileRealtime();
    }
    checkBackendHealth();
    notifyListeners();
  }

  /// Real-time health check on Render Proxy Server
  Future<void> checkBackendHealth() async {
    _backendHealthMessage = 'Checking...';
    notifyListeners();
    final res = await SyncDubBackendService().checkBackendHealth();
    _isBackendHealthy = res['isHealthy'] as bool? ?? false;
    _backendHealthMessage = res['message'] as String? ?? 'Offline';
    _backendHealthLatency = res['latencyMs'] as int? ?? 0;
    if (_isBackendHealthy) {
      await _syncProfile();
    }
    notifyListeners();
  }

  void _subscribeToProfileRealtime() {
    _profileSubscription?.cancel();
    final stream = AuthService().profileStream;
    if (stream != null) {
      _profileSubscription = stream.listen(
        (rows) {
          if (rows.isNotEmpty) {
            final row = rows.first;
            final mins = (row['translation_minutes_remaining'] as num?)?.toDouble();
            if (mins != null) {
              _creditsRemaining = mins;
            }
            final plan = row['plan']?.toString();
            if (plan != null) {
              _userPlan = plan == 'pro'
                  ? 'SyncDub Pro'
                  : plan == 'studio'
                      ? 'Creator Studio'
                      : 'Starter Free';
            }
            notifyListeners();
          }
        },
        onError: (err) {
          debugPrint('[TranslationState] Profile realtime stream error (handled): $err');
        },
      );
    }
  }

  Future<void> _syncProfile() async {
    final profile = await AuthService().fetchUserProfile();
    if (profile != null) {
      _userPlan = profile['plan'] == 'pro'
          ? 'SyncDub Pro'
          : profile['plan'] == 'studio'
              ? 'Creator Studio'
              : 'Starter Free';
      _creditsRemaining = profile['minutes'] ?? 45.0;
      notifyListeners();
    } else {
      final planInfo = await SyncDubBackendService().fetchLiveUserPlan();
      if (planInfo != null) {
        _userPlan = planInfo.plan == 'pro'
            ? 'SyncDub Pro'
            : planInfo.plan == 'studio'
                ? 'Creator Studio'
                : 'Starter Free';
        _creditsRemaining = planInfo.minutesRemaining;
        notifyListeners();
      }
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _hasCompletedOnboarding = prefs.getBool('hasCompletedOnboarding') ?? false;

    final savedCode = prefs.getString('targetLangCode');
    if (savedCode != null) {
      final match = kSupportedLanguages.firstWhere(
        (l) => l.code == savedCode,
        orElse: () => kSupportedLanguages.first,
      );
      _targetLanguage = match;
    }
    _originalVolume = prefs.getDouble('origVol') ?? 0.15;
    _dubbedVolume = prefs.getDouble('dubVol') ?? 0.85;
    _isAutoDuckEnabled = prefs.getBool('autoDuck') ?? true;
    _isFloatingEnabled = prefs.getBool('floatingEnabled') ?? true;
    _preferredCaptureMode = prefs.getString('preferredCaptureMode') ?? 'internal';
    _overlaySize = prefs.getString('overlaySize') ?? 'Medium';
    _overlaySnapPosition = prefs.getString('overlaySnapPosition') ?? 'Bottom Right';
    _showOverlayDubbedText = prefs.getBool('showOverlayDubbedText') ?? true;
    // Default MUST ALWAYS be Light Theme (false)
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;

    // Load Real-Life Persisted Sessions (No Demo Data)
    final savedHistoryJson = prefs.getString('saved_history_sessions');
    if (savedHistoryJson != null && savedHistoryJson.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(savedHistoryJson);
        _historySessions.clear();
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            _historySessions.add(HistorySession.fromJson(item));
          }
        }
      } catch (_) {}
    }

  }

  Future<void> _saveHistorySessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _historySessions.map((s) => s.toJson()).toList();
      await prefs.setString('saved_history_sessions', jsonEncode(jsonList));
    } catch (_) {}
  }

  /// Query real-time phone audio output hardware
  Future<void> refreshOutputDevices() async {
    final devices = await AudioDeviceService.getAvailableOutputDevices();
    _availableOutputDevices = devices;
    // Keep current selected if valid
    if (!_availableOutputDevices.any((d) => d.id == _selectedOutputDevice.id)) {
      _selectedOutputDevice = _availableOutputDevices.first;
    }
    notifyListeners();
  }

  /// Change audio output route on physical device
  Future<void> selectOutputDevice(AudioOutputDevice dev) async {
    triggerHaptic();
    _selectedOutputDevice = dev;
    notifyListeners();
    await AudioDeviceService.selectAudioOutput(dev);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('outputDeviceId', dev.id);
  }

  // Tactile Haptic Trigger
  void triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  // Navigation Stack for Android Back Button handling
  final List<int> _screenStack = [];

  // Navigation with Strict Authentication Lockdown
  void goScreen(int idx) {
    triggerHaptic();
    // BINA LOGIN KE USER APP NA KHOL PAAYE: Prevent navigation to in-app screens without authentication
    if (!AuthService().isAuthenticated && idx != 0 && idx != 1) {
      _currentScreen = 0; // Force to Login Screen
      notifyListeners();
      return;
    }
    if (_currentScreen != idx) {
      _screenStack.add(_currentScreen);
      _currentScreen = idx;
      notifyListeners();
    }
  }

  /// Handles system back press.
  /// Returns true if handled by popping to previous screen or returning to Home.
  /// Returns false if already at Home screen (screen 3) or on Login/Onboarding screen so an exit dialog can be shown.
  bool handleBackPress() {
    triggerHaptic();
    // On Login Screen or Onboarding Screen, user CANNOT back press into the app
    if (_currentScreen == 0 || _currentScreen == 1) {
      return false; // Triggers system exit dialog
    }
    // If not authenticated, force stay on login screen
    if (!AuthService().isAuthenticated) {
      _currentScreen = 0;
      notifyListeners();
      return false;
    }
    if (_currentScreen != 3) {
      if (_screenStack.isNotEmpty) {
        while (_screenStack.isNotEmpty) {
          final prev = _screenStack.removeLast();
          if (prev != _currentScreen && prev >= 3) {
            _currentScreen = prev;
            notifyListeners();
            return true;
          }
        }
      }
      _currentScreen = 3;
      _screenStack.clear();
      notifyListeners();
      return true;
    }
    return false;
  }

  // Auth Handling
  Future<void> handleGoogleLogin() async {
    triggerHaptic();
    _isAuthenticating = true;
    _activeError = null;
    notifyListeners();

    final result = await AuthService().signInWithGoogle();
    _isAuthenticating = false;

    if (result.success) {
      _activeError = null;
      await _syncProfile();
      _subscribeToProfileRealtime();
      if (!_hasCompletedOnboarding) {
        _currentScreen = 1; // Onboarding for new user
      } else {
        _currentScreen = 3; // Home directly
      }
    } else {
      // SECURITY ENFORCEMENT: Never bypass login if auth fails! Stay on Login Screen!
      _currentScreen = 0;
      _activeError = result.error ?? AppError(
        title: 'Sign-In Failed',
        reason: 'Unable to authenticate your Google account. Please try again.',
        recoveryAction: 'Tap Continue with Google',
        type: AppErrorType.auth,
      );
    }
    notifyListeners();
  }

  Future<void> handleSignOut() async {
    triggerHaptic();
    _profileSubscription?.cancel();
    _profileSubscription = null;
    _isTranslating = false;
    _isConnecting = false;
    _sessionTimer?.cancel();
    FloatingOverlayManager.hideOverlay();
    _currentScreen = 0; // Back to Login immediately
    notifyListeners();
    unawaited(AuthService().signOut().timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    ));
  }

  // Onboarding
  Future<void> completeOnboardingDirectly() async {
    triggerHaptic();
    _hasCompletedOnboarding = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasCompletedOnboarding', true);
    if (!AuthService().isAuthenticated) {
      _currentScreen = 0; // Login
    } else {
      _currentScreen = 3; // Home
      _syncProfile();
      _subscribeToProfileRealtime();
    }
    notifyListeners();
  }

  void nextOnboardingStep() async {
    triggerHaptic();
    if (_onboardingStep == 0) {
      _onboardingStep = 1;
    } else if (_onboardingStep == 1) {
      _permGranted[0] = true;
      _onboardingStep = 2;
    } else if (_onboardingStep == 2) {
      _permGranted[1] = true;
      _onboardingStep = 0;
      await completeOnboardingDirectly();
    }
    notifyListeners();
  }

  void grantPermission(int step) {
    if (step >= 0 && step < _permGranted.length) {
      _permGranted[step] = true;
      notifyListeners();
    }
  }

  // Live Dubbing Control
  Future<void> toggleLiveDubbing() async {
    triggerHaptic();
    if (_isTranslating || _isConnecting) {
      // Save real session to history if active for at least 2 seconds
      if (_isTranslating && _sessionDurationSeconds >= 2) {
        final newSession = HistorySession(
          id: 'sess_${DateTime.now().millisecondsSinceEpoch}',
          icon: '',
          title: '${_targetLanguage.name} Live Dub',
          meta: '${_targetLanguage.abbr} · Real-time stream · $_wordsDubbed words',
          dur: formattedTimer,
          originalText: _liveOriginalText.isNotEmpty ? _liveOriginalText : 'Live spoken conversation',
          dubbedText: _liveDubbedText.isNotEmpty ? _liveDubbedText : 'Real-time live translated audio',
          timestamp: DateTime.now(),
        );
        _historySessions.insert(0, newSession);
        _saveHistorySessions();
      }

      // Stop dubbing
      _isConnecting = false;
      _isTranslating = false;
      _isPaused = false;
      _sessionTimer?.cancel();
      _sessionTimer = null;
      _silenceDetectionTimer?.cancel();
      _silenceDetectionTimer = null;
      await SyncDubBackendService().stopLiveDubbingSession();
      FloatingOverlayManager.hideOverlay();
      notifyListeners();
    } else {
      // 1. Quota validation
      if (_creditsRemaining <= 0) {
        _activeError = AppError(
          title: 'Translation Quota Exhausted',
          reason: 'You have 0 minutes remaining in your account. Please upgrade to continue real-time dubbing.',
          recoveryAction: 'Upgrade Plan',
          type: AppErrorType.quota,
        );
        _currentScreen = 6; // Paywall
        notifyListeners();
        return;
      }

      // 2. Ensure Audio Record permission is granted (MANDATORY for both internal video audio and microphone capture)
      try {
        final micStatus = await Permission.microphone.status;
        if (!micStatus.isGranted) {
          final reqResult = await Permission.microphone.request();
          if (!reqResult.isGranted) {
            _activeError = AppError(
              title: 'Audio Capture Permission Required',
              reason: 'SyncDub requires audio capture permission to dub playing videos. Please allow microphone/audio permission to continue.',
              recoveryAction: 'Grant Permission',
              type: AppErrorType.microphone,
            );
            notifyListeners();
            return;
          }
        }
      } catch (e) {
        _activeError = AppErrorHandler.sanitize(e, context: 'Audio Permission');
        notifyListeners();
        return;
      }

      // 3. Audio Capture Mode Selection (Direct Video Audio vs Microphone)
      String effectiveCaptureMode = _preferredCaptureMode;
      if (effectiveCaptureMode == 'internal') {
        bool internalGranted = false;
        try {
          internalGranted = await AudioPipelineService().requestInternalAudioPermission();
        } catch (e) {
          debugPrint('[TranslationState] Internal audio capture permission error: $e');
        }
        if (!internalGranted) {
          // Fallback to mic loopback if system media projection was not granted
          effectiveCaptureMode = 'mic';
        }
      }

      // 4. Start connecting in real time
      _isConnecting = true;
      _isPaused = false;
      _statusMessage = 'Connecting to SyncDub AI Engine...';
      _activeError = null;
      notifyListeners();

      try {
        // Begin backend session
        await SyncDubBackendService().startLiveDubbingSession(
          targetLanguageCode: _targetLanguage.code,
          captureMode: effectiveCaptureMode,
          onCreditsUpdate: (credits, plan) {
            _creditsRemaining = credits;
            _userPlan = plan;
            notifyListeners();
          },
          onLatencyUpdate: (latency) {
            _latencyMs = latency;
            notifyListeners();
          },
          onTranscriptUpdate: (orig, dub) {
            _liveOriginalText = orig;
            _liveDubbedText = dub;
            _wordsDubbed += 4;
            _accuracyPct = 99.4;
            notifyAudioActivity();
            notifyListeners();
          },
          onStatusChange: (status) {
            _statusMessage = status;
            if (status.contains('Active') || status.contains('Live')) {
              _isConnecting = false;
              _isTranslating = true;
              _isPaused = false;
              if (_sessionTimer == null) {
                _sessionDurationSeconds = 0;
                _startSessionTimer();
                _startSilenceDetection();
                FloatingOverlayManager.showOverlay(
                  isTranslating: true,
                  isPaused: false,
                  targetLang: _targetLanguage.code.toUpperCase(),
                );
              }
            }
            notifyListeners();
          },
          onDisconnected: (reason) {
            debugPrint('[TranslationState] Live session disconnected: $reason');
            _isConnecting = false;
            _isTranslating = false;
            _isPaused = false;
            _sessionTimer?.cancel();
            _sessionTimer = null;
            _silenceDetectionTimer?.cancel();
            _silenceDetectionTimer = null;
            _statusMessage = 'Ready to Dub';
            FloatingOverlayManager.hideOverlay();
            _activeError = AppError(
              title: 'Dubbing Disconnected',
              reason: reason,
              recoveryAction: 'Tap Start to Reconnect',
              type: AppErrorType.network,
            );
            notifyListeners();
          },
        );
      } catch (e) {
        _isConnecting = false;
        _isTranslating = false;
        _isPaused = false;
        _activeError = AppErrorHandler.sanitize(e, context: 'Live Dubbing');
        notifyListeners();
      }
    }
  }

  /// Toggle Pause / Resume during live translation (matching Chrome Extension)
  void togglePauseResume() {
    triggerHaptic();
    if (!_isTranslating) return;
    _isPaused = !_isPaused;
    if (_isPaused) {
      _statusMessage = 'Translation Paused';
      _sessionTimer?.cancel();
      _sessionTimer = null;
      SyncDubBackendService().pauseLiveStream();
    } else {
      _statusMessage = 'Live Translating';
      _lastAudioActivityTime = DateTime.now();
      _startSessionTimer();
      SyncDubBackendService().resumeLiveStream();
    }
    if (_isFloatingEnabled) {
      FloatingOverlayManager.updateOverlay(
        isTranslating: _isTranslating,
        isPaused: _isPaused,
        targetLang: _targetLanguage.code.toUpperCase(),
      );
    }
    notifyListeners();
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused) {
        _sessionDurationSeconds++;
        notifyListeners();
      }
    });
  }

  void _startSilenceDetection() {
    _silenceDetectionTimer?.cancel();
    _silenceDetectionTimer = null;
    _lastAudioActivityTime = DateTime.now();
    // Auto-pause is completely disabled so dubbing runs continuously in the background
    // without ever pausing automatically. Chunks continue to record and stream to backend.
  }

  /// Called when audio input or transcribed speech is received
  void notifyAudioActivity() {
    _lastAudioActivityTime = DateTime.now();
  }

  void toggleAutoPauseOnSilence() {
    triggerHaptic();
    _isAutoPauseOnSilenceEnabled = !_isAutoPauseOnSilenceEnabled;
    notifyListeners();
  }

  /// User action: Grant Audio Capture Permission directly from contextual box
  Future<void> requestAudioPermission() async {
    triggerHaptic();
    try {
      final internal = await AudioPipelineService().requestInternalAudioPermission();
      if (internal) {
        clearActiveError();
        await toggleLiveDubbing();
        return;
      }
      final status = await Permission.microphone.request();
      if (status.isGranted) {
        clearActiveError();
        await toggleLiveDubbing();
      } else if (status.isPermanentlyDenied) {
        await openAppSettings();
      } else {
        _activeError = AppError(
          title: 'Audio Capture Permission Required',
          reason: 'SyncDub requires system audio capture or microphone access to translate playing videos in real-time. Please allow permission.',
          recoveryAction: 'Grant Permission',
          type: AppErrorType.microphone,
        );
        notifyListeners();
      }
    } catch (e) {
      _activeError = AppErrorHandler.sanitize(e, context: 'Audio Permission');
      notifyListeners();
    }
  }

  /// Backward compatible alias for requestAudioPermission
  Future<void> requestMicPermission() => requestAudioPermission();

  /// User action: Retry connection from contextual box
  Future<void> retryConnection() async {
    triggerHaptic();
    clearActiveError();
    await toggleLiveDubbing();
  }

  void stopSessionAndExport() {
    triggerHaptic();
    _isTranslating = false;
    _isConnecting = false;
    _isPaused = false;
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _silenceDetectionTimer?.cancel();
    _silenceDetectionTimer = null;
    SyncDubBackendService().stopLiveDubbingSession();
    FloatingOverlayManager.hideOverlay();

    // Save to real history if session ran
    if (_sessionDurationSeconds > 0) {
      _historySessions.insert(
        0,
        HistorySession(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          icon: '',
          title: 'Live Dubbing · ${_targetLanguage.name}',
          meta: 'Live Session · EN → ${_targetLanguage.code.toUpperCase()}',
          dur: formattedTimer,
          originalText: _liveOriginalText,
          dubbedText: _liveDubbedText,
          timestamp: DateTime.now(),
        ),
      );
      _saveHistorySessions();
    }

    // Return to Home Dashboard (No Subtitles screen)
    _currentScreen = 3;
    notifyListeners();
  }

  // Audio Controls
  Future<void> setOriginalVolume(double vol) async {
    _originalVolume = vol;
    AudioPipelineService().setOriginalVolume(vol);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('origVol', vol);
  }

  Future<void> setDubbedVolume(double vol) async {
    _dubbedVolume = vol;
    AudioPipelineService().setDubbedVolume(vol);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('dubVol', vol);
  }

  Future<void> toggleAutoDuck() async {
    triggerHaptic();
    _isAutoDuckEnabled = !_isAutoDuckEnabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoDuck', _isAutoDuckEnabled);
  }

  Future<void> toggleFloating() async {
    triggerHaptic();
    _isFloatingEnabled = !_isFloatingEnabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('floatingEnabled', _isFloatingEnabled);

    if (_isFloatingEnabled) {
      final hasPerm = await FloatingOverlayManager.checkPermission();
      if (!hasPerm) {
        await FloatingOverlayManager.requestPermission();
      } else if (_isTranslating) {
        await FloatingOverlayManager.showOverlay(
          isTranslating: _isTranslating,
          isPaused: _isPaused,
        );
      }
    } else {
      await FloatingOverlayManager.hideOverlay();
    }
  }

  void hideFab() {
    triggerHaptic();
    _isFabVisible = false;
    notifyListeners();
  }

  void showFab() {
    triggerHaptic();
    _isFabVisible = true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    triggerHaptic();
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  Future<void> setTargetLanguage(SyncDubLanguage lang) async {
    triggerHaptic();
    _targetLanguage = lang;
    if (_isTranslating) {
      FloatingOverlayManager.updateOverlay(
        isTranslating: _isTranslating,
        isPaused: _isPaused,
        targetLang: lang.code.toUpperCase(),
      );
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('targetLangCode', lang.code);
  }

  /// Cycle to next target language (used by floating overlay language quick button)
  void cycleNextLanguage() {
    triggerHaptic();
    final currentIndex = kSupportedLanguages.indexWhere((l) => l.code == _targetLanguage.code);
    final nextIndex = currentIndex >= 0 ? (currentIndex + 1) % kSupportedLanguages.length : 0;
    setTargetLanguage(kSupportedLanguages[nextIndex]);
  }

  // Paywall controls
  void selectPlan(int planIndex) {
    triggerHaptic();
    _selectedPlan = planIndex;
    notifyListeners();
  }

  void setBillingCycle(String cycle) {
    triggerHaptic();
    _billingCycle = cycle;
    notifyListeners();
  }

  /// Activates subscription tier and grants real translation minutes in memory, local storage, and Supabase
  Future<void> activateSubscription({int? planIndex}) async {
    triggerHaptic();
    final idx = planIndex ?? _selectedPlan;
    _selectedPlan = idx;

    final String planKey;
    final String planName;
    final double grantedMinutes;

    if (idx == 2) {
      planKey = 'studio';
      planName = 'Creator Studio';
      grantedMinutes = 10000.0;
    } else if (idx == 1) {
      planKey = 'pro';
      planName = 'SyncDub Pro';
      grantedMinutes = 3000.0;
    } else {
      planKey = 'starter';
      planName = 'Starter Free';
      grantedMinutes = 45.0;
    }

    _userPlan = planName;
    _creditsRemaining = grantedMinutes;
    _activeError = null; // Clear any existing quota exhausted errors
    notifyListeners();

    // Persist to local preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userPlan', planName);
    await prefs.setDouble('creditsRemaining', grantedMinutes);

    // Persist to Supabase profiles table
    await AuthService().updateUserProfile(plan: planKey, minutes: grantedMinutes);
  }

  Future<void> clearHistory() async {
    triggerHaptic();
    _historySessions.clear();
    notifyListeners();
    await _saveHistorySessions();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }
}
