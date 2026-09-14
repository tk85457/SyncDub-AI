import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../models/translation_state.dart';
import '../theme/app_theme.dart';
import '../widgets/motion_icon.dart';

class ConnectingScreen extends StatefulWidget {
  final TranslationState state;

  const ConnectingScreen({super.key, required this.state});

  @override
  State<ConnectingScreen> createState() => _ConnectingScreenState();
}

class _ConnectingScreenState extends State<ConnectingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  int _currentStep = 0;
  Timer? _stepTimer;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    // Sequentially advance through connection steps
    _stepTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_currentStep < 3) {
        setState(() {
          _currentStep++;
        });
      } else {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            widget.state.goScreen(3); // Go to Home
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.state.isDarkMode;
    final fg = AppTheme.textPrimary(isDark);
    final fg3 = AppTheme.textMuted(isDark);
    final sf = AppTheme.surface(isDark);
    final bd = AppTheme.border(isDark);

    final List<Map<String, dynamic>> steps = [
      {
        'icon': Iconsax.global,
        'name': 'Establishing TLS 1.3 socket',
        'sub': 'Encrypted pipeline',
      },
      {
        'icon': Iconsax.flash,
        'name': 'Connecting to SyncDub AI Live Node',
        'sub': 'Routing nearest server (~32ms)',
      },
      {
        'icon': Iconsax.microphone,
        'name': 'Initialising 48kHz PCM Stream',
        'sub': '16-bit low latency buffer',
      },
      {
        'icon': Iconsax.tick_circle,
        'name': 'Live Engine Synced',
        'sub': 'Zero audio persistence mode',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'SyncDub',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 28),

          // Glowing App Icon with rotation ring
          Stack(
            alignment: Alignment.center,
            children: [
              RotationTransition(
                turns: _spinController,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3), width: 2),
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppTheme.emerald,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.emerald,
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Image.asset(
                'assets/images/app_icon.png',
                width: 64,
                height: 64,
                fit: BoxFit.contain,
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Step Checklist
          Column(
            children: List.generate(steps.length, (i) {
              final isDone = i < _currentStep;
              final isCur = i == _currentStep;
              final opacity = isDone || isCur ? 1.0 : 0.4;
              final data = steps[i];

              return AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: opacity,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isCur ? AppTheme.emeraldDim : sf,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCur ? AppTheme.emerald : bd,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isDone
                              ? AppTheme.emerald
                              : (isCur ? AppTheme.emeraldDim : sf),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDone || isCur ? AppTheme.emerald : bd,
                          ),
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Iconsax.tick_circle, size: 16, color: Colors.white)
                              : isCur
                                  ? SyncDubMotionIcon(
                                      icon: data['icon'] as IconData,
                                      size: 15,
                                      color: AppTheme.emerald,
                                    )
                                  : Icon(
                                      data['icon'] as IconData,
                                      size: 15,
                                      color: fg3,
                                    ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['name'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: fg,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              data['sub'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                color: fg3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Text(
            'Handshake in progress…',
            style: TextStyle(
              fontSize: 12,
              color: fg3,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () {
              _stepTimer?.cancel();
              widget.state.goScreen(3);
            },
            icon: const Icon(Iconsax.close_circle, size: 16),
            label: const Text('Cancel Connection', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: fg3,
              side: BorderSide(color: bd),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
