import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../theme/app_theme.dart';

/// Animated micro-motion icon inspired by itshover.com
/// Delivers smooth breathing, spring bounce, or continuous pulse.
class SyncDubMotionIcon extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color color;
  final bool animate;
  final Duration duration;

  const SyncDubMotionIcon({
    super.key,
    required this.icon,
    this.size = 20,
    required this.color,
    this.animate = true,
    this.duration = const Duration(milliseconds: 1400),
  });

  @override
  State<SyncDubMotionIcon> createState() => _SyncDubMotionIconState();
}

class _SyncDubMotionIconState extends State<SyncDubMotionIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.15).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
    ]).animate(_controller);

    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SyncDubMotionIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate != oldWidget.animate) {
      if (widget.animate) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return Icon(widget.icon, size: widget.size, color: widget.color);
    }
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Icon(widget.icon, size: widget.size, color: widget.color),
        );
      },
    );
  }
}

/// Continuous pulsing icon with an expanding aura ring (like live radar / flaticon animated ping)
class SyncDubPulsingIcon extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color color;
  final Color? auraColor;

  const SyncDubPulsingIcon({
    super.key,
    required this.icon,
    this.size = 20,
    required this.color,
    this.auraColor,
  });

  @override
  State<SyncDubPulsingIcon> createState() => _SyncDubPulsingIconState();
}

class _SyncDubPulsingIconState extends State<SyncDubPulsingIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aura = widget.auraColor ?? widget.color;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        final auraSize = widget.size + (val * 12);
        final opacity = (1.0 - val).clamp(0.0, 0.6);

        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: auraSize,
              height: auraSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: aura.withValues(alpha: opacity * 0.25),
              ),
            ),
            Icon(widget.icon, size: widget.size, color: widget.color),
          ],
        );
      },
    );
  }
}

/// Dancing animated audio sound wave bars (like modern voice messages & live streaming)
class SyncDubLiveSoundWaveIcon extends StatefulWidget {
  final double height;
  final Color color;
  final bool isPlaying;

  const SyncDubLiveSoundWaveIcon({
    super.key,
    this.height = 16,
    this.color = AppTheme.emerald,
    this.isPlaying = true,
  });

  @override
  State<SyncDubLiveSoundWaveIcon> createState() => _SyncDubLiveSoundWaveIconState();
}

class _SyncDubLiveSoundWaveIconState extends State<SyncDubLiveSoundWaveIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant SyncDubLiveSoundWaveIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return SizedBox(
          height: widget.height,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(4, (i) {
              final offset = (i * 0.25);
              final wave = (math.sin((t * 2 * math.pi) + (offset * 2 * math.pi)) + 1) / 2;
              final barHeight = widget.isPlaying
                  ? (widget.height * 0.3) + (wave * widget.height * 0.7)
                  : widget.height * 0.35;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: 2.5,
                height: barHeight,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

/// Optimized animated icon widget for SyncDub AI.
/// Renders authentic animated Flaticon GIF icons optimized for low-end phones:
/// 1. Uses cacheWidth & cacheHeight based on physical devicePixelRatio (downscales 512px frames to 48-72px, 98% RAM saving)
/// 2. Isolated with RepaintBoundary to avoid triggering parent widget repaints
/// 3. Zero-stutter gapless playback with low-overhead filter quality
/// 4. Graceful fallback to crisp vector icons if an asset fails to load
class SyncDubFlaticon extends StatelessWidget {
  final String assetName;
  final double size;
  final BoxFit fit;
  final Color? color;

  const SyncDubFlaticon({
    super.key,
    required this.assetName,
    this.size = 24,
    this.fit = BoxFit.contain,
    this.color,
  });

  static IconData iconFor(String assetName) {
    final n = assetName.toLowerCase();
    if (n.contains('home')) return Iconsax.home_2;
    if (n.contains('history')) return Iconsax.clock;
    if (n.contains('user')) return Iconsax.user;
    if (n.contains('settings')) return Iconsax.setting_2;
    if (n.contains('soundwave')) return Iconsax.sound;
    if (n.contains('speed')) return Iconsax.speedometer;
    if (n.contains('translate')) return Iconsax.language_square;
    if (n.contains('rocket')) return Iconsax.flash_1;
    if (n.contains('shield')) return Iconsax.shield_tick;
    if (n.contains('verified')) return Iconsax.verify;
    if (n.contains('mic')) return Iconsax.microphone_2;
    if (n.contains('speaker')) return Iconsax.volume_high;
    return Iconsax.global;
  }

  static String resolveAssetPath(String name) {
    var clean = name
        .replaceAll('assets/images/', '')
        .replaceAll('.webp', '')
        .replaceAll('.gif', '')
        .replaceAll('.png', '');
    return 'assets/images/$clean.webp';
  }

  @override
  Widget build(BuildContext context) {
    final path = resolveAssetPath(assetName);
    final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    // Downscale decode buffer to physical display pixels (e.g. 24 * 2.5 = 60px)
    // Low-end memory optimization: saves over 95% RAM compared to decoding raw 512x512 GIF frames
    final targetPixelSize = (size * pixelRatio).clamp(32.0, 120.0).toInt();

    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          path,
          width: size,
          height: size,
          fit: fit,
          cacheWidth: targetPixelSize,
          cacheHeight: targetPixelSize,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => Icon(
            SyncDubFlaticon.iconFor(assetName),
            size: size,
            color: color ?? AppTheme.emerald,
          ),
        ),
      ),
    );
  }
}
