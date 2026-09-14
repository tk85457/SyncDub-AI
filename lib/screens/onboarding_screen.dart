import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/languages.dart';
import '../models/translation_state.dart';
import '../services/floating_overlay_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/syncdub_waveform.dart';

class OnboardingScreen extends StatefulWidget {
  final TranslationState state;

  const OnboardingScreen({super.key, required this.state});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _pulseController;
  late final AnimationController _demoWaveController;

  double _currentPage = 0.0;
  int _currentIndex = 0;

  bool _micGranted = false;
  bool _overlayGranted = false;

  // Interactive Slide 0 Demo State
  bool _demoDubbingActive = false;

  // Interactive Slide 1 Floating Pill State
  bool _floatingMockDocked = false;

  final List<Color> _slideColors = [
    AppTheme.emerald,           // Slide 0: Neural Dubbing
    const Color(0xFF0EA5E9),    // Slide 1: Floating Overlay (Sky Blue)
    const Color(0xFF6366F1),    // Slide 2: Permissions (Indigo)
    const Color(0xFFF59E0B),    // Slide 3: Audio Ducking (Amber)
    AppTheme.emerald,           // Slide 4: Personalize & Launch (Emerald)
  ];

  @override
  void initState() {
    super.initState();
    // 100% Full-Screen Edge-to-Edge Carousel
    _pageController = PageController(viewportFraction: 1.0)
      ..addListener(() {
        if (mounted) {
          setState(() {
            _currentPage = _pageController.page ?? 0.0;
            _currentIndex = _currentPage.round();
          });
        }
      });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _demoWaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _checkPermissionsState();
  }

  Future<void> _checkPermissionsState() async {
    final mic = await Permission.microphone.isGranted;
    final overlay = await FloatingOverlayManager.checkPermission();
    if (mounted) {
      setState(() {
        _micGranted = mic;
        _overlayGranted = overlay;
        if (mic) widget.state.grantPermission(0);
      });
    }
  }

  Future<void> _requestMicrophone() async {
    widget.state.triggerHaptic();
    final status = await Permission.microphone.request();
    final isGranted = status.isGranted;
    if (mounted) {
      setState(() {
        _micGranted = isGranted;
        if (isGranted) widget.state.grantPermission(0);
      });
    }
  }

  Future<void> _requestOverlayPermission() async {
    widget.state.triggerHaptic();
    await FloatingOverlayManager.requestPermission();
    final hasPerm = await FloatingOverlayManager.checkPermission();
    if (mounted) {
      setState(() {
        _overlayGranted = hasPerm;
      });
    }
  }

  Future<void> _finishOnboarding() async {
    widget.state.triggerHaptic();
    await widget.state.completeOnboardingDirectly();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    _demoWaveController.dispose();
    super.dispose();
  }

  Color _getCurrentGlowColor() {
    final idx = _currentPage.floor().clamp(0, _slideColors.length - 1);
    final nextIdx = (idx + 1).clamp(0, _slideColors.length - 1);
    final ratio = (_currentPage - idx).clamp(0.0, 1.0);
    return Color.lerp(_slideColors[idx], _slideColors[nextIdx], ratio) ?? AppTheme.emerald;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final isDark = state.isDarkMode;
    final bg = isDark ? const Color(0xFF070B14) : const Color(0xFFF8FAFC);
    final fg = AppTheme.textPrimary(isDark);
    final fg2 = AppTheme.textSecondary(isDark);
    final fg3 = AppTheme.textMuted(isDark);
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final bd = AppTheme.border(isDark);

    const totalSlides = 5;
    final activeColor = _getCurrentGlowColor();

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // 1. DYNAMIC FULL-SCREEN AMBIENT AURA
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pageController,
              builder: (context, _) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.4),
                      radius: 1.25,
                      colors: [
                        activeColor.withValues(alpha: isDark ? 0.22 : 0.12),
                        activeColor.withValues(alpha: isDark ? 0.05 : 0.02),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. FULL-SCREEN EDGE-TO-EDGE PAGEVIEW
          PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: totalSlides,
            itemBuilder: (context, index) {
              final diff = _currentPage - index;
              final heroScale = (1.0 - (diff.abs() * 0.16)).clamp(0.82, 1.0);
              final heroTranslateY = (diff * 20.0);
              final textParallaxX = (diff * 36.0);
              final opacity = (1.0 - (diff.abs() * 0.45)).clamp(0.0, 1.0);

              return Opacity(
                opacity: opacity,
                child: _buildSlideContent(
                  index: index,
                  heroScale: heroScale,
                  heroTranslateY: heroTranslateY,
                  textParallaxX: textParallaxX,
                  isDark: isDark,
                  fg: fg,
                  fg2: fg2,
                  fg3: fg3,
                  cardBg: cardBg,
                  bd: bd,
                  activeColor: activeColor,
                ),
              );
            },
          ),

