import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/translation_state.dart';
import '../services/audio_pipeline_service.dart';
import 'motion_icon.dart';

/// Authentic Chrome Extension Master Connect Button
///
/// Features:
/// 1. Idle: Royal Blue Gradient, Play icon, and resting mini-waveform bars.
/// 2. Connecting: Sky Blue Gradient, 4 animated equalizer bars (`eq-bar`) with staggered bounces, and tap-to-cancel capability.
/// 3. Live: Crimson Red Gradient, pulsating glow ring, Stop icon, real-time timer, and live microphone-reactive equalizer bars.
/// 4. Pause / Resume: Chrome-extension companion secondary button (Amber/Emerald).
class MasterConnectButton extends StatefulWidget {
  final TranslationState state;

  const MasterConnectButton({
    super.key,
    required this.state,
  });

  @override
  State<MasterConnectButton> createState() => _MasterConnectButtonState();
}

class _MasterConnectButtonState extends State<MasterConnectButton>
    with TickerProviderStateMixin {
  late AnimationController _eqController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // 4-bar equalizer bounce animation (0.9s duration matching Chrome extension eq-bounce)
    _eqController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    // Subtle breathing pulse for live state
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _eqController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLive = widget.state.isTranslating;
    final isConnecting = widget.state.isConnecting;
    final isPaused = widget.state.isPaused;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // MASTER BUTTON
        AnimatedBuilder(
          animation: Listenable.merge([_eqController, _pulseController]),
          builder: (context, child) {
            final pulseVal = _pulseController.value;

            // Colors & Gradients
            final Gradient bgGradient;
            final List<BoxShadow> shadows;

            if (isLive) {
              bgGradient = const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
              );
              shadows = [
                BoxShadow(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.35 + (0.18 * pulseVal)),
                  blurRadius: 16 + (8 * pulseVal),
                  spreadRadius: 1 + (2 * pulseVal),
                ),
              ];
            } else if (isConnecting) {
              bgGradient = const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
              );
              shadows = [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.40),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ];
            } else {
              bgGradient = const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
              );
              shadows = [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.30),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ];
            }

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  widget.state.toggleLiveDubbing();
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeInOut,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: bgGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: shadows,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isConnecting) ...[
                          // Chrome-Extension Style 4-Bar Equalizer Animation
                          _buildEqualizerBars(
                            animationProgress: _eqController.value,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          const Flexible(
                            child: Text(
                              'Connecting to SyncDub AI… (Tap to Cancel)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else if (isLive) ...[
                          const SyncDubFlaticon(
                            assetName: 'anim_soundwave.gif',
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Stop Live Dubbing (${widget.state.formattedTimer})',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Live Reactive Audio Equalizer
                          ValueListenableBuilder<double>(
                            valueListenable: AudioPipelineService().micAmplitude,
                            builder: (context, amp, _) {
                              return _buildLiveEqualizerBars(
                                micAmplitude: amp,
                                animProgress: _eqController.value,
                                isPaused: isPaused,
                              );
                            },
                          ),
                        ] else ...[
                          const SyncDubFlaticon(
                            assetName: 'anim_soundwave.gif',
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Start Live Dubbing',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Resting waveform mini-bars
                          _buildIdleBars(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // Chrome-Extension Style Pause / Resume Secondary Button
        if (isLive) ...[
          const SizedBox(height: 10),
          InkWell(
            onTap: () => widget.state.togglePauseResume(),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: isPaused
                    ? const Color(0xFF10B981) // Emerald Resume
                    : const Color(0xFFF59E0B), // Amber Pause
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: (isPaused ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
                        .withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SyncDubFlaticon(
                      assetName: isPaused ? 'anim_soundwave.gif' : 'anim_speed.gif',
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isPaused ? 'Resume Translation' : 'Pause Translation',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 4 Equalizer bars replicating Chrome extension `@keyframes eq-bounce`
  Widget _buildEqualizerBars({
    required double animationProgress,
    required Color color,
  }) {
    // 4 bars with delays 0.0, 0.15, 0.30, 0.45
    final delays = [0.0, 0.15, 0.30, 0.45];

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(4, (i) {
        final phase = (animationProgress - delays[i]) % 1.0;
        final sineVal = math.sin(phase * 2 * math.pi);
        // Height between 6px and 22px
        final barHeight = 6.0 + (16.0 * (0.5 + 0.5 * sineVal));

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.8),
          width: 3.5,
          height: barHeight,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  /// Live equalizer bars that react dynamically to microphone amplitude
  Widget _buildLiveEqualizerBars({
    required double micAmplitude,
    required double animProgress,
    required bool isPaused,
  }) {
    if (isPaused) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(4, (_) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            width: 3.0,
            height: 4.0,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      );
    }

    final mults = [1.2, 0.8, 1.4, 0.9];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(4, (i) {
        final wave = math.sin((animProgress * 2 * math.pi) + (i * 0.8));
        final voiceBoost = (micAmplitude * 32.0 * mults[i]).clamp(0.0, 18.0);
        final height = 6.0 + (5.0 * (0.5 + 0.5 * wave)) + voiceBoost;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.8),
          width: 3.2,
          height: height.clamp(5.0, 24.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  /// Subtle resting bars for Idle state
  Widget _buildIdleBars() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _miniBar(7),
        _miniBar(14),
        _miniBar(10),
        _miniBar(6),
      ],
    );
  }

  Widget _miniBar(double h) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      width: 2.8,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}
