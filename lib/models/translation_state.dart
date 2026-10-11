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
import '../services/revenue_cat_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
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
  final String? videoUrl;
  final String? localAudioPath;
  final String? thumbnailUrl;
  final String? platform;
  final String? targetLang;

  const HistorySession({
    required this.id,
    required this.icon,
    required this.title,
    required this.meta,
    required this.dur,
    required this.originalText,
    required this.dubbedText,
    required this.timestamp,
    this.videoUrl,
    this.localAudioPath,
    this.thumbnailUrl,
    this.platform,
    this.targetLang,
  });

  String? get effectiveThumbnailUrl {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return thumbnailUrl;
    }
    if (videoUrl != null && videoUrl!.isNotEmpty) {
      final uri = Uri.tryParse(videoUrl!);
      String? id;
      if (uri != null) {
        if (uri.queryParameters.containsKey('v')) {
          id = uri.queryParameters['v'];
        } else if (uri.pathSegments.isNotEmpty) {
          id = uri.pathSegments.last;
        }
      }
      if (id != null && id.isNotEmpty) {
        return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'icon': icon,
    'title': title,
    'meta': meta,
    'dur': dur,
    'originalText': originalText,
    'dubbedText': dubbedText,
    'timestamp': timestamp.toIso8601String(),
    if (videoUrl != null) 'videoUrl': videoUrl,
    if (localAudioPath != null) 'localAudioPath': localAudioPath,
    if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    if (platform != null) 'platform': platform,
    if (targetLang != null) 'targetLang': targetLang,
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
    videoUrl: json['videoUrl'] as String?,
    localAudioPath: json['localAudioPath'] as String?,
    thumbnailUrl: json['thumbnailUrl'] as String?,
    platform: json['platform'] as String?,
    targetLang: json['targetLang'] as String?,
  );
}

class TranslationState extends ChangeNotifier with WidgetsBindingObserver {
  // Screen indices matching prototype:
  // 0: Login, 1: Onboarding, 2: Connecting, 3: Home, 4: Live Dubbing,
  // 5: SRT Export, 6: Paywall, 7: History, 8: Settings, 9: Offline, 10: Mic Error
  int _currentScreen;

  // Onboarding
  int _onboardingStep = 0;
  final List<bool> _permGranted = [false, false];
  bool _hasCompletedOnboarding;

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
  bool _isAutoPauseOnSilenceEnabled = true;
  final Stopwatch _activityStopwatch = Stopwatch()..start();
  int _lastAudioActivityMs = 0;
  Timer? _silenceDetectionTimer;
  int _sessionDurationSeconds = 0;
  Timer? _sessionTimer;
  bool _hasDetectedInitialAudio = false;
  double _smoothedAmp = 0.0;

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

  // Audio Mixer - Defaults to 0% real video volume and 100% dubbed voice volume
  double _originalVolume = 0.0; // 0%
  double _dubbedVolume = 1.0; // 100%

  // Floating Overlay (PiP)
  bool _isFloatingEnabled = true;
  bool _isFabVisible = true;

  // Theme - ALWAYS defaults to Light Theme as requested
  bool _isDarkMode = false;
  final ValueNotifier<bool> darkModeNotifier = ValueNotifier<bool>(false);

  // Supabase Real-Time Stream Subscription
  StreamSubscription? _profileSubscription;

  // Real-Time Telemetry
  double? _creditsRemaining; // Minutes available (null until fetched from Supabase/cloud)
  bool get isCreditsLoaded => _creditsRemaining != null;
  double get creditsRemaining => _creditsRemaining ?? 0.0;
  String _userPlan = 'Starter Free';
  String _planKey = 'free'; // raw server/profile key: free | pro | studio | power
  int _latencyMs = 0;
  final double _accuracyPct = 0.0; // no real accuracy metric from the server, so no fake 99.4%
  String _statusMessage = 'Ready';

  // Backend Health Telemetry
  bool _isBackendHealthy = false;
  String _backendHealthMessage = 'Checking...';
  int _backendHealthLatency = 0;

  bool get isBackendHealthy => _isBackendHealthy;
  String get backendHealthMessage => _backendHealthMessage;
  int get backendHealthLatency => _backendHealthLatency;

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
  bool get isAutoPaused => _isAutoPaused;
  int get lastAudioActivityMs => _lastAudioActivityMs;
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

  String get userPlan => _userPlan;
  int get latencyMs => _latencyMs;
  double get accuracyPct => _accuracyPct;
  String get statusMessage => _statusMessage;

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

  TranslationState({
    bool initialHasCompletedOnboarding = false,
    bool initialIsAuthenticated = false,
  })  : _hasCompletedOnboarding = initialHasCompletedOnboarding,
        _currentScreen = !initialHasCompletedOnboarding
            ? 1 // First-time user onboarding carousel directly from frame 0!
            : (!initialIsAuthenticated ? 0 : 3) {
    _init();
  }