          // 3. FLOATING TOP BAR (Brand Pill + Slide Counter + Skip)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // App Brand Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (isDark ? const Color(0xFF0F172A) : Colors.white).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: bd),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/app_icon.png',
                          width: 22,
                          height: 22,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'SyncDub AI',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: fg,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: activeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_currentIndex + 1}/$totalSlides',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: activeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Skip Button (routes directly to Login)
                  InkWell(
                    onTap: _finishOnboarding,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFF0F172A) : Colors.white).withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: bd),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Skip',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: fg2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Iconsax.arrow_right_3, size: 14, color: fg2),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. FLOATING BOTTOM CONTROL ISLAND
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    bg.withValues(alpha: 0.0),
                    bg.withValues(alpha: 0.85),
                    bg,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Smooth Stretching Page Indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(totalSlides, (i) {
                          final isActive = _currentIndex == i;
                          final slideColor = _slideColors[i];
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: isActive ? 32 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: isActive
                                  ? slideColor
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: slideColor.withValues(alpha: 0.55),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 14),

                      // Navigation Actions: Back Button + Primary Continue
                      Row(
                        children: [
                          if (_currentIndex > 0) ...[
                            InkWell(
                              onTap: () {
                                widget.state.triggerHaptic();
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeInOutCubic,
                                );
                              },
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                height: 52,
                                width: 52,
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: bd),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Icon(Iconsax.arrow_left_2, size: 20, color: fg),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],

                          Expanded(
                            child: InkWell(
                              onTap: () {
                                widget.state.triggerHaptic();
                                if (_currentIndex < totalSlides - 1) {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 360),
                                    curve: Curves.easeInOutCubic,
                                  );
                                } else {
                                  _finishOnboarding();
                                }
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      activeColor,
                                      activeColor.withValues(alpha: 0.88),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: activeColor.withValues(alpha: 0.42),
                                      blurRadius: 18,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _currentIndex == totalSlides - 1
                                          ? 'Start Dubbing in ${widget.state.targetLanguage.name} 🚀'
                                          : 'Continue',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      _currentIndex == totalSlides - 1
                                          ? Iconsax.flash_1
                                          : Iconsax.arrow_right_1,
                                      size: 18,
                                      color: Colors.black,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlideContent({
    required int index,
    required double heroScale,
    required double heroTranslateY,
    required double textParallaxX,
    required bool isDark,
    required Color fg,
    required Color fg2,
    required Color fg3,
    required Color cardBg,
    required Color bd,
    required Color activeColor,
  }) {
    Widget heroWidget;
    String tagLabel;
    IconData tagIcon;
    String title;
    String subtitle;
    Widget? extraWidget;

    switch (index) {
      case 0:
        tagLabel = 'ZERO-LATENCY NEURAL DUBBING';
        tagIcon = Iconsax.flash_1;
        title = 'Real-Time\nLive Speech Dubbing';
        subtitle = 'Listen to any foreign YouTube video, Reels, or lecture dubbed into your native language with zero lag.';
        heroWidget = _buildHero0(isDark, activeColor, bd, cardBg, fg, fg2);
        extraWidget = Row(
          children: [
            _metricChip('⚡ <380ms', 'Ultra Low Latency', isDark, bd, fg),
            const SizedBox(width: 8),
            _metricChip('🌐 100+ Langs', 'Neural Voices', isDark, bd, fg),
            const SizedBox(width: 8),
            _metricChip('🎯 99.4%', 'Speech Fidelity', isDark, bd, fg),
          ],
        );
        break;

      case 1:
        tagLabel = 'BACKGROUND OVERLAY SUPERPOWER';
        tagIcon = Iconsax.layer;
        title = 'Works in Background\nOver YouTube & Reels';
        subtitle = 'Dubbing never stops when you switch apps. Floating controls stay on screen and auto-dock to the edge after 10s.';
        heroWidget = _buildHero1(isDark, bd, cardBg, fg);
        break;

      case 2:
        tagLabel = 'ESSENTIAL 2-STEP PERMISSIONS';
        tagIcon = Iconsax.shield_tick;
        title = 'Grant Required\nPermissions';
        subtitle = 'SyncDub requires 2 core permissions to capture incoming audio from your speaker and float controls over videos.';
        heroWidget = _buildHero2(isDark, bd, fg, fg3, cardBg);
        break;

      case 3:
        tagLabel = 'SMART AUDIO DUCKING & TUNING';
        tagIcon = Iconsax.setting_2;
        title = 'Smart Audio Ducking\n& Dual Volume';
        subtitle = 'Original video volume automatically drops to 20% when the dubbed voice speaks, so you hear every word crystal clear.';
        heroWidget = _buildHero3(isDark, bd, fg, fg3, cardBg);
        break;

      case 4:
      default:
        tagLabel = 'INSTANT PERSONALIZATION';
        tagIcon = Iconsax.language_circle;
        title = 'Choose Your\nDubbing Language';
        subtitle = 'Pick your primary language now. You can change this anytime with 1 tap from the floating pill.';
        heroWidget = _buildHero4(isDark, bd, fg, cardBg, activeColor);
        break;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            22,
            MediaQuery.of(context).padding.top + 62,
            22,
            120, // Clear floating bottom bar
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - (MediaQuery.of(context).padding.top + 182)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Slide Tag Badge
                    _tagBadge(icon: tagIcon, label: tagLabel, color: activeColor),
                    const SizedBox(height: 10),

                    // Headline with Parallax
                    Transform.translate(
                      offset: Offset(textParallaxX, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                              letterSpacing: -0.6,
                              color: fg,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: fg2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Hero Graphic with Zoom & Translate Parallax
                Center(
                  child: Transform.translate(
                    offset: Offset(0, heroTranslateY),
                    child: Transform.scale(
                      scale: heroScale,
                      child: heroWidget,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Extra widgets (metrics / options)
                ?extraWidget,
              ],
            ),
          ),
        );
      },
    );
  }

  // Hero 0: Glowing App Icon with Interactive "Tap to Demo" Dubbing Capsule
  Widget _buildHero0(bool isDark, Color activeColor, Color bd, Color cardBg, Color fg, Color fg2) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final scale = 1.0 + (math.sin(_pulseController.value * 2 * math.pi) * 0.035);
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        activeColor.withValues(alpha: 0.28),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.38),
                          blurRadius: 28,
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
        const SizedBox(height: 16),

        // Interactive Live Dubbing Demo Simulator Card
        InkWell(
          onTap: () {
            widget.state.triggerHaptic();
            setState(() {
              _demoDubbingActive = !_demoDubbingActive;
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _demoDubbingActive ? AppTheme.emerald : bd,
                width: _demoDubbingActive ? 1.6 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: _demoDubbingActive
                      ? AppTheme.emerald.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _demoDubbingActive ? AppTheme.emerald : Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _demoDubbingActive ? 'AI DUBBING SIMULATOR (LIVE)' : 'TAP TO TEST DUBBING DEMO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: _demoDubbingActive ? AppTheme.emerald : fg2,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _demoDubbingActive
                            ? AppTheme.emerald.withValues(alpha: 0.15)
                            : activeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _demoDubbingActive ? '🔊 Playing' : '▶ Tap Demo',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _demoDubbingActive ? AppTheme.emerald : activeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('🇺🇸 EN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _demoDubbingActive
                          ? SyncDubSignatureWaveform(
                              height: 22,
                              isDark: isDark,
                            )
                          : Container(
                              height: 2,
                              color: bd,
                            ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '🇮🇳 HI Dub',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: _demoDubbingActive ? AppTheme.emerald : fg2,
                      ),
                    ),
                  ],
                ),
                if (_demoDubbingActive) ...[
                  const SizedBox(height: 8),
                  Text(
                    '“Artificial intelligence is revolutionizing communication...”\n→ “आर्टिफिशियल इंटेलिजेंस संचार में क्रांति ला रहा है...”',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.emerald,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Hero 1: Mock Phone Screen with YouTube & Interactive Floating Capsule
  Widget _buildHero1(bool isDark, Color bd, Color cardBg, Color fg) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF070B14),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simulated YouTube Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('▶ YouTube', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Global Tech Summit 2026 Keynote...',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Interactive Floating SyncDub Capsule Demo
          InkWell(
            onTap: () {
              widget.state.triggerHaptic();
              setState(() {
                _floatingMockDocked = !_floatingMockDocked;
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF0EA5E9), width: 1.6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/app_icon.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 10),
                  if (!_floatingMockDocked) ...[
                    const Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text('⏸ Pause', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFFBBF24))),
                          Text('🌐 HI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0EA5E9))),
                          Text('⤢ App', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                  ] else ...[
                    const Expanded(
                      child: Text(
                        'Docked to edge (Tap to expand)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70),
                      ),
                    ),
                    const Icon(Iconsax.arrow_left_3, size: 14, color: Color(0xFF0EA5E9)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 10-Second Auto-Dock Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Iconsax.timer_1, size: 14, color: AppTheme.emerald),
                SizedBox(width: 6),
                Text(
                  'Auto-docks to side after 10s of inactivity',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.emerald),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Hero 2: Interactive 1-Tap Permission Cards
  Widget _buildHero2(bool isDark, Color bd, Color fg, Color fg3, Color cardBg) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _permissionCard(
          icon: Iconsax.microphone_2,
          title: 'Microphone Access',
          desc: 'Captures incoming speech from your speaker to dub',
          isGranted: _micGranted,
          onAction: _requestMicrophone,
          isDark: isDark,
          bd: bd,
          fg: fg,
          fg3: fg3,
          cardBg: cardBg,
        ),
        const SizedBox(height: 10),
        _permissionCard(
          icon: Iconsax.layer,
          title: 'Display Over Other Apps',
          desc: 'Floats controls over YouTube, Reels, and Netflix',
          isGranted: _overlayGranted,
          onAction: _requestOverlayPermission,
          isDark: isDark,
          bd: bd,
          fg: fg,
          fg3: fg3,
          cardBg: cardBg,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: bd),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Iconsax.lock, size: 13, color: AppTheme.emerald),
              const SizedBox(width: 6),
              Text(
                '100% Private · Zero Audio Recorded or Stored',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Hero 3: Smart Audio Ducking Simulation
  Widget _buildHero3(bool isDark, Color bd, Color fg, Color fg3, Color cardBg) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: bd),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Audio Ducking Simulation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('ACTIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.emerald)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Original Video Volume Bar (dips to 20%)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Original Media Audio (YouTube / Reels)', style: TextStyle(fontSize: 11, color: fg3)),
                      const Text('20% (Auto-Ducked)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFF59E0B))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 0.20,
                      minHeight: 6,
                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Dubbed Voice Volume Bar (plays at 100%)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('AI Dubbed Voice (Crystal Clear)', style: TextStyle(fontSize: 11, color: fg3)),
                      const Text('100%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.emerald)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 1.0,
                      minHeight: 6,
                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.emerald),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        _audioSettingPill(
          icon: Iconsax.sound,
          title: 'Dual Independent Volume',
          desc: 'Tune dubbed voice and background video volume independently in Settings.',
          badge: 'REALTIME',
          badgeColor: const Color(0xFF0EA5E9),
          isDark: isDark,
          bd: bd,
          fg: fg,
          fg3: fg3,
          cardBg: cardBg,
        ),
      ],
    );
  }

  // Hero 4: Live Target Language Selector Grid (Instant TTFV Personalization)
  Widget _buildHero4(bool isDark, Color bd, Color fg, Color cardBg, Color activeColor) {
    final currentTarget = widget.state.targetLanguage;
    final topLanguages = [
      kSupportedLanguages.firstWhere((l) => l.code == 'hi-IN', orElse: () => kSupportedLanguages[0]),
      kSupportedLanguages.firstWhere((l) => l.code == 'en-US', orElse: () => kSupportedLanguages[1]),
      kSupportedLanguages.firstWhere((l) => l.code == 'es-ES', orElse: () => kSupportedLanguages[2]),
      kSupportedLanguages.firstWhere((l) => l.code == 'fr-FR', orElse: () => kSupportedLanguages[3]),
      kSupportedLanguages.firstWhere((l) => l.code == 'de-DE', orElse: () => kSupportedLanguages[4]),
      kSupportedLanguages.firstWhere((l) => l.code == 'ja-JP', orElse: () => kSupportedLanguages[5]),
      kSupportedLanguages.firstWhere((l) => l.code == 'bn-IN', orElse: () => kSupportedLanguages[6]),
      kSupportedLanguages.firstWhere((l) => l.code == 'ru-RU', orElse: () => kSupportedLanguages[7]),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: bd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Your Primary Language',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              Text(
                'Selected: ${currentTarget.flag} ${currentTarget.name}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.emerald),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 2-column compact language grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topLanguages.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 3.2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, i) {
              final lang = topLanguages[i];
              final isSelected = lang.code == currentTarget.code;
              return InkWell(
                onTap: () {
                  widget.state.setTargetLanguage(lang);
                  setState(() {});
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.emerald.withValues(alpha: 0.15)
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.emerald : bd,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(lang.flag, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lang.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? AppTheme.emerald : fg,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, size: 14, color: AppTheme.emerald),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tagBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String title, String subtitle, bool isDark, Color bd, Color fg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: bd),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 9, color: AppTheme.emerald, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _permissionCard({
    required IconData icon,
    required String title,
    required String desc,
    required bool isGranted,
    required VoidCallback onAction,
    required bool isDark,
    required Color bd,
    required Color fg,
    required Color fg3,
    required Color cardBg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isGranted ? AppTheme.emerald.withValues(alpha: 0.5) : bd,
          width: isGranted ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: isGranted ? AppTheme.emerald.withValues(alpha: 0.2) : const Color(0xFF334155),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isGranted ? AppTheme.emerald : Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(fontSize: 10, color: fg3),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: isGranted ? null : onAction,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isGranted ? AppTheme.emerald.withValues(alpha: 0.15) : AppTheme.emerald,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isGranted ? '✓ Granted' : 'Allow',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isGranted ? AppTheme.emerald : Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _audioSettingPill({
    required IconData icon,
    required String title,
    required String desc,
    required String badge,
    required Color badgeColor,
    required bool isDark,
    required Color bd,
    required Color fg,
    required Color fg3,
    required Color cardBg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: badgeColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: badgeColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(fontSize: 10.5, color: fg3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
