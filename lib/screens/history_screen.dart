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

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

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
                    'assets/images/app_icon.webp',
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Dubbing History',
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
                      '${sessions.length} ${sessions.length == 1 ? 'session' : 'sessions'}',
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
                        '${sessions.length} dubbing ${sessions.length == 1 ? 'session' : 'sessions'} saved',
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
                            assetName: 'anim_history.webp',
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No Translation History Yet',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Start live dubbing in Floating Mode or In-App to build your personal translation history.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: fg2, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => state.goScreen(3), // Open Home
                          icon: const Icon(Iconsax.translate, size: 16),
                          label: const Text('Start Live Translation'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.emerald,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sessions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final s = sessions[index];
                      final thumbUrl = s.effectiveThumbnailUrl;

                      return _buildHistoryVideoCard(
                        context: context,
                        session: s,
                        thumbUrl: thumbUrl,
                        timeAgo: _formatTimeAgo(s.timestamp),
                        sf: sf,
                        sf2: sf2,
                        bd: bd,
                        fg: fg,
                        fg2: fg2,
                        fg3: fg3,
                      );
                    },
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Modern video card representation: 16:9 thumbnail + duration pill + title + platform badge + dub info + 3-dot menu
  Widget _buildHistoryVideoCard({
    required BuildContext context,
    required HistorySession session,
    required String? thumbUrl,
    required String timeAgo,
    required Color sf,
    required Color sf2,
    required Color bd,
    required Color fg,
    required Color fg2,
    required Color fg3,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: sf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              // 1. Video Thumbnail (16:9 ratio, rounded corners) with duration badge
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 114,
                      height: 64,
                      child: thumbUrl != null
                          ? Image.network(
                              thumbUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, error, stack) => Container(
                                color: sf2,
                                child: const Center(
                                  child: Icon(Iconsax.video_play, color: AppTheme.emerald, size: 28),
                                ),
                              ),
                            )
                          : Container(
                              color: sf2,
                              child: const Center(
                                child: Icon(Iconsax.video_play, color: AppTheme.emerald, size: 26),
                              ),
                            ),
                    ),
                  ),

                  // Duration pill on bottom right
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        session.dur,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // 2. Video Title, Platform Badge, Dubbed Language, and Timestamp
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: fg,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Platform & Dubbing Meta Row
                    Row(
                      children: [
                        // Platform logo badge
                        if (session.platform != null && session.platform!.isNotEmpty) ...[
                          Text(
                            session.platform!,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.emerald,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text('•', style: TextStyle(fontSize: 10, color: fg3)),
                          const SizedBox(width: 5),
                        ],

                        // Dubbed info
                        Flexible(
                          child: Text(
                            session.targetLang != null
                                ? 'Dubbed in ${session.targetLang}'
                                : (session.meta.contains('Dubbed') ? session.meta : 'Live Dubbing'),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.emerald,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Relative Time
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 10,
                        color: fg3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
}
