import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

import 'auth_service.dart';
import 'audio_pipeline_service.dart';

class SyncDubBackendConfig {
  static const String supabaseUrl = 'https://gbsyzsckiarexxkcjszn.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdic3l6c2NraWFyZXh4a2Nqc3puIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI1NDI2MzksImV4cCI6MjA5ODExODYzOX0.yXNWXMpsMpCJv3pqOycTi8OFuCaipDDSQ0YM5bOI2PY';
  static const String proxyHttpUrl =
      'https://syncdub-translator-backend-1-hncr.onrender.com';
  static const String proxyWsUrl =
      'wss://syncdub-translator-backend-1-hncr.onrender.com';
  static const String fallbackWsUrl =
      'wss://syncdub-translator-backend-1-hncr.onrender.com';

  // ONE backend for the mobile app AND the Chrome extension (same host as the extension's
  // PROXY_SERVER_URL), so both use the same Supabase project, the same profiles row and the
  // same minutes balance.
  // NOTE: no shared-account credentials and no Gemini API key live in the client.
  // The Gemini key stays on the Render proxy; every user authenticates as themselves.
}

class BackendPlanInfo {
  final String plan;
  final double minutesRemaining;
  final bool isOnline;

  const BackendPlanInfo({
    required this.plan,
    required this.minutesRemaining,
    required this.isOnline,
  });
}

class SyncDubBackendService {
  static final SyncDubBackendService _instance = SyncDubBackendService._internal();
  factory SyncDubBackendService() => _instance;
  SyncDubBackendService._internal();

  String? _cachedAccessToken;
  String? get cachedAccessToken => _cachedAccessToken;
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  int _speechTurnStartTimestamp = 0;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _isPaused = false;
  bool get isPaused => _isPaused;

  bool _isManualPaused = false;
  bool get isManualPaused => _isManualPaused;
  int _sessionGeneration = 0;

  static const int _boundaryOutputSuppressMs = 350;
  int _boundaryOutputSuppressUntilMs = 0;

  /// Suppress late-arriving translated packets belonging to previous video segment / ad
  void suppressBoundaryOutput(String reason, {int durationMs = _boundaryOutputSuppressMs}) {
    final target = DateTime.now().millisecondsSinceEpoch + durationMs;
    if (target > _boundaryOutputSuppressUntilMs) {
      _boundaryOutputSuppressUntilMs = target;
    }
    debugPrint('[BoundaryAudioGuard] Suppressing translated output for ${durationMs}ms ($reason)');
  }

  /// Pause live translation stream (immediately blocks audio input and flushes playback queues)
  /// Matching Chrome extension: does not send manual activityEnd which conflicts with SyncDub AI Auto-VAD
  void pauseLiveStream({bool stopPlayback = true}) {
    _isPaused = true;
    _isManualPaused = true;
    _preAckChunks.clear(); // anything captured before the pause is stale: never send it after resume
    suppressBoundaryOutput('pause requested');
    if (stopPlayback) {
      AudioPipelineService().stopPlayback();
    } else {
      AudioPipelineService().flushPlaybackQueue();
    }
    debugPrint('[BackendService] Live stream PAUSED (audio input blocked, output dropped, queues flushed, stopPlayback=$stopPlayback)');
  }

  /// Resume live translation stream
  /// Matching Chrome extension: resumes audio chunk streaming so SyncDub AI Auto-VAD detects speech onset
  /// [guard]=true for hard boundaries (manual resume / seek): flush + drop stale output.
  /// [guard]=false for silence auto-resume: nothing stale exists, so never drop the first translated syllables.
  void resumeLiveStream({bool guard = true}) {
    _isPaused = false;
    _isManualPaused = false;
    if (guard) {
      suppressBoundaryOutput('resuming live dubbing');
      AudioPipelineService().flushPlaybackQueue();
    }
    debugPrint('[BackendService] Live stream RESUMED (audio streaming active, boundary guard engaged)');
  }

