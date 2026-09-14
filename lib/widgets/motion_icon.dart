import 'dart:math' as math;
import 'package:flutter/material.dart';
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

/// Renders authentic Flaticon animated GIF icons extracted from flaticon.com
class SyncDubFlaticon extends StatelessWidget {
  final String assetName;
  final double size;
  final BoxFit fit;

  const SyncDubFlaticon({
    super.key,
    required this.assetName,
    this.size = 24,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final path = assetName.startsWith('assets/') ? assetName : 'assets/images/$assetName';
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        path,
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.animation,
          size: size,
          color: AppTheme.emerald,
        ),
      ),
    );
  }
}
