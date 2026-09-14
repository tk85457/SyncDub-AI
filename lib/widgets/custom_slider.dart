import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomSlider extends StatelessWidget {
  final String label;
  final double value; // 0.0 to 1.0
  final ValueChanged<double> onChanged;
  final bool isEmerald;
  final bool isDark;

  const CustomSlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.isEmerald = false,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = AppTheme.textPrimary(isDark);
    final fg2 = AppTheme.textSecondary(isDark);
    final trackBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final fillBg = isEmerald ? AppTheme.emerald : fg;
    final percentage = (value * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: fillBg,
            inactiveTrackColor: trackBg,
            thumbColor: Colors.white,
            overlayColor: fillBg.withValues(alpha: 0.15),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            thumbShape: _CustomThumbShape(),
            trackShape: const RoundedRectSliderTrackShape(),
          ),
          child: Slider(
            value: value.clamp(0.0, 1.0),
            min: 0.0,
            max: 1.0,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _CustomThumbShape extends SliderComponentShape {
  final double thumbRadius = 9;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    // Shadow
    final shadowPaint = Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(center + const Offset(0, 1), thumbRadius, shadowPaint);

    // Thumb Body
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, thumbRadius, fillPaint);

    // Subtle Border
    final borderPaint = Paint()
      ..color = const Color(0x1F000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, thumbRadius, borderPaint);
  }
}
