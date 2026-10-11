import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../models/translation_state.dart';
import '../services/floating_overlay_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_toggle_switch.dart';

class PipOverlayScreen extends StatelessWidget {
  final TranslationState state;

  const PipOverlayScreen({
    super.key,
    required this.state,
  });


  @override
  Widget build(BuildContext context) {
    final isDark = state.isDarkMode;
    final fg = AppTheme.textPrimary(isDark);
    final fg3 = AppTheme.textMuted(isDark);
    final bd = AppTheme.border(isDark);
    final sf = AppTheme.surface(isDark);

    const compatibleApps = [
      'YouTube & YouTube Shorts',
      'Instagram Reels & Stories',
      'Netflix & Prime Video (Browser)',
      'Twitch & Kick Live Streams',
      'Twitter / X Video Posts',
      'Chrome & Mobile Web Browsers',
    ];

    return Column(
      children: [
        // App Nav Bar with Back button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: bd)),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () => state.handleBackPress(),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_ios_new, size: 14, color: AppTheme.emerald),
                      SizedBox(width: 4),
                      Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.emerald,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'PiP Overlay & Apps',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [


                // 2. Overlay Settings Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: sf,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: bd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OVERLAY PREFERENCES',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: fg3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Enable Floating Overlay',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: fg,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Display interactive dubbing controls over any app',
                                  style: TextStyle(fontSize: 11, color: fg3),
                                ),
                              ],
                            ),
                          ),
                          CustomToggleSwitch(
                            value: state.isFloatingEnabled,
                            isDark: isDark,
                            onChanged: (_) => state.toggleFloating(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Test Overlay Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      state.triggerHaptic();
                      if (!state.isTranslating) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Start live dubbing on the Home tab first to launch the floating overlay.'),
                              backgroundColor: AppTheme.amber,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                        return;
                      }
                      await FloatingOverlayManager.showOverlay(
                        isTranslating: state.isTranslating,
                        isPaused: state.isPaused,
                        targetLang: state.targetLanguage.abbr,
                        targetLangFlag: state.targetLanguage.flag,
                        targetLangName: state.targetLanguage.name,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Floating Overlay launched over screen.'),
                            backgroundColor: AppTheme.emerald,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Iconsax.layer, size: 18, color: AppTheme.emerald),
                    label: const Text(
                      'Preview Floating Overlay on Screen',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.emerald),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.emerald, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Compatible Apps Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: sf,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: bd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TESTED COMPATIBLE APPS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: fg3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...compatibleApps.asMap().entries.map((entry) {
                        final i = entry.key;
                        final app = entry.value;

                        return Column(
                          children: [
                            if (i > 0)
                              Divider(height: 14, thickness: 1, color: bd.withValues(alpha: 0.5)),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    app,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: fg,
                                    ),
                                  ),
                                  const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Iconsax.tick_circle, size: 13, color: AppTheme.emerald),
                                      SizedBox(width: 4),
                                      Text(
                                        'Verified',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.emerald,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
