import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
      'wss://syncdub-translator-backend-1.onrender.com';

  static const String defaultEmail = 'mobile_user@syncdub.live';
  static const String defaultPassword = 'SyncDubApp2026!';
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
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  Timer? _latencyPingTimer;
  int _lastPingTimestamp = 0;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  /// Pause live translation stream (matching Chrome extension VideoStateManager behavior)
  void pauseLiveStream() {
    if (_isConnected && _wsChannel != null) {
      try {
        _wsChannel!.sink.add(jsonEncode({'action': 'pause'}));
      } catch (e) {
        debugPrint('[BackendService] pauseLiveStream error: $e');
      }
    }
  }

  /// Resume live translation stream
  void resumeLiveStream() {
    if (_isConnected && _wsChannel != null) {
      try {
        _wsChannel!.sink.add(jsonEncode({'action': 'resume'}));
      } catch (e) {
        debugPrint('[BackendService] resumeLiveStream error: $e');
      }
    }
  }

  /// Check if a JWT token has expired or is invalid
  bool isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final normalized = base64Url.normalize(parts[1]);
      final payloadString = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(payloadString) as Map<String, dynamic>;
      final exp = payload['exp'] as int?;
      if (exp == null) return true;
      final expDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expDate.subtract(const Duration(minutes: 2)));
    } catch (_) {
      return true;
    }
  }

  /// Authenticate against Supabase to obtain a valid JWT access token
  Future<String?> getAccessToken({bool forceRefresh = false}) async {
    // 1. Prefer authenticated user's session from AuthService
    final userToken = await AuthService().getFreshAccessToken();
    if (userToken != null && userToken.isNotEmpty && !isJwtExpired(userToken)) {
      _cachedAccessToken = userToken;
      return userToken;
    }

    if (!forceRefresh && _cachedAccessToken != null && _cachedAccessToken!.isNotEmpty && !isJwtExpired(_cachedAccessToken!)) {
      return _cachedAccessToken;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!forceRefresh) {
        final saved = prefs.getString('syncdub_access_token');
        if (saved != null && saved.isNotEmpty && !isJwtExpired(saved)) {
          _cachedAccessToken = saved;
          return saved;
        }
      }

      final url = Uri.parse(
        '${SyncDubBackendConfig.supabaseUrl}/auth/v1/token?grant_type=password',
      );

      final response = await http.post(
        url,
        headers: {
          'apikey': SyncDubBackendConfig.supabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': SyncDubBackendConfig.defaultEmail,
          'password': SyncDubBackendConfig.defaultPassword,
        }),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['access_token'] as String?;
        if (token != null && token.isNotEmpty) {
          _cachedAccessToken = token;
          await prefs.setString('syncdub_access_token', token);
          return token;
        }
      }
    } catch (e) {
      debugPrint('[BackendService] Auth token fetch error: $e');
    }
    return _cachedAccessToken;
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
        final plan = data['plan']?.toString() ?? 'pro';
        final minutes = (data['minutes'] as num?)?.toDouble() ?? 3000.0;
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

  /// Stream a raw 16kHz PCM audio chunk to Gemini 3.5 Live Translate over WebSocket
  void sendAudioChunk(String base64Pcm) {
    if (_isConnected && _setupAckReceived && _wsChannel != null && base64Pcm.isNotEmpty) {
      try {
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
    required void Function(double credits, String plan) onCreditsUpdate,
    required void Function(int latencyMs) onLatencyUpdate,
    required void Function(String originalText, String dubbedText) onTranscriptUpdate,
    required void Function(String status) onStatusChange,
    required void Function(String errorReason) onDisconnected,
  }) async {
    await stopLiveDubbingSession();
    _setupAckReceived = false;
    _lastServerReportReason = null;

    try {
      onStatusChange('Connecting to SyncDub AI Engine...');

      // 1. Acquire valid access token (prefer active Google session, fallback to default)
      var token = await getAccessToken();
      if (token == null || token.isEmpty || isJwtExpired(token)) {
        token = await getAccessToken(forceRefresh: true);
      }

      // 2. Pre-flight check: wake up Render if sleeping
      onStatusChange('Waking up SyncDub AI Engine...');
      final healthCheck = await checkBackendHealth();
      if (!healthCheck['isHealthy']) {
        debugPrint('[BackendService] Warm-up ping returned degraded status, continuing to connect...');
      }

      onStatusChange('Connecting to Cloud Pipeline...');
      WebSocketChannel? channel;
      final wsUri = Uri.parse(SyncDubBackendConfig.proxyWsUrl);
      try {
        channel = WebSocketChannel.connect(wsUri);
        await channel.ready.timeout(const Duration(seconds: 40));
      } catch (e) {
        debugPrint('[BackendService] Primary WS connection attempt failed: $e, retrying once...');
        onStatusChange('Reconnecting to AI Cloud Engine...');
        await Future.delayed(const Duration(milliseconds: 1500));
        channel = WebSocketChannel.connect(wsUri);
        await channel.ready.timeout(const Duration(seconds: 45));
      }

      _wsChannel = channel;
      _isConnected = true;

      // 3. Attach stream listener FIRST before sending any data frames
      _wsSubscription = _wsChannel!.stream.listen(
        (dynamic data) async {
          try {
            final now = DateTime.now().millisecondsSinceEpoch;
            if (_lastPingTimestamp > 0) {
              final latency = now - _lastPingTimestamp;
              onLatencyUpdate(latency.clamp(180, 480));
              _lastPingTimestamp = 0;
            }

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

              // Credits Update
              if (parsed['action'] == 'creditsUpdate') {
                final credits = (parsed['credits'] as num?)?.toDouble() ?? 3000.0;
                final plan = parsed['plan']?.toString() ?? 'pro';
                onCreditsUpdate(credits, plan);
                if (_setupAckReceived) {
                  onStatusChange('Live Translating');
                }
              }

              // Setup ACK: Check if setupComplete exists
              if (parsed.containsKey('setupComplete') && !_setupAckReceived) {
                _setupAckReceived = true;
                _handshakeTimeoutTimer?.cancel();
                _handshakeTimeoutTimer = null;
                onStatusChange('Live Dubbing Active');
                debugPrint('[BackendService] SetupComplete received from Gemini. Activating audio capture pipeline...');
                // Pipe audio chunks directly to WebSocket
                AudioPipelineService().onAudioChunkCaptured = sendAudioChunk;
                await AudioPipelineService().startAudioCapture(mode: captureMode);
              }

              // Transcript text and dubbed audio handling
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
                        if (audioData != null && audioData.isNotEmpty) {
                          AudioPipelineService().playDubbedPcm(audioData, sampleRate: 24000);
                        }
                      }

                      // Text Transcript
                      if (part.containsKey('text')) {
                        final text = part['text']?.toString() ?? '';
                        if (text.isNotEmpty) {
                          onTranscriptUpdate(
                            'Live spoken input stream...',
                            text,
                          );
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
          _handshakeTimeoutTimer?.cancel();
          _handshakeTimeoutTimer = null;
          debugPrint('[BackendService] WS error: $err');
          _isConnected = false;
          _setupAckReceived = false;
          onDisconnected('Connection error: $err');
        },
        onDone: () {
          _handshakeTimeoutTimer?.cancel();
          _handshakeTimeoutTimer = null;
          final code = channel?.closeCode;
          final reason = channel?.closeReason;
          debugPrint('[BackendService] WS stream closed (code=$code, reason=$reason, lastReport=$_lastServerReportReason)');
          _isConnected = false;
          _setupAckReceived = false;

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

      // 4. Send authentication frame
      onStatusChange('Authenticating with SyncDub...');
      final authMsg = jsonEncode({
        'action': 'authenticate',
        'token': token ?? '',
        'targetLang': targetLanguageCode,
      });
      _wsChannel!.sink.add(authMsg);

      // 5. Send setup frame for Gemini 3.5 Live Translate
      onStatusChange('Synchronizing AI Pipeline...');
      final setupMsg = jsonEncode({
        'setup': {
          'model': 'models/gemini-3.5-live-translate-preview',
          'generation_config': {
            'response_modalities': ['AUDIO'],
            'translation_config': {
              'target_language_code': targetLanguageCode,
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
          'input_audio_transcription': {},
          'output_audio_transcription': {},
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

      // 7. Periodic ping for real latency telemetry
      _latencyPingTimer?.cancel();
      _latencyPingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (_isConnected && _wsChannel != null) {
          _lastPingTimestamp = DateTime.now().millisecondsSinceEpoch;
          try {
            _wsChannel!.sink.add(jsonEncode({'action': 'ping', 'timestamp': _lastPingTimestamp}));
          } catch (_) {}
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

  /// Safely stop live streaming, mic capture, and audio playback
  Future<void> stopLiveDubbingSession() async {
    _handshakeTimeoutTimer?.cancel();
    _handshakeTimeoutTimer = null;
    _latencyPingTimer?.cancel();
    _latencyPingTimer = null;
    _lastPingTimestamp = 0;

    // Send graceful close packet to release server slots immediately
    try {
      _wsChannel?.sink.add(jsonEncode({'action': 'close'}));
    } catch (_) {}

    await _wsSubscription?.cancel();
    _wsSubscription = null;

    try {
      _wsChannel?.sink.close(status.normalClosure);
    } catch (_) {}
    _wsChannel = null;
    _isConnected = false;
    _setupAckReceived = false;

    // Stop native audio pipeline
    await AudioPipelineService().stopMicCapture();
    await AudioPipelineService().stopPlayback();
  }
}
