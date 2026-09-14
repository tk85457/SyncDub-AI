import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FloatingLivePill extends StatefulWidget {
  final bool isLive;
  final bool isMini;
  final bool isDark;
  final String? text;
  final VoidCallback onTap;

  const FloatingLivePill({
    super.key,
    required this.isLive,
    required this.isMini,
    required this.isDark,
    this.text,
    required this.onTap,
  });

  @override
  State<FloatingLivePill> createState() => _FloatingLivePillState();
}

class _FloatingLivePillState extends State<FloatingLivePill> with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final fg = widget.isDark ? const Color(0xFF090D16) : const Color(0xFFFFFFFF);

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: const Cubic(0.34, 1.56, 0.64, 1.0),
        padding: widget.isMini
            ? const EdgeInsets.all(12)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        height: 40,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(widget.isMini ? 20 : 22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _blinkController,
              builder: (context, _) {
                final alpha = 0.3 + (0.7 * _blinkController.value);
                final dotSize = widget.isMini ? 10.0 : 7.0;

                return Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.emerald.withValues(alpha: alpha),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.emerald.withValues(alpha: 0.5 * alpha),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                );
              },
            ),
            if (!widget.isMini) ...[
              const SizedBox(width: 7),
              Text(
                widget.text ?? (widget.isLive ? 'Live' : 'Ready'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
