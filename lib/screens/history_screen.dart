import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../models/translation_state.dart';
import '../theme/app_theme.dart';
import '../widgets/motion_icon.dart';

class HistoryScreen extends StatelessWidget {
  final TranslationState state;

  const HistoryScreen({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = state.isDarkMode;
    final fg = AppTheme.textPrimary(isDark);
    final fg2 = AppTheme.textSecondary(isDark);
    final fg3 = AppTheme.textMuted(isDark);
    final bd = AppTheme.border(isDark);
    final sf = AppTheme.surface(isDark);
    final sf2 = AppTheme.surfaceElevated(isDark);

    final sessions = state.historySessions;

    return Column(
      children: [
        // App Nav Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: bd)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/images/app_icon.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Session History',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: fg,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: sf2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: bd),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Iconsax.clock, size: 12, color: AppTheme.emerald),
                    const SizedBox(width: 5),
                    Text(
                      '${sessions.length} sessions',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: fg2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top count and clear actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${sessions.length} sessions recorded',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: fg3,
                        ),
                      ),
                      if (sessions.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: sf,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(color: bd),
                                ),
                                title: Text(
                                  'Clear History?',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg),
                                ),
                                content: Text(
                                  'Are you sure you want to remove all recorded sessions?',
                                  style: TextStyle(fontSize: 13, color: fg2),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: Text('Cancel', style: TextStyle(color: fg3)),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      state.clearHistory();
                                    },
                                    child: const Text(
                                      'Clear',
                                      style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const Text(
                            'Clear History',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                if (sessions.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 24),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: sf,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: bd),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: sf2,
                            shape: BoxShape.circle,
                            border: Border.all(color: bd),
                          ),
                          alignment: Alignment.center,
                          child: const SyncDubFlaticon(
                            assetName: 'anim_history.gif',
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No Sessions Yet',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Start live dubbing to automatically record real-time translation session logs here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: fg2, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => state.goScreen(3),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.emerald,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Start Live Dubbing'),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: sf,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: bd),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sessions.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        thickness: 1,
                        color: bd.withValues(alpha: 0.6),
                      ),
                      itemBuilder: (context, index) {
                        final s = sessions[index];

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              // Badge icon
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: sf2,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: bd),
                                ),
                                alignment: Alignment.center,
                                child: const SyncDubFlaticon(
                                  assetName: 'anim_soundwave.gif',
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Title & Meta
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.title,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: fg,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      s.meta,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: fg3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Duration
                              Text(
                                s.dur,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: fg2,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Dubbed status badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.emeraldDim,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Iconsax.tick_circle, size: 11, color: AppTheme.emerald),
                                    SizedBox(width: 3),
                                    Text(
                                      'Dubbed',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.emerald,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
