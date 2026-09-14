import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../theme/app_theme.dart';

class PulsingCtaButton extends StatefulWidget {
  final bool isLive;
  final bool isDark;
  final VoidCallback onTap;

  const PulsingCtaButton({
    super.key,
    required this.isLive,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<PulsingCtaButton> createState() => _PulsingCtaButtonState();
}

class _PulsingCtaButtonState extends State<PulsingCtaButton> with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    if (widget.isLive) {
      _glowController.repeat(reverse: true);
      _dotController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant PulsingCtaButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLive && !_glowController.isAnimating) {
      _glowController.repeat(reverse: true);
      _dotController.repeat(reverse: true);
    } else if (!widget.isLive && _glowController.isAnimating) {
      _glowController.stop();
      _dotController.stop();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // In prototype:
    // Light idle: bg #0F172A, color #fff
    // Dark idle: bg #F8FAFC, color #090D16
    // Light live: bg #0F172A, color #fff + emerald glow
    // Dark live: bg #F8FAFC, color #090D16 + emerald glow
    final bgColor = widget.isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final fgColor = widget.isDark ? const Color(0xFF090D16) : const Color(0xFFFFFFFF);

    if (!widget.isLive) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: widget.onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: bgColor,
            foregroundColor: fgColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Iconsax.play, size: 14, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                'Start Live Dubbing',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: fgColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowProgress = _glowController.value; // 0.0 to 1.0
        final blur = 24.0 + (18.0 * glowProgress);
        final glowAlpha = 0.25 + (0.22 * glowProgress);

        return AnimatedBuilder(
          animation: _dotController,
          builder: (context, _) {
            final dotAlpha = 0.3 + (0.7 * _dotController.value);

            return Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.emerald, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.emerald.withValues(alpha: glowAlpha),
                    blurRadius: blur,
                    spreadRadius: 1.5,
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: widget.onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: bgColor,
                  foregroundColor: fgColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.emerald.withValues(alpha: dotAlpha),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.emerald,
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Stop Translation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: fgColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
