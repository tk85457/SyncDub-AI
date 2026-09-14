import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../models/translation_state.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final TranslationState state;

  const LoginScreen({super.key, required this.state});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final isDark = state.isDarkMode;
    final bg = isDark ? const Color(0xFF090D16) : const Color(0xFFFAFAFA);
    final fg = AppTheme.textPrimary(isDark);
    final fg2 = AppTheme.textSecondary(isDark);
    final fg3 = AppTheme.textMuted(isDark);
    final bd = AppTheme.border(isDark);
    final isAuthenticating = state.isAuthenticating;
    final activeError = state.activeError;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Soft ambient glow in dark mode
          if (isDark)
            Positioned(
              top: -80,
              left: 0,
              right: 0,
              height: 380,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.emerald.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  // Top Row: Minimal Theme Switcher (No clutter)
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () {
                        state.triggerHaptic();
                        state.toggleTheme();
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: (isDark ? const Color(0xFF131D2E) : Colors.white).withValues(alpha: 0.9),
                        side: BorderSide(color: bd),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: Icon(
                        isDark ? Iconsax.sun_1 : Iconsax.moon,
                        size: 18,
                        color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF6366F1),
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Centerpiece: Uncropped App Icon with Gentle Halo
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = 1.0 + (math.sin(_pulseController.value * 2 * math.pi) * 0.025);
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppTheme.emerald.withValues(alpha: isDark ? 0.20 : 0.10),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.emerald.withValues(alpha: isDark ? 0.32 : 0.14),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/images/app_icon.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // App Title & Clean Subhead
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'SyncDub',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                          color: fg,
                        ),
                      ),
                      Text(
                        ' AI',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                          color: AppTheme.emerald,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Real-time neural voice dubbing for any video',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: fg2,
                      letterSpacing: -0.2,
                    ),
                  ),

                  // Error notification if sign-in fails
                  if (activeError != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Iconsax.warning_2, size: 16, color: AppTheme.danger),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              activeError.reason,
                              style: TextStyle(fontSize: 12, color: fg2),
                            ),
                          ),
                          InkWell(
                            onTap: () => state.clearActiveError(),
                            child: Icon(Iconsax.close_circle, size: 16, color: fg3),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Spacer(flex: 3),

                  // Main Google Sign-In Action (Simple, Bold, Clean)
                  InkWell(
                    onTap: isAuthenticating
                        ? null
                        : () {
                            state.triggerHaptic();
                            state.handleGoogleLogin();
                          },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: isAuthenticating
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: isDark ? Colors.black : Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Signing in…',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.black : Colors.white,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/images/google_logo.png',
                                    width: 22,
                                    height: 22,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Continue with Google',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                      color: isDark ? Colors.black : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Clean Trust & Privacy Note
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Iconsax.shield_tick, size: 13, color: AppTheme.emerald),
                      const SizedBox(width: 6),
                      Text(
                        '100% Private · Zero Audio Recorded',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: fg3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Minimal Footer Legal
                  Text(
                    'By continuing, you agree to Terms & Privacy Policy',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: fg3,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
