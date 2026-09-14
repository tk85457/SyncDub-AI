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

class _FloatingDubWidgetState extends State<FloatingDubWidget> with SingleTickerProviderStateMixin {
  // Position
  double _x = 24.0;
  double _y = 200.0;
  bool _initializedPos = false;

  // Expansion state
  bool _isExpanded = false;

  // Docked state (sliding into edge after 30s)
  bool _isDocked = false;
  bool _dockedLeft = false;

  Timer? _inactivityTimer;
  static const int _inactivitySeconds = 10;

  @override
  void initState() {
    super.initState();
    _resetInactivityTimer();
  }

  @override
  void didUpdateWidget(covariant FloatingDubWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.isTranslating && !oldWidget.state.isTranslating) {
      // Translation started: undock and bring to active view
      setState(() {
        _isDocked = false;
      });
      _resetInactivityTimer();
    }
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: _inactivitySeconds), () {
      if (!mounted) return;
      // Auto-dock to nearest edge
      final screenWidth = MediaQuery.of(context).size.width;
      final dockLeft = _x < screenWidth / 2;
      setState(() {
        _isExpanded = false;
        _isDocked = true;
        _dockedLeft = dockLeft;
        _x = dockLeft ? -26.0 : screenWidth - 32.0;
      });
    });
  }

  void _onTapFloating() {
    widget.state.triggerHaptic();
    if (_isDocked) {
      // Undock from screen edge
      final screenWidth = MediaQuery.of(context).size.width;
      setState(() {
        _isDocked = false;
        _x = _dockedLeft ? 20.0 : screenWidth - 76.0;
      });
      _resetInactivityTimer();
    } else {
      setState(() {
        _isExpanded = !_isExpanded;
      });
      _resetInactivityTimer();
    }
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    // Only show if floating is enabled in settings and (session is translating or user fab is visible)
    if (!state.isFloatingEnabled || (!state.isTranslating && !state.isFabVisible)) {
      return const SizedBox.shrink();
    }

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    if (!_initializedPos) {
      _x = screenWidth - 76.0;
      _y = screenHeight * 0.42;
      _initializedPos = true;
    }

    final isLive = state.isTranslating;
    final isDark = state.isDarkMode;
    final sf = AppTheme.surface(isDark);
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
            _isDocked = false;
            _x += details.delta.dx;
            _y += details.delta.dy;
            _x = _x.clamp(0.0, screenWidth - 60.0);
            _y = _y.clamp(60.0, screenHeight - 140.0);
          });
        },
        onPanEnd: (_) {
          _resetInactivityTimer();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: _dockedLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              // Main Floating App Icon Button
              GestureDetector(
                onTap: _onTapFloating,
                child: Container(
                  width: _isDocked ? 56 : 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: sf,
                    borderRadius: BorderRadius.circular(_isDocked ? 14 : 20),
                    border: Border.all(
                      color: isLive ? AppTheme.emerald : bd,
                      width: isLive ? 2.2 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                      if (isLive)
                        BoxShadow(
                          color: AppTheme.emeraldGlow,
                          blurRadius: 14,
                        ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Official App Icon
                      Image.asset(
                        'assets/images/app_icon.png',
                        width: 44,
                        height: 44,
                        fit: BoxFit.contain,
                      ),
                      // Live pulse indicator badge (amber if paused, emerald if active)
                      if (isLive)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: state.isPaused ? AppTheme.amber : AppTheme.emerald,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Expanded Quick Controls (Play/Pause, Pause/Resume, Language, Dock/Close)
              if (_isExpanded && !_isDocked) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: sf,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: bd),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Start / Stop Button
                      InkWell(
                        onTap: () {
                          state.triggerHaptic();
                          state.toggleLiveDubbing();
                          _resetInactivityTimer();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isLive ? AppTheme.danger.withValues(alpha: 0.12) : AppTheme.emeraldDim,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isLive ? Iconsax.stop : Iconsax.play,
                            size: 18,
                            color: isLive ? AppTheme.danger : AppTheme.emerald,
                          ),
                        ),
                      ),

                      // 2. Pause / Resume Button (when Live)
                      if (isLive) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            state.triggerHaptic();
                            state.togglePauseResume();
                            _resetInactivityTimer();
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: state.isPaused
                                  ? AppTheme.emeraldDim
                                  : AppTheme.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              state.isPaused ? Iconsax.play : Iconsax.pause,
                              size: 18,
                              color: state.isPaused ? AppTheme.emerald : AppTheme.amber,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),

                      // 3. Quick Language Picker Button
                      InkWell(
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
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceElevated(isDark),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: bd),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(state.targetLanguage.flag, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 4),
                              Text(
                                state.targetLanguage.code.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: fg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 4. Open Live Dub Screen
                      if (isLive) ...[
                        InkWell(
                          onTap: () {
                            state.triggerHaptic();
                            state.goScreen(3);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Icon(Iconsax.maximize_4, size: 16, color: fg),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],

                      // 5. Dock / Dismiss Button
                      InkWell(
                        onTap: () {
                          state.triggerHaptic();
                          final dockLeft = _x < screenWidth / 2;
                          setState(() {
                            _isExpanded = false;
                            _isDocked = true;
                            _dockedLeft = dockLeft;
                            _x = dockLeft ? -26.0 : screenWidth - 32.0;
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(Iconsax.arrow_right_3, size: 16, color: fg),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