  /// Check if a JWT token has expired or is invalid
  bool isJwtExpired(String token, {Duration skew = const Duration(minutes: 2)}) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final normalized = base64Url.normalize(parts[1]);
      final payloadString = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(payloadString) as Map<String, dynamic>;
      final exp = (payload['exp'] as num?)?.toInt();
      if (exp == null) return true;
      final expDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expDate.subtract(skew));
    } catch (_) {
      return true;
    }
  }

  /// Returns the signed-in user's own JWT (refreshing it when it is about to expire).
  ///
  /// There is intentionally NO fallback to a shared account: the old fallback silently billed
  /// dubbing minutes to a shared login whenever the user's token was inside its last 2 minutes.
  Future<String?> getAccessToken({bool forceRefresh = false}) async {
    try {
      var token = await AuthService().getFreshAccessToken();
      if (AuthService().isAuthenticated &&
          (forceRefresh || token == null || token.isEmpty || isJwtExpired(token))) {
        try {
          final res = await AuthService().client.auth.refreshSession();
          token = res.session?.accessToken ?? token;
        } catch (e) {
          debugPrint('[BackendService] Token refresh failed: $e');
        }
      }
      // Hard-expired only (no skew): a token with <2 min left is still valid for this handshake.
      if (token != null && token.isNotEmpty && !isJwtExpired(token, skew: Duration.zero)) {
        _cachedAccessToken = token;
        return token;
      }
    } catch (e) {
      debugPrint('[BackendService] Auth token fetch error: $e');
    }
    _cachedAccessToken = null;
    return null;
  }

  /// Query live user plan and remaining translation credits from Render proxy
  Future<BackendPlanInfo?> fetchLiveUserPlan() async {
    try {
      final token = await getAccessToken();
      if (token == null) return null;

      final url = Uri.parse('${SyncDubBackendConfig.proxyHttpUrl}/api/user-plan');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final minutes = (data['minutes'] as num?)?.toDouble();
        if (minutes == null) return null; // never show an invented balance
        final plan = data['plan']?.toString() ?? 'free';
        return BackendPlanInfo(
          plan: plan,
          minutesRemaining: minutes,
          isOnline: true,
        );
      }
    } catch (e) {
      debugPrint('[BackendService] fetchLiveUserPlan error: $e');
    }
    return null;
  }

  /// Real-time health check on the Render Proxy Server
  Future<Map<String, dynamic>> checkBackendHealth() async {
    try {
      final stopwatch = Stopwatch()..start();
      final url = Uri.parse('${SyncDubBackendConfig.proxyHttpUrl}/');
      final res = await http.get(url).timeout(const Duration(seconds: 25));
      stopwatch.stop();
      final isHealthy = res.statusCode == 200 &&
          (res.body.contains('healthy') || res.body.contains('SyncDub Proxy Server'));
      debugPrint('[BackendService] Health check result: isHealthy=$isHealthy, time=${stopwatch.elapsedMilliseconds}ms');
      return {
        'isHealthy': isHealthy,
        'latencyMs': stopwatch.elapsedMilliseconds,
        'message': isHealthy ? 'Engine Online · Healthy' : 'Engine Degraded',
      };
    } catch (e) {
      debugPrint('[BackendService] Health check failed: $e');
      return {
        'isHealthy': false,
        'latencyMs': 0,
        'message': 'Offline / Connecting...',
      };
    }
  }

  bool _setupAckReceived = false;
  bool get isSetupComplete => _setupAckReceived;

  // ---- First-token timing (printed once per session as one "[Latency]" log line) ----
  final Stopwatch _sessionClock = Stopwatch();
  int _tWsReadyMs = -1;
  int _tSetupAckMs = -1;
  int _tCaptureMs = -1;
  bool _firstAudioLogged = false;

  /// Tear the session down and report it - used when audio capture cannot start.
  Future<void> _failSession(
    int gen,
    String message,
    void Function(String errorReason) onDisconnected,
  ) async {
    if (gen != _sessionGeneration) return; // already stopped / replaced
    await stopLiveDubbingSession();
    onDisconnected(message);
  }

  /// Stream a raw 16kHz PCM audio chunk to SyncDub AI Live Translate over WebSocket
  // Audio captured while the cloud handshake is still in flight (capture starts in parallel with it).
  final List<String> _preAckChunks = [];
  static const int _maxPreAckChunks = 12; // ~480ms of 40ms frames
  int _lastDubbedOutputMs = 0;

  void sendAudioChunk(String base64Pcm) {
    if (_isPaused || base64Pcm.isEmpty) return;
    if (_isConnected && !_setupAckReceived) {
      _preAckChunks.add(base64Pcm);
      if (_preAckChunks.length > _maxPreAckChunks) _preAckChunks.removeAt(0);
      return;
    }
    if (_isConnected && _setupAckReceived && _wsChannel != null) {
      try {
        // Latency clock starts at a real speech onset (after a quiet gap), not at the first silent frame
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (_speechTurnStartTimestamp == 0 &&
            nowMs - _lastDubbedOutputMs > 1000 &&
            AudioPipelineService().micAmplitude.value > 0.02) {
          _speechTurnStartTimestamp = nowMs;
        }
        final mediaMsg = jsonEncode({
          'realtimeInput': {
            'audio': {
              'mimeType': 'audio/pcm;rate=16000',
              'data': base64Pcm,
            }
          }
        });
        _wsChannel!.sink.add(mediaMsg);
      } catch (e) {
        debugPrint('[BackendService] sendAudioChunk error: $e');
      }
    }
  }

  Timer? _handshakeTimeoutTimer;
  String? _lastServerReportReason;

  /// Start live real-time bidirectional translation stream via WebSocket
  Future<void> startLiveDubbingSession({
    required String targetLanguageCode,
    String captureMode = 'internal',
    // When set, the network handshake starts immediately while this future is still pending (e.g. the
    // Android screen-capture permission dialog). Capture starts only once it resolves to a mode; a null
    // result means the user declined and the half-open session is torn down quietly.
    Future<String?>? captureModeFuture,
    bool preserveNativeCapture = false,
    required void Function(double credits, String plan) onCreditsUpdate,
    required void Function(int latencyMs) onLatencyUpdate,
    required void Function(String status) onStatusChange,
    required void Function(String errorReason) onDisconnected,
  }) async {
    await stopLiveDubbingSession(preserveNativeCapture: preserveNativeCapture);
    final gen = ++_sessionGeneration;
    _setupAckReceived = false;
    _lastServerReportReason = null;
    _sessionClock
      ..reset()
      ..start();
    _tWsReadyMs = -1;
    _tSetupAckMs = -1;
    _tCaptureMs = -1;
    _firstAudioLogged = false;

    // With a pending capture permission the UI must not say "Live" until capture can really start,
    // even if the server's setupComplete wins the race against the user's tap on "Allow".
    final deferred = captureModeFuture != null;
    var captureReady = !deferred;
    var activeAnnounced = false;
    void announceActive() {
      if (activeAnnounced || gen != _sessionGeneration) return;
      activeAnnounced = true;
      onStatusChange('Live Dubbing Active');
    }

    try {
      onStatusChange('Connecting to SyncDub AI Engine...');

      // 1. Acquire the signed-in user's own access token (no shared-account fallback)
      var token = await getAccessToken();
      token ??= await getAccessToken(forceRefresh: true);
      if (token == null || token.isEmpty) {
        onDisconnected('Authentication token expired. Please re-authenticate.');
        return;
      }
      final String authToken = token;

      onStatusChange('Connecting to Cloud Pipeline...');

      // Fire-and-forget background health check — do NOT block WS connection for warm servers
      // This saves 300ms-2s on every session start when Render server is already warm
      checkBackendHealth().then((health) {
        debugPrint('[BackendService] Background health check: ${health['message']}');
      }).catchError((_) {});
      WebSocketChannel? channel;
      final wsUri = Uri.parse(SyncDubBackendConfig.proxyWsUrl);
      // Protocol-level pings stop NAT / Render's proxy from silently dropping the socket while
      // dubbing is paused (no audio frames are sent during silence auto-pause).
      const wsPing = Duration(seconds: 20);
      try {
        channel = IOWebSocketChannel.connect(wsUri, pingInterval: wsPing);
        await channel.ready.timeout(const Duration(seconds: 40));
      } catch (e) {
        debugPrint('[BackendService] Primary WS connection attempt failed: $e, retrying once...');
        try {
          channel?.sink.close(); // do not leak the half-open first attempt
        } catch (_) {}
        if (gen != _sessionGeneration) return; // user pressed Stop while connecting
        onStatusChange('Reconnecting to AI Cloud Engine...');
        await Future.delayed(const Duration(milliseconds: 300));
        if (gen != _sessionGeneration) return;
        channel = IOWebSocketChannel.connect(wsUri, pingInterval: wsPing);
        await channel.ready.timeout(const Duration(seconds: 45));
      }

      if (gen != _sessionGeneration) {
        try {
          channel.sink.close();
        } catch (_) {}
        return;
      }

      _wsChannel = channel;
      _isConnected = true;
      _tWsReadyMs = _sessionClock.elapsedMilliseconds;

      // 3. Attach stream listener FIRST before sending any data frames
      _wsSubscription = _wsChannel!.stream.listen(
        (dynamic data) async {
          try {
            final String text;
            if (data is String) {
              text = data;
            } else if (data is List<int>) {
              text = utf8.decode(data, allowMalformed: true);
            } else {
              text = data.toString();
            }

            final decoded = jsonDecode(text);
            final List<Map<String, dynamic>> messages = [];
            if (decoded is List) {
              for (final item in decoded) {
                if (item is Map<String, dynamic>) {
                  messages.add(item);
                } else if (item is Map) {
                  messages.add(Map<String, dynamic>.from(item));
                }
              }
            } else if (decoded is Map<String, dynamic>) {
              messages.add(decoded);
            } else if (decoded is Map) {
              messages.add(Map<String, dynamic>.from(decoded));
            }

            for (final parsed in messages) {
              // Server error frame capture
              if (parsed.containsKey('error')) {
                final errObj = parsed['error'];
                if (errObj is Map && errObj.containsKey('message')) {
                  _lastServerReportReason = errObj['message']?.toString();
                } else {
                  _lastServerReportReason = errObj?.toString();
                }
                debugPrint('[BackendService] Server error message captured: $_lastServerReportReason');
              }

              // Server diagnostics report frame capture
              if (parsed['action'] == 'serverCloseInfo') {
                final report = parsed['report'] as Map<String, dynamic>?;
                final reason = report?['reason']?.toString();
                if (reason != null && reason.isNotEmpty) {
                  _lastServerReportReason = reason;
                }
                debugPrint('[BackendService] Server close diagnostics captured: $_lastServerReportReason');
              }

              // Credits Update - update accounting only; do not overwrite live/paused status
              if (parsed['action'] == 'creditsUpdate') {
                final credits = (parsed['credits'] as num?)?.toDouble();
                if (credits != null) {
                  onCreditsUpdate(credits, parsed['plan']?.toString() ?? '');
                }
              }

              // Setup ACK: Check if setupComplete exists
              if (parsed.containsKey('setupComplete') && !_setupAckReceived) {
                if (gen != _sessionGeneration) {
                  return;
                }
                _setupAckReceived = true;
                _tSetupAckMs = _sessionClock.elapsedMilliseconds;
                _handshakeTimeoutTimer?.cancel();
                _handshakeTimeoutTimer = null;
                if (captureReady) announceActive();
                debugPrint('[BackendService] SetupComplete received from SyncDub AI. Activating audio capture pipeline...');
                // Capture already runs (started before handshake). Flush the pre-ACK audio, then stream live.
                AudioPipelineService().onAudioChunkCaptured = sendAudioChunk;
                final pending = List<String>.from(_preAckChunks);
                _preAckChunks.clear();
                for (final c in pending) {
                  sendAudioChunk(c);
                }
                // Deferred sessions start capture from the permission continuation below instead.
                if (!deferred) {
                  final captureOk = await AudioPipelineService().startAudioCapture(mode: captureMode);
                  if (!captureOk) {
                    unawaited(_failSession(
                      gen,
                      'Audio capture could not start. Please allow screen/microphone audio access and tap Start again.',
                      onDisconnected,
                    ));
                  }
                }
              }

              // Dubbed audio handling (no transcripts are requested: they only add latency)
              if (parsed.containsKey('serverContent')) {
                final serverContent = parsed['serverContent'] as Map<String, dynamic>?;
                final modelTurn = serverContent?['modelTurn'] as Map<String, dynamic>?;
                final parts = modelTurn?['parts'] as List<dynamic>?;

                if (parts != null) {
                  for (final part in parts) {
                    if (part is Map<String, dynamic>) {
                      // Audio PCM playback
                      if (part.containsKey('inlineData')) {
                        final inlineData = part['inlineData'] as Map<String, dynamic>?;
                        final audioData = inlineData?['data']?.toString();
                        if (!_isPaused && !_isManualPaused && audioData != null && audioData.isNotEmpty) {
                          final nowMs = DateTime.now().millisecondsSinceEpoch;
                          if (_boundaryOutputSuppressUntilMs > nowMs) {
                            debugPrint('[BoundaryAudioGuard] Discarded stale audio chunk arriving ${_boundaryOutputSuppressUntilMs - nowMs}ms inside boundary suppression window');
                            continue;
                          }
                          if (_speechTurnStartTimestamp > 0) {
                            final latency = nowMs - _speechTurnStartTimestamp;
                            if (latency > 0 && latency < 20000) onLatencyUpdate(latency);
                            _speechTurnStartTimestamp = 0;
                          }
                          _lastDubbedOutputMs = nowMs;
                          if (!_firstAudioLogged) {
                            _firstAudioLogged = true;
                            // Timeline from the start of the connect. With the permission dialog running in parallel,
                            // "capture ready" is when the user tapped Allow; the real wait after that moment is the last number.
                            final tFirst = _sessionClock.elapsedMilliseconds;
                            final sinceCapture = _tCaptureMs >= 0 ? tFirst - _tCaptureMs : -1;
                            debugPrint('[Latency] connect -> websocket ready ${_tWsReadyMs}ms | -> setupComplete ${_tSetupAckMs}ms | -> capture ready ${_tCaptureMs}ms | -> first dubbed audio ${tFirst}ms (${sinceCapture}ms after capture start)');
                          }
                          AudioPipelineService().playDubbedPcm(audioData, sampleRate: 24000);
                        } else if (_isPaused || _isManualPaused) {
                          debugPrint('[BackendService] Dropped incoming serverContent PCM chunk while paused');
                        }
                      }
                    }
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('[BackendService] WS message parse error: $e');
          }
        },
        onError: (err) {
          // Stale session (stopped / language-switched) or already reported by onDone
          if (gen != _sessionGeneration) return;
          _sessionGeneration++;
          _handshakeTimeoutTimer?.cancel();
          _handshakeTimeoutTimer = null;
          debugPrint('[BackendService] WS error: $err');
          _isConnected = false;
          _setupAckReceived = false;
          _wsChannel = null;
          // The socket is gone: release native capture + playback instead of leaking them
          unawaited(AudioPipelineService().stopMicCapture());
          unawaited(AudioPipelineService().stopPlayback());
          onDisconnected('Connection error: $err');
        },
        onDone: () {
          if (gen != _sessionGeneration) return;
          _sessionGeneration++;
          _handshakeTimeoutTimer?.cancel();
          _handshakeTimeoutTimer = null;
          final code = channel?.closeCode;
          final reason = channel?.closeReason;
          debugPrint('[BackendService] WS stream closed (code=$code, reason=$reason, lastReport=$_lastServerReportReason)');
          _isConnected = false;
          _setupAckReceived = false;
          _wsChannel = null;
          unawaited(AudioPipelineService().stopMicCapture());
          unawaited(AudioPipelineService().stopPlayback());

          String userMessage = _lastServerReportReason ?? 'Connection closed';
          if (code == 1013) {
            userMessage = 'Previous session is clearing on cloud server. Please tap Start to reconnect.';
          } else if (code == 4001) {
            userMessage = 'Authentication timeout with cloud server. Please tap Start to retry.';
          } else if (code == 4002) {
            userMessage = 'Insufficient translation credits remaining. Please upgrade your plan.';
          } else if (code == 4003) {
            userMessage = 'Authentication token expired. Please re-authenticate.';
          } else if (code == 4500) {
            userMessage = reason != null && reason.isNotEmpty
                ? 'Server error: $reason'
                : 'AI Translation engine temporarily unavailable. Please retry in a few seconds.';
          } else if (reason != null && reason.isNotEmpty) {
            userMessage = reason;
          }
          onDisconnected(userMessage);
        },
      );

      // 4. Normalize language code for SyncDub AI Live Translate (matching Chrome extension BCP47_MAP & BCP47_OVERRIDES)
      String cleanLangCode = targetLanguageCode.trim();
      if (cleanLangCode.toLowerCase() == 'zh-cn') {
        cleanLangCode = 'zh-Hans';
      } else if (cleanLangCode.toLowerCase() == 'zh-tw') {
        cleanLangCode = 'zh-Hant';
      } else if (cleanLangCode.toLowerCase() == 'ar-xm') {
        cleanLangCode = 'ar';
      } else if (!cleanLangCode.toLowerCase().startsWith('zh-')) {
        cleanLangCode = cleanLangCode.split('-').first.toLowerCase();
      }

      // Start native capture NOW, in parallel with the auth/setup handshake (saves 100-300ms to first token).
      // Frames captured before setupComplete are buffered (max ~480ms) and flushed on ACK.
      // With a pending permission (captureModeFuture) the handshake above already runs while the system
      // dialog is open; capture begins the moment the user allows it.
      _preAckChunks.clear();
      AudioPipelineService().onAudioChunkCaptured = sendAudioChunk;
      unawaited(() async {
        var mode = captureMode;
        if (captureModeFuture != null) {
          String? resolved;
          try {
            resolved = await captureModeFuture;
          } catch (_) {
            resolved = null;
          }
          if (gen != _sessionGeneration) return; // stopped / failed while the dialog was open
          if (resolved == null) {
            // Permission declined: the caller already reset the UI, just drop the half-open session.
            await stopLiveDubbingSession();
            return;
          }
          mode = resolved;
        }
        final ok = await AudioPipelineService().startAudioCapture(mode: mode);
        if (gen != _sessionGeneration) return;
        if (!ok) {
          unawaited(_failSession(
            gen,
            'Audio capture could not start. Please allow screen/microphone audio access and tap Start again.',
            onDisconnected,
          ));
          return;
        }
        captureReady = true;
        _tCaptureMs = _sessionClock.elapsedMilliseconds;
        if (_setupAckReceived) announceActive();
      }());

      // Send authentication frame
      onStatusChange('Authenticating with SyncDub...');
      final authMsg = jsonEncode({
        'action': 'authenticate',
        'token': authToken,
        'targetLang': cleanLangCode,
      });
      _wsChannel!.sink.add(authMsg);

      // 5. Send setup frame for SyncDub AI Live Translate (matching Chrome extension offscreen.js lines 2013-2057)
      onStatusChange('Synchronizing AI Pipeline...');
      final setupMsg = jsonEncode({
        'setup': {
          'model': 'models/gemini-3.5-live-translate-preview',
          'generation_config': {
            'response_modalities': ['AUDIO'],
            'translation_config': {
              'target_language_code': cleanLangCode,
              'echo_target_language': true,
            },
          },
          'realtime_input_config': {
            'automatic_activity_detection': {
              'disabled': false,
              'start_of_speech_sensitivity': 'START_SENSITIVITY_HIGH',
              'end_of_speech_sensitivity': 'END_SENSITIVITY_HIGH',
              'prefix_padding_ms': 20,
              'silence_duration_ms': 300,
            },
          },
        },
      });
      _wsChannel!.sink.add(setupMsg);

      // 6. Arm handshake watchdog timer (45 seconds for cloud cold-starts)
      _handshakeTimeoutTimer?.cancel();
      _handshakeTimeoutTimer = Timer(const Duration(seconds: 45), () {
        if (!_setupAckReceived && _isConnected) {
          debugPrint('[BackendService] Handshake watchdog triggered: setupComplete not received within 45s');
          stopLiveDubbingSession();
          onDisconnected('Cloud AI Engine took too long to initialize. Please tap Start to retry.');
        }
      });

    } catch (e) {
      _handshakeTimeoutTimer?.cancel();
      _handshakeTimeoutTimer = null;
      debugPrint('[BackendService] Live dubbing connection error: $e');
      _isConnected = false;
      onDisconnected('Unable to reach SyncDub server: $e');
    }
  }

  /// Real-time live language switch during an active translation session.
  /// Kills the existing SyncDub AI WebSocket session cleanly and reconnects immediately
  /// with the new target language, while keeping native audio capture alive.
  Future<void> switchTargetLanguage({
    required String newTargetLanguageCode,
    String captureMode = 'internal',
    required void Function(double credits, String plan) onCreditsUpdate,
    required void Function(int latencyMs) onLatencyUpdate,
    required void Function(String status) onStatusChange,
    required void Function(String errorReason) onDisconnected,
  }) async {
    debugPrint('[BackendService] Seamlessly switching target language to: $newTargetLanguageCode');
    final gen = ++_sessionGeneration;

    onStatusChange('Disconnecting & Reconnecting to AI Engine...');

    // 1. Temporarily detach audio chunk forwarding and stop old language playback
    AudioPipelineService().onAudioChunkCaptured = null;
    AudioPipelineService().stopPlayback();

    // 2. Safely stop existing WebSocket session while preserving native capture
    await stopLiveDubbingSession(preserveNativeCapture: true);

    // 3. Grace delay for cloud proxy to recycle connection
    await Future.delayed(const Duration(milliseconds: 250));
    if (gen != _sessionGeneration) return;

    // 4. Connect new session with new language code, preserving native capture
    await startLiveDubbingSession(
      targetLanguageCode: newTargetLanguageCode,
      captureMode: captureMode,
      preserveNativeCapture: true,
      onCreditsUpdate: onCreditsUpdate,
      onLatencyUpdate: onLatencyUpdate,
      onStatusChange: onStatusChange,
      onDisconnected: onDisconnected,
    );
  }

  /// Safely stop live streaming, mic capture, and audio playback
  Future<void> stopLiveDubbingSession({bool preserveNativeCapture = false}) async {
    if (!preserveNativeCapture) {
      _isPaused = false;
      _isManualPaused = false;
      _sessionGeneration++;
    }
    _handshakeTimeoutTimer?.cancel();
    _handshakeTimeoutTimer = null;
    _speechTurnStartTimestamp = 0;
    _preAckChunks.clear();

    await _wsSubscription?.cancel();
    _wsSubscription = null;

    try {
      _wsChannel?.sink.close(status.normalClosure);
    } catch (_) {}
    _wsChannel = null;
    _isConnected = false;
    _setupAckReceived = false;

    // Stop native audio pipeline only if not preserving for real-time language switch
    if (!preserveNativeCapture) {
      await AudioPipelineService().stopMicCapture();
    }
    await AudioPipelineService().stopPlayback();
  }

  /// Creates a standard canonical 44-byte RIFF WAVE header for 16-bit PCM audio
  static Uint8List createWavHeader({
    required int pcmDataLength,
    int sampleRate = 24000,
    int numChannels = 1,
    int bitsPerSample = 16,
  }) {
    final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final blockAlign = numChannels * (bitsPerSample ~/ 8);
    final fileSize = 36 + pcmDataLength;

    final header = Uint8List(44);
    final bdata = ByteData.view(header.buffer);

    // "RIFF"
    header[0] = 0x52; header[1] = 0x49; header[2] = 0x46; header[3] = 0x46;
    // File size - 8
    bdata.setUint32(4, fileSize, Endian.little);
    // "WAVE"
    header[8] = 0x57; header[9] = 0x41; header[10] = 0x56; header[11] = 0x45;
    // "fmt "
    header[12] = 0x66; header[13] = 0x6D; header[14] = 0x74; header[15] = 0x20;
    // Subchunk1Size = 16
    bdata.setUint32(16, 16, Endian.little);
    // AudioFormat = 1 (PCM)
    bdata.setUint16(20, 1, Endian.little);
    // NumChannels = 1
    bdata.setUint16(22, numChannels, Endian.little);
    // SampleRate = 24000
    bdata.setUint32(24, sampleRate, Endian.little);
    // ByteRate = 48000
    bdata.setUint32(28, byteRate, Endian.little);
    // BlockAlign = 2
    bdata.setUint16(32, blockAlign, Endian.little);
    // BitsPerSample = 16
    bdata.setUint16(34, bitsPerSample, Endian.little);
    // "data"
    header[36] = 0x64; header[37] = 0x61; header[38] = 0x74; header[39] = 0x61;
    // Subchunk2Size = pcmDataLength
    bdata.setUint32(40, pcmDataLength, Endian.little);

    return header;
  }
}
