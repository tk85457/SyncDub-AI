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
  AudioPipelineService._internal();

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
  Future<bool> requestInternalAudioPermission() async {
    try {
      final bool granted =
          await _methodChannel.invokeMethod<bool>('requestInternalAudioPermission') ?? false;
      return granted;
    } catch (e) {
      debugPrint('[AudioPipeline] requestInternalAudioPermission error: $e');
      return false;
    }
  }

  /// Start capturing audio (mode: "internal" for direct YouTube/video stream, or "mic")
  Future<bool> startAudioCapture({String mode = 'internal'}) async {
    if (_isCapturing) return true;
    try {
      final res = await _methodChannel.invokeMethod<Map>('startAudioCapture', {'mode': mode});
      final bool started = res?['started'] == true;
      _activeCaptureMode = res?['mode']?.toString() ?? mode;
      captureModeNotifier.value = _activeCaptureMode;

      if (started) {
        _isCapturing = true;
        _micStreamSubscription?.cancel();
        _micStreamSubscription = _eventChannel.receiveBroadcastStream().listen(
          (dynamic event) {
            if (event is Map) {
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
          },
          onError: (dynamic error) {
            debugPrint('[AudioPipeline] Audio capture stream error: $error');
          },
          onDone: () {
            _isCapturing = false;
            micAmplitude.value = 0.0;
          },
        );
        return true;
      }
    } catch (e) {
      debugPrint('[AudioPipeline] startAudioCapture exception: $e');
    }
    return false;
  }

  /// Legacy alias: Start capturing audio (defaults to internal video stream)
  Future<bool> startMicCapture() => startAudioCapture(mode: 'internal');

  /// Stop capturing microphone audio
  Future<void> stopMicCapture() async {
    _isCapturing = false;
    micAmplitude.value = 0.0;
    await _micStreamSubscription?.cancel();
    _micStreamSubscription = null;

    try {
      await _methodChannel.invokeMethod('stopMicCapture');
    } catch (e) {
      debugPrint('[AudioPipeline] stopMicCapture error: $e');
    }
  }

  /// Play incoming dubbed PCM audio chunk from Gemini over the physical phone speaker
  Future<void> playDubbedPcm(String base64Data, {int sampleRate = 24000}) async {
    if (base64Data.isEmpty) return;
    try {
      await _methodChannel.invokeMethod('playPcmChunk', {
        'data': base64Data,
        'sampleRate': sampleRate,
      });
    } catch (e) {
      debugPrint('[AudioPipeline] playDubbedPcm error: $e');
    }
  }

  /// Stop audio playback and flush buffer
  Future<void> stopPlayback() async {
    try {
      await _methodChannel.invokeMethod('stopAudioPlayback');
    } catch (e) {
      debugPrint('[AudioPipeline] stopPlayback error: $e');
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
}
