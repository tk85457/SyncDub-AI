import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnimatedWaveform extends StatefulWidget {
  final bool isLive;
  final int barCount;
  final double height;
  final bool isDark;

  const AnimatedWaveform({
    super.key,
    required this.isLive,
    this.barCount = 28,
    this.height = 44,
    this.isDark = false,
  });

  @override
  State<AnimatedWaveform> createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<AnimatedWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _baseHeights = [];

  // Prototype base height sequence
  static const List<double> _protoHeights = [
    8, 14, 24, 36, 28, 18, 44, 32, 20, 38, 26, 16, 42, 30, 22, 36, 24, 14, 40, 28, 18, 34, 22, 12, 38, 26, 16, 44
  ];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.barCount; i++) {
      _baseHeights.add(_protoHeights[i % _protoHeights.length]);
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    if (widget.isLive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLive && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isLive && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final idleColor = widget.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    if (!widget.isLive) {
      return SizedBox(
        height: widget.height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(widget.barCount, (i) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3,
              height: 8,
              decoration: BoxDecoration(
                color: idleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * 2 * pi;

        return SizedBox(
          height: widget.height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(widget.barCount, (i) {
              final phase = (i / widget.barCount) * 2 * pi * 1.5;
              final wave = (sin(t + phase) + 1.0) / 2.0; // 0.0 to 1.0
              final targetH = _baseHeights[i];
              // Dynamic bounce between min 5px and max targetH
              final curH = (5.0 + (targetH - 5.0) * wave).clamp(4.0, widget.height);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: 3,
                height: curH,
                decoration: BoxDecoration(
                  color: AppTheme.emerald,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.emerald.withValues(alpha: 0.35 * wave),
                      blurRadius: 4,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
