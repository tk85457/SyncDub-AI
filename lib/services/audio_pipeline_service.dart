import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Real-time Sound Transmission & Playback Pipeline Service
///
/// Bridges native Android AudioRecord (16kHz PCM 16-bit mono) and AudioTrack (24kHz low-latency speech playback)
/// with the SyncDub AI WebSocket backend.
class AudioPipelineService {
  static final AudioPipelineService _instance = AudioPipelineService._internal();
  factory AudioPipelineService() => _instance;

  /// Callback invoked when Android system stops MediaProjection or user cancels
  VoidCallback? onMediaProjectionStopped;

  /// Called the moment another app's media playback (YouTube, Reels, ...) really starts (true) or stops (false).
  /// Native side debounces ~300ms and never reports "stopped" before it has seen "started" in the session.
  void Function(bool active)? onExternalPlaybackChanged;

  AudioPipelineService._internal() {
    _methodChannel.setMethodCallHandler((call) async {
      if (call.method == 'onMediaProjectionStopped') {
        debugPrint('[AudioPipeline] Native MediaProjection stopped notification received');
        onMediaProjectionStopped?.call();
      } else if (call.method == 'onExternalPlaybackChanged') {
        final args = call.arguments;
        final active = args is Map && args['active'] == true;
        onExternalPlaybackChanged?.call(active);
      }
    });
  }

  static const MethodChannel _methodChannel =
      MethodChannel('com.syncdub.livedub/audio_pipeline');
  static const EventChannel _eventChannel =
      EventChannel('com.syncdub.livedub/mic_stream');

  StreamSubscription? _micStreamSubscription;
  bool _isCapturing = false;
  bool get isCapturing => _isCapturing;

  /// Current real-time microphone RMS amplitude (0.0 to 1.0)
  final ValueNotifier<double> micAmplitude = ValueNotifier<double>(0.0);

  /// Callback invoked when a 16kHz PCM audio chunk is captured
  void Function(String base64Chunk)? onAudioChunkCaptured;

  String _activeCaptureMode = 'internal';
  String get activeCaptureMode => _activeCaptureMode;

  /// Notifier for real-time capture mode ('internal' for YouTube/videos or 'mic')
  final ValueNotifier<String> captureModeNotifier = ValueNotifier<String>('internal');

  /// Request Android system internal audio playback capture permission (MediaProjection dialog)
  /// Returns 'granted', 'user_cancelled', or 'not_supported'
  Future<String> requestInternalAudioPermission() async {
    try {
      final res = await _methodChannel.invokeMethod<dynamic>('requestInternalAudioPermission');
      if (res is bool) {
        return res ? 'granted' : 'not_supported';
      }
      return res?.toString() ?? 'not_supported';
    } catch (e) {
      debugPrint('[AudioPipeline] requestInternalAudioPermission error: $e');
      return 'not_supported';
    }
  }

  Future<bool>? _startFuture;
  int _captureGen = 0;

  /// Start capturing audio (mode: "internal" for direct YouTube/video stream, or "mic").
  ///
  /// Concurrent callers share ONE in-flight start. Previously a second call re-subscribed the
  /// EventChannel (cancel + listen), and the native onCancel() stops the AudioRecord, so capture
  /// could die silently while Dart still believed it was running.
  Future<bool> startAudioCapture({String mode = 'internal'}) {
    if (_isCapturing) return Future<bool>.value(true);
    final inFlight = _startFuture;
    if (inFlight != null) return inFlight;
    final f = _startAudioCaptureInternal(mode);
    _startFuture = f;
    f.whenComplete(() {
      if (identical(_startFuture, f)) _startFuture = null;
    });
    return f;
  }

  Future<bool> _startAudioCaptureInternal(String mode) async {
    final gen = _captureGen;
    try {
      // Attach the listener BEFORE native capture starts so the first frames are not dropped.
      _micStreamSubscription ??= _eventChannel.receiveBroadcastStream().listen(
        _handleCaptureEvent,
        onError: (dynamic error) {
          debugPrint('[AudioPipeline] Audio capture stream error: $error');
        },
        onDone: () {
          _isCapturing = false;
          micAmplitude.value = 0.0;
        },
      );

      final res = await _methodChannel.invokeMethod<Map>('startAudioCapture', {'mode': mode});
      final bool started = res?['started'] == true;
      _activeCaptureMode = res?['mode']?.toString() ?? mode;
      captureModeNotifier.value = _activeCaptureMode;

      if (gen != _captureGen) {
        // stopMicCapture() ran while the native start was still in flight - undo it.
        if (started) {
          try {
            await _methodChannel.invokeMethod('stopMicCapture');
          } catch (_) {}
        }
        return false;
      }
      if (started) {
        _isCapturing = true;
        return true;
      }
      debugPrint('[AudioPipeline] Native capture did not start: ${res?['error']}');
    } catch (e) {
      debugPrint('[AudioPipeline] startAudioCapture exception: $e');
    }
    // Start failed: release the listener so a later retry begins from a clean state.
    final sub = _micStreamSubscription;
    _micStreamSubscription = null;
    await sub?.cancel();
    return false;
  }

