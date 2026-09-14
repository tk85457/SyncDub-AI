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

  void _showSizePicker(BuildContext context) {
    state.triggerHaptic();
    final isDark = state.isDarkMode;
    final sf = AppTheme.surface(isDark);
    final fg = AppTheme.textPrimary(isDark);
    final bd = AppTheme.border(isDark);

    showModalBottomSheet(
      context: context,
      backgroundColor: sf,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: bd,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select Overlay Size',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg),
                ),
                const SizedBox(height: 12),
                ...['Small (Compact)', 'Medium (Standard)', 'Large (Expanded)'].map((opt) {
                  final key = opt.split(' ').first;
                  final isSelected = state.overlaySize == key;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(opt, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: fg)),
                    trailing: isSelected ? const Icon(Iconsax.tick_circle, color: AppTheme.emerald, size: 20) : null,
                    onTap: () {
                      state.setOverlaySize(key);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnapPositionPicker(BuildContext context) {
    state.triggerHaptic();
    final isDark = state.isDarkMode;
    final sf = AppTheme.surface(isDark);
    final fg = AppTheme.textPrimary(isDark);
    final bd = AppTheme.border(isDark);

    showModalBottomSheet(
      context: context,
      backgroundColor: sf,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: bd,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select Dock & Snap Position',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg),
                ),
                const SizedBox(height: 12),
                ...['Bottom Right', 'Bottom Left', 'Top Right', 'Top Left'].map((pos) {
                  final isSelected = state.overlaySnapPosition == pos;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(pos, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: fg)),
                    trailing: isSelected ? const Icon(Iconsax.tick_circle, color: AppTheme.emerald, size: 20) : null,
                    onTap: () {
                      state.setOverlaySnapPosition(pos);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

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
                // 1. Interactive PiP Preview Container
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: bd),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Iconsax.video_play,
                        size: 48,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      Positioned(
                        top: 12,
                        left: 14,
                        child: Row(
                          children: [
                            Image.asset('assets/images/app_icon.png', width: 22, height: 22),
                            const SizedBox(width: 8),
                            const Text(
                              'Background Overlay Active',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.emerald.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'LIVE DUB',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xE0090D16),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${state.targetLanguage.flag} ${state.targetLanguage.name} Audio Stream',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFF8FAFC),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${state.latencyMs > 0 ? state.latencyMs : 240}ms real-time latency',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.emerald,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

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
                      Divider(height: 20, thickness: 1, color: bd),
                      InkWell(
                        onTap: () => _showSizePicker(context),
                        borderRadius: BorderRadius.circular(10),
                        child: _buildRowItem(
                          icon: Iconsax.maximize_3,
                          title: 'Overlay Size',
                          trailing: '${state.overlaySize} \u203a',
                          fg: fg,
                          fg3: fg3,
                        ),
                      ),
                      Divider(height: 20, thickness: 1, color: bd),
                      InkWell(
                        onTap: () => _showSnapPositionPicker(context),
                        borderRadius: BorderRadius.circular(10),
                        child: _buildRowItem(
                          icon: Iconsax.location,
                          title: 'Dock Position',
                          trailing: '${state.overlaySnapPosition} \u203a',
                          fg: fg,
                          fg3: fg3,
                        ),
                      ),
                      Divider(height: 20, thickness: 1, color: bd),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Show Live Dubbed Text',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: fg,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Displays translated speech subtitles in overlay',
                                  style: TextStyle(fontSize: 11, color: fg3),
                                ),
                              ],
                            ),
                          ),
                          CustomToggleSwitch(
                            value: state.showOverlayDubbedText,
                            isDark: isDark,
                            onChanged: (_) => state.toggleOverlayDubbedText(),
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
                      await FloatingOverlayManager.showOverlay(
                        isTranslating: state.isTranslating,
                        isPaused: state.isPaused,
                        targetLang: state.targetLanguage.code.toUpperCase(),
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

  Widget _buildRowItem({
    required IconData icon,
    required String title,
    required String trailing,
    required Color fg,
    required Color fg3,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 14),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
          Text(
            trailing,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.emerald),
          ),
        ],
      ),
    );
  }
}