  Future<void> _init() async {
    FloatingOverlayManager.initialize(
      onPauseResume: () => togglePauseResume(),
      onClose: () => toggleFloating(),
      onLanguageCycle: () => cycleNextLanguage(),
      onLanguageSelected: (code) => setTargetLanguageByCode(code),
      onStopDubbing: () {
        if (_isTranslating || _isConnecting) toggleLiveDubbing();
      },
    );
    FloatingOverlayManager.hideOverlay();
    AudioPipelineService().onMediaProjectionStopped = () {
      debugPrint('[TranslationState] Media projection stopped by OS or user. Cutting off connection.');
      if (_isTranslating || _isConnecting) {
        toggleLiveDubbing();
      }
    };
    await AuthService().initialize();
    await _loadPreferences();
    await refreshOutputDevices();
    AudioPipelineService().setOriginalVolume(_originalVolume);
    AudioPipelineService().setDubbedVolume(_dubbedVolume);

    // RevenueCat is the ONLY billing stack. The app never credits minutes itself: purchases are
    // confirmed by RevenueCat's server-to-server webhook, which credits the profile on the server.
    unawaited(RevenueCatService().initialize(appUserId: AuthService().user?.id));

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

    // Register lifecycle observer to detect permission changes on app resume
    WidgetsBinding.instance.addObserver(this);

    // Proactively request Appear on Top, Microphone, and Notification permissions right on app launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestStartupPermissions();
    });
  }

  /// Proactively requests all necessary Android permissions right on app launch:
  /// 1. Microphone (RECORD_AUDIO)
  /// 2. Notifications (POST_NOTIFICATIONS on Android 13+)
  /// 3. Appear on Top (SYSTEM_ALERT_WINDOW overlay permission)
  Future<void> requestStartupPermissions() async {
    try {
      // 1. Microphone permission
      final micGranted = await Permission.microphone.isGranted;
      if (!micGranted) {
        final res = await Permission.microphone.request();
        if (res.isGranted) {
          grantPermission(0);
        }
      } else {
        grantPermission(0);
      }

      // 2. Notification permission
      final notifGranted = await Permission.notification.isGranted;
      if (!notifGranted) {
        await Permission.notification.request();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[TranslationState] Error requesting startup permissions: $e');
    }
  }

  DateTime? _lastBackendWake;

  /// Fire-and-forget ping that wakes a sleeping Render instance (a cold start takes ~20 s). Called
  /// when the app comes to the foreground, so the engine is already awake when the user taps Start
  /// and the first dubbed word is not delayed by the cold start. Throttled and silent (no UI state).
  void wakeBackend() {
    if (isTranslating) return;
    final now = DateTime.now();
    final last = _lastBackendWake;
    if (last != null && now.difference(last) < const Duration(minutes: 3)) return;
    _lastBackendWake = now;
    unawaited(SyncDubBackendService().checkBackendHealth());
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
              SharedPreferences.getInstance().then((p) => p.setDouble('syncdub_cached_user_credits', mins));
            }
            _setPlan(row['plan']?.toString());
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
    final prefs = await SharedPreferences.getInstance();
    final profile = await AuthService().fetchUserProfile();
    if (profile != null) {
      _setPlan(profile['plan']?.toString());
      final mins = (profile['minutes'] as num?)?.toDouble();
      if (mins != null) {
        _creditsRemaining = mins;
        await prefs.setDouble('syncdub_cached_user_credits', mins);
      }
      notifyListeners();
    } else {
      final planInfo = await SyncDubBackendService().fetchLiveUserPlan();
      if (planInfo != null) {
        _setPlan(planInfo.plan);
        _creditsRemaining = planInfo.minutesRemaining;
        await prefs.setDouble('syncdub_cached_user_credits', planInfo.minutesRemaining);
        notifyListeners();
      }
    }

    // Sync authenticated user with RevenueCat
    final authUser = AuthService().user;
    if (authUser != null) {
      unawaited(RevenueCatService().logIn(authUser.id));
    }
  }

  static String _planDisplayName(String key) {
    switch (key) {
      case 'starter':
        return 'SyncDub Starter';
      case 'pro':
        return 'SyncDub Pro';
      case 'studio':
        return 'Creator Studio';
      case 'power':
        return 'Power Viewer';
      default:
        return 'Starter Free';
    }
  }

  void _setPlan(String? key) {
    if (key == null || key.trim().isEmpty) return;
    _planKey = key.trim().toLowerCase();
    _userPlan = _planDisplayName(_planKey);
  }

  // No transcripts are requested from the engine (they only added latency), so history keeps fixed labels.
  static const String _historyOriginalText = 'Live spoken conversation';
  static const String _historyDubbedText = 'Real-time live translated audio';

  /// Saves the running session to history (>= 2s). Call BEFORE the live flags are reset.
  void _archiveSessionIfActive() {
    if (!_isTranslating || _sessionDurationSeconds < 2) return;
    _historySessions.insert(
      0,
      HistorySession(
        id: 'sess_${DateTime.now().millisecondsSinceEpoch}',
        icon: '',
        title: '${_targetLanguage.name} Live Dub',
        meta: '${_targetLanguage.abbr} · Real-time stream',
        dur: formattedTimer,
        originalText: _historyOriginalText,
        dubbedText: _historyDubbedText,
        timestamp: DateTime.now(),
      ),
    );
    _saveHistorySessions();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _hasCompletedOnboarding = prefs.getBool('hasCompletedOnboarding') ?? false;

    final savedCode = prefs.getString('targetLangCode');
    if (savedCode != null) {
      final cleanSaved = savedCode.toLowerCase().split('-').first;
      final match = kSupportedLanguages.where((l) => l.code.toLowerCase() == savedCode.toLowerCase()).firstOrNull ??
          kSupportedLanguages.where((l) => l.code.toLowerCase() == cleanSaved).firstOrNull ??
          kSupportedLanguages.where((l) => savedCode.toLowerCase().startsWith(l.code.toLowerCase())).firstOrNull ??
          kSupportedLanguages.first;
      _targetLanguage = match;
    }
    _originalVolume = prefs.getDouble('origVol') ?? 0.0;
    _dubbedVolume = prefs.getDouble('dubVol') ?? 1.0;
    _isFloatingEnabled = prefs.getBool('floatingEnabled') ?? true;
    _preferredCaptureMode = prefs.getString('preferredCaptureMode') ?? 'internal';
    // Default MUST ALWAYS be Light Theme (false)
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    darkModeNotifier.value = _isDarkMode;

    // Smart Video Silence Detection preference
    _isAutoPauseOnSilenceEnabled = prefs.getBool('autoPauseOnSilenceEnabled') ?? true;

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

    // Ensure no hardcoded or obsolete cached credits default to 45 min
    // Credits remain null until fetched directly from Supabase / server
    if (prefs.getDouble('syncdub_cached_user_credits') == 45.0) {
      await prefs.remove('syncdub_cached_user_credits');
    }
    if (prefs.getDouble('creditsRemaining') == 45.0) {
      await prefs.remove('creditsRemaining');
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
    _creditPollTimer?.cancel();
    _creditPollTimer = null;
    _isAwaitingCredit = false;
    _archiveSessionIfActive();
    _isTranslating = false;
    _isConnecting = false;
    _isPaused = false;
    _isAutoPaused = false;
    _isSwitchingLanguage = false;
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _silenceDetectionTimer?.cancel();
    _silenceDetectionTimer = null;
    unawaited(SyncDubBackendService().stopLiveDubbingSession());
    // Never leak the previous account's balance/plan into the next login
    _creditsRemaining = null;
    _planKey = 'free';
    _userPlan = 'Starter Free';
    FloatingOverlayManager.hideOverlay();
    _currentScreen = 0; // Back to Login immediately
    notifyListeners();
    unawaited(AuthService().signOut().timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    ));
    unawaited(RevenueCatService().logOut());
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
      _archiveSessionIfActive();

      // Stop dubbing
      _isConnecting = false;
      _isTranslating = false;
      _isPaused = false;
      _isAutoPaused = false;
      _isSwitchingLanguage = false;
      _sessionTimer?.cancel();
      _sessionTimer = null;
      _silenceDetectionTimer?.cancel();
      _silenceDetectionTimer = null;
      AudioPipelineService().stopPlayback();
      await SyncDubBackendService().stopLiveDubbingSession();
      FloatingOverlayManager.hideOverlay();
      notifyListeners();
    } else {
      if (_startInFlight) return;
      _startInFlight = true;
      try {
        await _startLiveDubbing();
      } finally {
        _startInFlight = false;
      }
    }
  }

  bool _startInFlight = false;

  Future<void> _startLiveDubbing() async {
      // 1. Quota validation
      if (_creditsRemaining != null && _creditsRemaining! <= 0) {
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

      // 3. Audio Capture Mode (Direct Screen / Video Audio Capture or Mic)
      // LATENCY: the Android screen-capture dialog is NOT awaited here any more. It opens now, and the
      // server handshake (token, WebSocket, auth, model setup) runs underneath it. Capture starts the
      // moment the user taps Allow, so the dialog time no longer adds to the time-to-first-dubbed-audio.
      String effectiveCaptureMode = _preferredCaptureMode;
      String permOutcome = 'granted';
      Future<String?> captureModeFuture;
      if (effectiveCaptureMode == 'internal') {
        captureModeFuture = AudioPipelineService()
            .requestInternalAudioPermission()
            .catchError((Object e) {
          debugPrint('[TranslationState] Internal audio capture permission error: $e');
          return 'not_supported';
        }).then<String?>((permStatus) {
          permOutcome = permStatus;
          if (permStatus == 'granted') return 'internal';
          // Fall back gracefully to mic capture without error
          if (permStatus == 'not_supported') return 'mic';
          return null; // cancelled or denied
        });
      } else {
        captureModeFuture = Future<String?>.value(effectiveCaptureMode);
      }

      // 4. Start connecting in real time
      _latencyMs = 0;
      _isConnecting = true;
      _isPaused = false;
      _statusMessage = 'Connecting to SyncDub AI Engine...';
      _activeError = null;
      notifyListeners();

      // Synchronize dubbed volume directly to native audio layer
      AudioPipelineService().setDubbedVolume(_dubbedVolume);

      try {
        // Begin backend session
        await SyncDubBackendService().startLiveDubbingSession(
          targetLanguageCode: _targetLanguage.code,
          captureMode: effectiveCaptureMode,
          captureModeFuture: captureModeFuture,
          onCreditsUpdate: (credits, plan) {
            _creditsRemaining = credits;
            _setPlan(plan);
            notifyListeners();
          },
          onLatencyUpdate: (latency) {
            _latencyMs = latency;
            notifyListeners();
          },
          onStatusChange: (status) {
            if (_isPaused) {
              _statusMessage = 'Translation Paused';
            } else {
              _statusMessage = status;
            }
            if (status.contains('Active') || status.contains('Live')) {
              final wasConnecting = _isConnecting;
              _isConnecting = false;
              _isTranslating = true;
              AudioPipelineService().setDubbedVolume(_dubbedVolume);
              AudioPipelineService().setOriginalVolume(_originalVolume);
              if (wasConnecting && _sessionTimer == null && !_isPaused) {
                _isPaused = false;
                _sessionDurationSeconds = 0;
                _startSessionTimer();
                _startSilenceDetection();
                if (_isFloatingEnabled) {
                  FloatingOverlayManager.showOverlay(
                    isTranslating: true,
                    isPaused: false,
                    targetLang: _targetLanguage.abbr,
                    targetLangFlag: _targetLanguage.flag,
                    targetLangName: _targetLanguage.name,
                  );
                } else {
                  // Bubble disabled: the foreground service must STILL run, otherwise Android silences
                  // background mic/projection capture as soon as the user opens the video app.
                  FloatingOverlayManager.ensureForeground();
                }
              }
            }
            notifyListeners();
          },
          onDisconnected: (reason) {
            debugPrint('[TranslationState] Live session disconnected: $reason');
            _archiveSessionIfActive();
            _isConnecting = false;
            _isTranslating = false;
            _isPaused = false;
            _isAutoPaused = false;
            _isSwitchingLanguage = false;
            _sessionTimer?.cancel();
            _sessionTimer = null;
            _silenceDetectionTimer?.cancel();
            _silenceDetectionTimer = null;
            _statusMessage = 'Ready to Dub';
            AudioPipelineService().stopPlayback();
            FloatingOverlayManager.hideOverlay();
            _activeError = AppErrorHandler.sanitize(
              reason,
              context: 'Live Dubbing',
            );
            notifyListeners();
          },
        );

        // The handshake is already running; now settle the capture-permission dialog that opened with it.
        final resolvedCaptureMode = await captureModeFuture;
        if (resolvedCaptureMode == null) {
          // The backend tears the half-open session down itself; only the UI is reset here.
          _isConnecting = false;
          _isTranslating = false;
          if (permOutcome == 'user_cancelled') {
            // User cancelled or backed out from the system screen capture prompt
            debugPrint('[TranslationState] User cancelled screen capture dialog. Aborting live session.');
            _statusMessage = 'Ready to Dub';
          } else {
            _statusMessage = 'Screen Audio Required';
            _activeError = AppError(
              title: 'Screen Audio Permission Required',
              reason: 'SyncDub requires screen audio capture permission to dub playing videos directly from your screen.',
              recoveryAction: 'Tap to Allow',
              type: AppErrorType.microphone,
            );
          }
          FloatingOverlayManager.hideOverlay();
          notifyListeners();
        } else if (resolvedCaptureMode == 'mic' && effectiveCaptureMode == 'internal') {
          debugPrint('[TranslationState] Internal audio not supported, falling back to mic capture.');
        }
      } catch (e) {
        _isConnecting = false;
        _isTranslating = false;
        _isPaused = false;
        _isAutoPaused = false;
        _isSwitchingLanguage = false;
        _sessionTimer?.cancel();
        _sessionTimer = null;
        _silenceDetectionTimer?.cancel();
        _silenceDetectionTimer = null;
        AudioPipelineService().stopPlayback();
        await SyncDubBackendService().stopLiveDubbingSession();
        FloatingOverlayManager.hideOverlay();
        _activeError = AppErrorHandler.sanitize(e, context: 'Live Dubbing');
        notifyListeners();
      }
  }

  /// Toggle Pause / Resume during live translation (matching Chrome Extension)
  void togglePauseResume() {
    triggerHaptic();
    if (!_isTranslating) return;
    _isPaused = !_isPaused;
    _isAutoPaused = false; // Manual toggle always clears auto-pause state
    if (_isPaused) {
      _statusMessage = 'Translation Paused';
      _sessionTimer?.cancel();
      _sessionTimer = null;
      AudioPipelineService().setDubbingPaused(true); // native input gate + playback flush + system volume back, first
      SyncDubBackendService().pauseLiveStream();
      AudioPipelineService().stopPlayback();
    } else {
      _statusMessage = 'Live Translating';
      _lastAudioActivityMs = _activityStopwatch.elapsedMilliseconds;
      _startSessionTimer();
      SyncDubBackendService().resumeLiveStream();
      AudioPipelineService().setDubbingPaused(false);
      AudioPipelineService().setOriginalVolume(_originalVolume); // Restore user volume
      AudioPipelineService().setDubbedVolume(_dubbedVolume); // Restore dubbed volume
    }
    if (_isFloatingEnabled) {
      FloatingOverlayManager.updateOverlay(
        isTranslating: _isTranslating,
        isPaused: _isPaused,
        targetLang: _targetLanguage.abbr,
        targetLangFlag: _targetLanguage.flag,
        targetLangName: _targetLanguage.name,
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

  /// Chrome Extension-style silence detection auto-pause.
  ///
  /// Polls mic amplitude (RMS) every 200ms.
  /// If amplitude stays below [_silenceThreshold] for [_silenceDurationMs] ms → auto-pause playback.
  /// If amplitude rises above [_resumeThreshold] while auto-paused → auto-resume.
  ///
  /// Thresholds calibrated for video playback with compression noise floor.
  static const double _silenceThreshold = 0.015; // RMS below this = silence
  static const double _resumeThreshold = 0.018;  // RMS above this = speech onset
  static const int _silenceDurationMs = 900;     // 0.9s of sustained silence → auto-pause (video stopped)

  bool _isAutoPaused = false; // true only when paused *by* silence detection (not user manual)

  Future<void> toggleAutoPauseOnSilence() async {
    triggerHaptic();
    _isAutoPauseOnSilenceEnabled = !_isAutoPauseOnSilenceEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoPauseOnSilenceEnabled', _isAutoPauseOnSilenceEnabled);
    if (!_isAutoPauseOnSilenceEnabled && _isAutoPaused) {
      _isAutoPaused = false;
      _isPaused = false;
      _lastAudioActivityMs = _activityStopwatch.elapsedMilliseconds;
      _statusMessage = 'Live Translating';
      SyncDubBackendService().resumeLiveStream(guard: false);
      AudioPipelineService().setDubbingPaused(false);
      AudioPipelineService().setOriginalVolume(_originalVolume);
      AudioPipelineService().setDubbedVolume(_dubbedVolume);
      if (_isFloatingEnabled) {
        FloatingOverlayManager.updateOverlay(
          isTranslating: _isTranslating,
          isPaused: false,
          targetLang: _targetLanguage.abbr,
          targetLangFlag: _targetLanguage.flag,
          targetLangName: _targetLanguage.name,
        );
      }
    }
    notifyListeners();
  }

  void _autoPauseNow(String why) {
    if (_isPaused || !_isTranslating) return;
    _isAutoPaused = true;
    _isPaused = true;
    _statusMessage = 'Auto-Paused (silence)';
    SyncDubBackendService().pauseLiveStream(stopPlayback: false);
    AudioPipelineService().setDubbingPaused(true);
    debugPrint('[SilenceDetection] Auto-paused: $why');
    if (_isFloatingEnabled) {
      FloatingOverlayManager.updateOverlay(
        isTranslating: _isTranslating,
        isPaused: true,
        targetLang: _targetLanguage.abbr,
        targetLangFlag: _targetLanguage.flag,
        targetLangName: _targetLanguage.name,
      );
    }
    notifyListeners();
  }

  void _autoResumeNow(String why) {
    if (!_isPaused || !_isAutoPaused || !_isTranslating) return;
    _isAutoPaused = false;
    _isPaused = false;
    _lastAudioActivityMs = _activityStopwatch.elapsedMilliseconds;
    _statusMessage = 'Live Translating';
    SyncDubBackendService().resumeLiveStream(guard: false);
    // preroll: re-sends the last ~0.6s so the first syllables of the resumed speech are not clipped
    AudioPipelineService().setDubbingPaused(false, preroll: true);
    AudioPipelineService().setOriginalVolume(_originalVolume);
    AudioPipelineService().setDubbedVolume(_dubbedVolume);
    debugPrint('[SilenceDetection] Auto-resumed: $why');
    if (_isFloatingEnabled) {
      FloatingOverlayManager.updateOverlay(
        isTranslating: _isTranslating,
        isPaused: false,
        targetLang: _targetLanguage.abbr,
        targetLangFlag: _targetLanguage.flag,
        targetLangName: _targetLanguage.name,
      );
    }
    notifyListeners();
  }

  /// Instant signal from Android's AudioPlaybackCallback: the other app's player started / stopped.
  /// Manual pauses are never touched; the amplitude silence detector stays as the fallback for apps
  /// that keep their audio stream open.
  void _onExternalPlaybackChanged(bool active) {
    if (!_isTranslating || !_isAutoPauseOnSilenceEnabled) return;
    if (active) {
      _hasDetectedInitialAudio = true;
      _lastAudioActivityMs = _activityStopwatch.elapsedMilliseconds;
      _autoResumeNow('video playback started');
    } else {
      _autoPauseNow('video playback stopped');
    }
  }

  void _startSilenceDetection() {
    _silenceDetectionTimer?.cancel();
    _silenceDetectionTimer = null;
    AudioPipelineService().onExternalPlaybackChanged = _onExternalPlaybackChanged;
    _lastAudioActivityMs = _activityStopwatch.elapsedMilliseconds;
    _isAutoPaused = false;
    _hasDetectedInitialAudio = false;
    _smoothedAmp = 0.0;

    _silenceDetectionTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!_isTranslating) return;

      final amp = AudioPipelineService().micAmplitude.value;
      _smoothedAmp = (_smoothedAmp * 0.7) + (amp * 0.3);

      // 1. Startup / Waiting phase: Never auto-pause before video audio/speech actually begins!
      // This ensures that when the user starts dubbing and switches to YouTube/Instagram,
      // it NEVER prematurely auto-pauses while they are opening their video.
      if (!_hasDetectedInitialAudio) {
        final bool detected = amp >= _silenceThreshold ||
            _smoothedAmp >= _silenceThreshold ||
            AudioPipelineService().isDubbedVoicePlaying;
        if (detected) {
          _hasDetectedInitialAudio = true;
          _lastAudioActivityMs = _activityStopwatch.elapsedMilliseconds;
          debugPrint('[SilenceDetection] Initial video audio/speech detected! Silence auto-pause armed.');
        } else {
          // If after 30 seconds no video was ever played, arm the detector to avoid indefinite drain
          if (_sessionDurationSeconds >= 30) {
            _hasDetectedInitialAudio = true;
          }
          _lastAudioActivityMs = _activityStopwatch.elapsedMilliseconds;
          return;
        }
      }

      if (_isAutoPauseOnSilenceEnabled) {
        if (!_isPaused) {
          // Active speech check: speech is present if instantaneous amp OR smoothed amp is above threshold,
          // OR if dubbed audio is currently playing through the speaker.
          final bool isSpeechActive = amp >= _silenceThreshold ||
              _smoothedAmp >= _silenceThreshold;

          if (isSpeechActive) {
            _lastAudioActivityMs = _activityStopwatch.elapsedMilliseconds; // Speech active — reset silence timer
          } else {
            final silenceMs = _activityStopwatch.elapsedMilliseconds - _lastAudioActivityMs;
            if (silenceMs >= _silenceDurationMs) {
              // Silence threshold crossed → auto-pause
              _autoPauseNow('${silenceMs}ms silence (amp=$amp, smoothed=$_smoothedAmp)');
            }
          }
        } else if (_isAutoPaused) {
          // Auto-resume check: if audio signal rises again, resume automatically
          final bool shouldResume = amp >= _resumeThreshold || _smoothedAmp >= _resumeThreshold;
          if (shouldResume) {
            _autoResumeNow('amp=$amp, smoothed=$_smoothedAmp > $_resumeThreshold');
          }
        }
        // If manually paused by user (_isPaused && !_isAutoPaused), do nothing — respect user intent
      }
    });
  }

  /// Called when audio input is received.
  /// Only extends the silence window - resuming from auto-pause is driven by the live audio
  /// amplitude (or the native playback signal), never by this call.
  void notifyAudioActivity() {
    _hasDetectedInitialAudio = true;
    if (!_isPaused) {
      _lastAudioActivityMs = _activityStopwatch.elapsedMilliseconds;
    }
  }


  /// User action: Grant Audio Capture Permission directly from contextual box
  Future<void> requestAudioPermission() async {
    triggerHaptic();
    try {
      final micStatus = await Permission.microphone.status;
      if (micStatus.isPermanentlyDenied) {
        await openAppSettings();
        return;
      }
      if (!micStatus.isGranted) {
        final req = await Permission.microphone.request();
        if (req.isPermanentlyDenied) {
          await openAppSettings();
          return;
        }
        if (!req.isGranted) {
          return;
        }
      }
      clearActiveError();
      await toggleLiveDubbing();
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
    _isAutoPaused = false;
    _isSwitchingLanguage = false;
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _silenceDetectionTimer?.cancel();
    _silenceDetectionTimer = null;
    AudioPipelineService().onExternalPlaybackChanged = null;
    AudioPipelineService().stopPlayback();
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
          originalText: _historyOriginalText,
          dubbedText: _historyDubbedText,
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
    _originalVolume = vol.clamp(0.0, 1.0);
    AudioPipelineService().setOriginalVolume(_originalVolume);
    notifyListeners();
  }

  Future<void> persistOriginalVolume(double vol) async {
    _originalVolume = vol.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('origVol', _originalVolume);
  }

  Future<void> setDubbedVolume(double vol) async {
    _dubbedVolume = vol.clamp(0.0, 1.0);
    AudioPipelineService().setDubbedVolume(_dubbedVolume);
    notifyListeners();
  }

  Future<void> persistDubbedVolume(double vol) async {
    _dubbedVolume = vol.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('dubVol', _dubbedVolume);
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
          targetLang: _targetLanguage.abbr,
          targetLangFlag: _targetLanguage.flag,
          targetLangName: _targetLanguage.name,
        );
      }
    } else if (_isTranslating || _isConnecting) {
      // Remove only the bubble; stopping the service here would kill background capture mid-session
      await FloatingOverlayManager.removeOverlayKeepService();
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
    darkModeNotifier.value = _isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  bool _isSwitchingLanguage = false;
  bool get isSwitchingLanguage => _isSwitchingLanguage;

  Future<void> setTargetLanguage(SyncDubLanguage lang) async {
    if (_targetLanguage.code == lang.code) return;
    triggerHaptic();
    final previousLang = _targetLanguage;
    _targetLanguage = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('targetLangCode', lang.code);

    if (_isFloatingEnabled) {
      FloatingOverlayManager.updateOverlay(
        isTranslating: _isTranslating,
        isPaused: _isPaused,
        targetLang: lang.abbr,
        targetLangFlag: lang.flag,
        targetLangName: lang.name,
      );
    }
    notifyListeners();

    // If dubbing is actively streaming, seamlessly switch SyncDub AI session in real-time
    if (_isTranslating && !_isSwitchingLanguage) {
      await _switchLanguageInActiveSession(lang, previousLang);
    }
  }

  Future<void> _switchLanguageInActiveSession(SyncDubLanguage newLang, SyncDubLanguage oldLang) async {
    _isSwitchingLanguage = true;
    _isConnecting = true;
    _statusMessage = 'Switching to ${newLang.name}…';
    notifyListeners();

    try {
      debugPrint('[TranslationState] Realtime switching live dubbing session to ${newLang.name} (${newLang.code})...');

      // Stop previous language playback immediately
      AudioPipelineService().stopPlayback();

      await SyncDubBackendService().switchTargetLanguage(
        newTargetLanguageCode: newLang.code,
        captureMode: AudioPipelineService().activeCaptureMode,
        onCreditsUpdate: (credits, plan) {
          _creditsRemaining = credits;
          _setPlan(plan);
          notifyListeners();
        },
        onLatencyUpdate: (latency) {
          _latencyMs = latency;
          notifyListeners();
        },
        onStatusChange: (status) {
          if (_isPaused) {
            _statusMessage = 'Translation Paused';
          } else {
            _statusMessage = status;
          }
          if (status.contains('Active') || status.contains('Live')) {
            _isConnecting = false;
            _isTranslating = true;
            AudioPipelineService().setDubbedVolume(_dubbedVolume);
            AudioPipelineService().setOriginalVolume(_originalVolume);
            if (_targetLanguage.code != newLang.code) {
              _isSwitchingLanguage = true;
              final pending = _targetLanguage;
              Future<void>.microtask(() => _switchLanguageInActiveSession(pending, newLang));
              notifyListeners();
              return;
            }
            _isSwitchingLanguage = false;
            if (_isFloatingEnabled) {
              FloatingOverlayManager.updateOverlay(
                isTranslating: true,
                isPaused: _isPaused,
                targetLang: newLang.abbr,
                targetLangFlag: newLang.flag,
                targetLangName: newLang.name,
              );
            }
          }
          notifyListeners();
        },
        onDisconnected: (reason) {
          debugPrint('[TranslationState] Live session disconnected: $reason');
          _archiveSessionIfActive();
          _isSwitchingLanguage = false;
          _isConnecting = false;
          _isTranslating = false;
          _isPaused = false;
          _isAutoPaused = false;
          _sessionTimer?.cancel();
          _sessionTimer = null;
          _silenceDetectionTimer?.cancel();
          _silenceDetectionTimer = null;
          _statusMessage = 'Ready to Dub';
          AudioPipelineService().stopPlayback();
          FloatingOverlayManager.hideOverlay();
          _activeError = AppErrorHandler.sanitize(
            reason,
            context: 'Live Dubbing',
          );
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('[TranslationState] Language switch error: $e');
      _isSwitchingLanguage = false;
      _isConnecting = false;
      _isTranslating = false;
      _isPaused = false;
      _isAutoPaused = false;
      _sessionTimer?.cancel();
      _sessionTimer = null;
      _silenceDetectionTimer?.cancel();
      _silenceDetectionTimer = null;
      _statusMessage = 'Ready to Dub';
      AudioPipelineService().stopPlayback();
      SyncDubBackendService().stopLiveDubbingSession();
      FloatingOverlayManager.hideOverlay();
      _targetLanguage = oldLang;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('targetLangCode', oldLang.code);
      } catch (_) {}
      if (_isFloatingEnabled) {
        FloatingOverlayManager.updateOverlay(
          isTranslating: false,
          isPaused: false,
          targetLang: oldLang.abbr,
          targetLangFlag: oldLang.flag,
          targetLangName: oldLang.name,
        );
      }
      _activeError = AppErrorHandler.sanitize(e, context: 'Language Switch');
      notifyListeners();
    }
  }

  /// Selects language by code (called from native floating overlay dialog)
  Future<void> setTargetLanguageByCode(String code) async {
    final clean = code.trim().toLowerCase();
    final matched = kSupportedLanguages.cast<SyncDubLanguage?>().firstWhere(
      (l) =>
          l!.code.toLowerCase() == clean ||
          l.abbr.toLowerCase() == clean ||
          l.code.toLowerCase().startsWith('$clean-') ||
          clean.startsWith('${l.code.toLowerCase()}-'),
      orElse: () => null,
    );
    if (matched == null) {
      debugPrint('[TranslationState] Unknown overlay language code: $code');
      return;
    }
    await setTargetLanguage(matched);
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

  // True while a paid purchase is waiting for the server to credit the minutes.
  bool _isAwaitingCredit = false;
  bool get isAwaitingCredit => _isAwaitingCredit;
  Timer? _creditPollTimer;

  /// Starts a RevenueCat purchase for the selected package.
  ///
  /// The app NEVER adds minutes itself. Flow: Google Play -> RevenueCat -> webhook -> server credits
  /// the profile (idempotent) -> the new balance reaches the app via realtime / polling below.
  /// Returns true when Google Play accepted the payment (minutes follow within seconds).
  Future<bool> purchaseRevenueCatPackage(Package package) async {
    triggerHaptic();

    final userId = AuthService().user?.id;
    if (userId == null) {
      _activeError = AppErrorHandler.sanitize(
        'Please sign in before buying minutes.',
        context: 'Purchase',
      );
      notifyListeners();
      return false;
    }

    final balanceBefore = _creditsRemaining ?? 0.0;
    final rc = RevenueCatService();
    final success = await rc.purchasePackage(package, appUserId: userId);
    if (success) {
      _activeError = null;
      _awaitServerCredit(balanceBefore);
      return true;
    }

    if (rc.lastErrorMessage != null) {
      _activeError = AppErrorHandler.sanitize(
        rc.lastErrorMessage!,
        context: 'RevenueCat Purchase',
      );
      notifyListeners();
    }
    return false;
  }

  /// Polls the server until the purchased minutes show up (the realtime profile stream usually
  /// delivers them first). Stops on success, sign-out, dispose, or after ~3 minutes. A late webhook
  /// is still picked up by the realtime stream and by the profile sync on app resume.
  void _awaitServerCredit(double balanceBefore) {
    _creditPollTimer?.cancel();
    _isAwaitingCredit = true;
    notifyListeners();

    var attempts = 0;
    var inFlight = false;

    void finish() {
      _creditPollTimer?.cancel();
      _creditPollTimer = null;
      _isAwaitingCredit = false;
      notifyListeners();
    }

    _creditPollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (inFlight) return;
      inFlight = true;
      attempts++;
      try {
        if (!AuthService().isAuthenticated) {
          finish();
          return;
        }
        final info = await SyncDubBackendService().fetchLiveUserPlan();
        if (info != null) {
          _setPlan(info.plan);
          _creditsRemaining = info.minutesRemaining;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble('syncdub_cached_user_credits', info.minutesRemaining);
          if (info.minutesRemaining > balanceBefore + 0.0001) {
            finish();
            return;
          }
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[TranslationState] Waiting for purchase credit failed (will retry): $e');
      } finally {
        inFlight = false;
      }
      if (attempts >= 60) {
        debugPrint('[TranslationState] Purchase credit not visible yet; realtime sync will deliver it.');
        finish();
      }
    });
  }

  Future<void> clearHistory() async {
    triggerHaptic();
    _historySessions.clear();
    notifyListeners();
    await _saveHistorySessions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _silenceDetectionTimer?.cancel();
    _sessionTimer?.cancel();
    _profileSubscription?.cancel();
    _creditPollTimer?.cancel();
    super.dispose();
  }
}