  void _handleCaptureEvent(dynamic event) {
    if (event is! Map) return;
    final base64Pcm = event['pcm']?.toString();
    final amp = (event['amp'] as num?)?.toDouble() ?? 0.0;
    final currentMode = event['mode']?.toString();
    if (currentMode != null && currentMode != _activeCaptureMode) {
      _activeCaptureMode = currentMode;
      captureModeNotifier.value = currentMode;
    }

    // Update amplitude for UI waveform reactions
    micAmplitude.value = amp;

    // Dispatch audio chunk to backend WebSocket
    if (base64Pcm != null && base64Pcm.isNotEmpty) {
      onAudioChunkCaptured?.call(base64Pcm);
    }
  }

  /// Legacy alias: Start capturing audio (defaults to internal video stream)
  Future<bool> startMicCapture() => startAudioCapture(mode: 'internal');

  /// Stop capturing microphone audio
  Future<void> stopMicCapture() async {
    _captureGen++;
    _isCapturing = false;
    micAmplitude.value = 0.0;
    onAudioChunkCaptured = null;
    final sub = _micStreamSubscription;
    _micStreamSubscription = null;
    await sub?.cancel();

    try {
      await _methodChannel.invokeMethod('stopMicCapture');
    } catch (e) {
      debugPrint('[AudioPipeline] stopMicCapture error: $e');
    }
  }

  /// Stop capturing audio (alias for stopMicCapture)
  Future<void> stopAudioCapture() => stopMicCapture();

  final Stopwatch _stopwatch = Stopwatch()..start();
  int _playbackEndsAtMs = 0;

  /// True while dubbed speech is still queued/playing on the speaker.
  ///
  /// Gemini returns audio in bursts that are faster than real time (a 5s sentence can arrive in
  /// ~300ms). Tracking arrival time made this go false while seconds of speech were still playing,
  /// so the silence detector auto-paused and flushed the queue mid-sentence.
  bool get isDubbedVoicePlaying => _stopwatch.elapsedMilliseconds < _playbackEndsAtMs + 250;

  /// Play incoming dubbed PCM audio chunk from SyncDub AI over the physical phone speaker
  void playDubbedPcm(String base64Data, {int sampleRate = 24000}) {
    if (base64Data.isEmpty) return;
    final now = _stopwatch.elapsedMilliseconds;
    final pcmBytes = (base64Data.length * 3) ~/ 4;
    final chunkMs = (pcmBytes * 1000) ~/ (sampleRate * 2);
    final start = now > _playbackEndsAtMs ? now : _playbackEndsAtMs;
    // Native queue is capped at ~6s of backlog, so never project further than that.
    _playbackEndsAtMs = (start + chunkMs) > (now + 6000) ? (now + 6000) : (start + chunkMs);
    _methodChannel.invokeMethod('playPcmChunk', {
      'data': base64Data,
      'sampleRate': sampleRate,
    }).catchError((e) {
      debugPrint('[AudioPipeline] playDubbedPcm error: $e');
    });
  }

  /// Stop audio playback and flush buffer
  Future<void> stopPlayback() async {
    _playbackEndsAtMs = 0;
    try {
      await _methodChannel.invokeMethod('stopAudioPlayback');
    } catch (e) {
      debugPrint('[AudioPipeline] stopPlayback error: $e');
    }
  }

  /// Instantly flush pending audio queue and AudioTrack hardware buffers
  Future<void> flushPlaybackQueue() async {
    _playbackEndsAtMs = 0;
    try {
      await _methodChannel.invokeMethod('flushPlaybackQueue');
    } catch (e) {
      debugPrint('[AudioPipeline] flushPlaybackQueue error: $e');
    }
  }

  /// Adjust real dubbed voice volume (0.0 to 1.0)
  Future<void> setDubbedVolume(double volume) async {
    try {
      await _methodChannel.invokeMethod('setDubbedVolume', {'volume': volume});
    } catch (e) {
      debugPrint('[AudioPipeline] setDubbedVolume error: $e');
    }
  }

  /// Adjust real system audio/music volume (0.0 to 1.0)
  Future<void> setOriginalVolume(double volume) async {
    try {
      await _methodChannel.invokeMethod('setOriginalVolume', {'volume': volume});
    } catch (e) {
      debugPrint('[AudioPipeline] setOriginalVolume error: $e');
    }
  }

  /// Inform native pipeline whether dubbing is paused so system audio can be restored.
  /// [preroll]=true only for a silence auto-resume: native then replays the last ~600ms captured while
  /// paused so the first syllables of the new speech are not clipped. Every manual resume drops old audio.
  Future<void> setDubbingPaused(bool isPaused, {bool preroll = false}) async {
    try {
      await _methodChannel.invokeMethod('setDubbingPaused', {'isPaused': isPaused, 'preroll': preroll && !isPaused});
    } catch (e) {
      debugPrint('[AudioPipeline] setDubbingPaused error: $e');
    }
  }

  /// Decode any media/audio file (AAC, M4A, MP4, Opus, WebM) into 16kHz 16-bit Mono PCM
  /// using native Android MediaExtractor + hardware MediaCodec.
  Future<Map<String, dynamic>> decodeAudioToPcm16k({
    required String inputPath,
    required String outputPath,
  }) async {
    try {
      final res = await _methodChannel.invokeMapMethod<String, dynamic>('decodeAudioToPcm16k', {
        'inputPath': inputPath,
        'outputPath': outputPath,
      });
      return res ?? {'success': false, 'error': 'No response from native decoder'};
    } catch (e) {
      debugPrint('[AudioPipeline] decodeAudioToPcm16k error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
