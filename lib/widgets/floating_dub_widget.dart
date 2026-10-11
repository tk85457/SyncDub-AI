import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../models/translation_state.dart';
import '../theme/app_theme.dart';
import 'language_picker_sheet.dart';

class FloatingDubWidget extends StatefulWidget {
  final TranslationState state;

  const FloatingDubWidget({super.key, required this.state});

  @override
  State<FloatingDubWidget> createState() => _FloatingDubWidgetState();
}

class _FloatingDubWidgetState extends State<FloatingDubWidget> {
  // Position
  double _x = 20.0;
  double _y = 200.0;
  bool _initializedPos = false;

  // Docked state (sliding into edge after inactivity)
  bool _isDocked = false;
  bool _dockedLeft = false;

  bool _wasTranslating = false;
  Timer? _inactivityTimer;
  static const int _inactivitySeconds = 25;
  static const double _capsuleWidth = 250.0;
  static const double _dockedWidth = 48.0;

  @override
  void initState() {
    super.initState();
    _wasTranslating = widget.state.isTranslating;
    _resetInactivityTimer();
  }

  @override
  void didUpdateWidget(covariant FloatingDubWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isTranslating = widget.state.isTranslating;
    if (isTranslating && !_wasTranslating) {
      // Translation started: undock and bring to active view
      setState(() {
        _isDocked = false;
      });
      _resetInactivityTimer();
    }
    _wasTranslating = isTranslating;
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: _inactivitySeconds), () {
      if (!mounted) return;
      // Auto-dock to nearest edge
      final screenWidth = MediaQuery.of(context).size.width;
      final dockLeft = _x < screenWidth / 2;
      setState(() {
        _isDocked = true;
        _dockedLeft = dockLeft;
        _x = dockLeft ? -8.0 : screenWidth - 44.0;
      });
    });
  }

  void _undockCapsule() {
    widget.state.triggerHaptic();
    final screenWidth = MediaQuery.of(context).size.width;
    setState(() {
      _isDocked = false;
      _x = _dockedLeft ? 16.0 : screenWidth - _capsuleWidth;
    });
    _resetInactivityTimer();
  }

  void _dockCapsule() {
    widget.state.triggerHaptic();
    final screenWidth = MediaQuery.of(context).size.width;
    final dockLeft = _x < screenWidth / 2;
    setState(() {
      _isDocked = true;
      _dockedLeft = dockLeft;
      _x = dockLeft ? -8.0 : screenWidth - 44.0;
    });
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    // Floating icon only appears if enabled in settings AND translation is actively running
    if (!state.isFloatingEnabled || !state.isTranslating) {
      return const SizedBox.shrink();
    }

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    if (!_initializedPos) {
      _x = screenWidth - _capsuleWidth;
      _y = screenHeight * 0.38;
      _initializedPos = true;
    }

    final isLive = state.isTranslating;
    final isPaused = state.isPaused;
    final isDark = state.isDarkMode;
    final fg = AppTheme.textPrimary(isDark);
    final bd = AppTheme.border(isDark);

    return Positioned(
      left: _x,
      top: _y,
      child: GestureDetector(
        onPanStart: (_) {
          _resetInactivityTimer();
        },
        onPanUpdate: (details) {
          setState(() {
            final wasDocked = _isDocked;
            _isDocked = false;
            _x += details.delta.dx;
            _y += details.delta.dy;
            final w = wasDocked ? _dockedWidth : _capsuleWidth;
            _x = _x.clamp(0.0, (screenWidth - w).clamp(0.0, double.infinity));
            final maxY = (screenHeight - 120.0) < 60.0 ? 60.0 : (screenHeight - 120.0);
            _y = _y.clamp(60.0, maxY);
          });
        },
        onPanEnd: (_) {
          _resetInactivityTimer();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          child: _isDocked
              ? _buildDockedTab(isLive, isPaused, isDark)
              : _buildFullCapsule(state, isLive, isPaused, isDark, fg, bd),
        ),
      ),
    );
  }

  /// Compact docked tab tucked on the screen edge
  Widget _buildDockedTab(bool isLive, bool isPaused, bool isDark) {
    return GestureDetector(
      onTap: _undockCapsule,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xEE0B1120),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isPaused ? AppTheme.amber : AppTheme.emerald,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              'assets/images/app_icon.webp',
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPaused ? AppTheme.amber : AppTheme.emerald,
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sleek Cyber Capsule matching the Android native overlay
  Widget _buildFullCapsule(
    TranslationState state,
    bool isLive,
    bool isPaused,
    bool isDark,
    Color fg,
    Color bd,
  ) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xEE0B1120), // Sleek deep glassmorphism
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: isPaused ? AppTheme.amber.withValues(alpha: 0.6) : const Color(0xFF334155),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          if (isLive && !isPaused)
            BoxShadow(
              color: AppTheme.emerald.withValues(alpha: 0.25),
              blurRadius: 14,
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. App Icon with live pulse ring
          Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                'assets/images/app_icon.webp',
                width: 34,
                height: 34,
                fit: BoxFit.contain,
              ),
              Positioned(
                bottom: 1,
                right: 1,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPaused ? AppTheme.amber : AppTheme.emerald,
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),

          // 2. Pause / Resume Button (Visible from start!)
          GestureDetector(
            onTap: () {
              state.triggerHaptic();
              state.togglePauseResume();
              _resetInactivityTimer();
            },
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isPaused ? const Color(0xFF154231) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isPaused ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                  width: 1.2,
                ),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPaused ? Iconsax.play : Iconsax.pause,
                    size: 13,
                    color: isPaused ? const Color(0xFF34D399) : const Color(0xFFF1F5F9),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isPaused ? 'Resume' : 'Pause',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isPaused ? const Color(0xFF34D399) : const Color(0xFFF1F5F9),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 5),

          // 3. Language Selector Pill (${flag} ${abbr} ▾)
          GestureDetector(
            onTap: () {
              state.triggerHaptic();
              LanguagePickerSheet.show(
                context: context,
                selectedLanguage: state.targetLanguage,
                isDark: isDark,
                onSelected: (lang) => state.setTargetLanguage(lang),
              );
              _resetInactivityTimer();
            },
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF475569), width: 1.0),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.targetLanguage.flag, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text(
                    state.targetLanguage.abbr,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down, size: 14, color: Color(0xFF38BDF8)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 5),

          // 4. Stop / Stop Live Dubbing Button
          GestureDetector(
            onTap: () {
              state.triggerHaptic();
              state.toggleLiveDubbing();
              _resetInactivityTimer();
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF475569), width: 1.0),
              ),
              alignment: Alignment.center,
              child: const Icon(Iconsax.stop, size: 14, color: AppTheme.danger),
            ),
          ),
          const SizedBox(width: 4),

          // 5. Dock / Tuck to side button
          GestureDetector(
            onTap: _dockCapsule,
            child: Container(
              width: 28,
              height: 32,
              alignment: Alignment.center,
              child: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }
}
