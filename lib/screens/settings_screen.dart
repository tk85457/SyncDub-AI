import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../models/translation_state.dart';
import '../theme/app_theme.dart';
import '../widgets/language_picker_sheet.dart';
import '../widgets/motion_icon.dart';

class SettingsScreen extends StatelessWidget {
  final TranslationState state;

  const SettingsScreen({
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
                  const SyncDubFlaticon(assetName: 'anim_settings.gif', size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: fg,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Quick Theme Toggle Button in Header
                  IconButton(
                    icon: Icon(
                      isDark ? Iconsax.sun_1 : Iconsax.moon,
                      size: 20,
                      color: fg,
                    ),
                    tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                    onPressed: () => state.toggleTheme(),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => state.goScreen(3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.emeraldDim,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Dashboard',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.emerald,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Audio Routing & Capture Source
                _buildSectionHeader('Audio & Input Source', fg3),
                Container(
                  decoration: BoxDecoration(
                    color: sf,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: bd),
                  ),
                  child: Column(
                    children: [
                      // Input / Capture Source (YouTube / Reels vs Mic)
                      _buildRow(
                        gifAsset: 'anim_soundwave.gif',
                        iconBg: sf2,
                        iconColor: AppTheme.emerald,
                        name: 'Capture Audio Source',
                        sub: state.preferredCaptureMode == 'internal'
                            ? 'Internal Video Audio (YouTube / Reels / OTT)'
                            : 'Microphone Loopback',
                        val: state.preferredCaptureMode == 'internal' ? 'Video' : 'Mic',
                        hasArrow: true,
                        fg: fg,
                        fg3: fg3,
                        bd: bd,
                        onTap: () => _showCaptureSourceSheet(context),
                      ),
                      Divider(height: 1, color: bd),
                      // Output Device (Fetches from physical phone in real-time)
                      _buildRow(
                        gifAsset: 'anim_speaker.gif',
                        iconBg: sf2,
                        iconColor: AppTheme.emerald,
                        name: 'Output Device',
                        sub: 'Routes voice: ${state.selectedOutputDevice.name}',
                        val: state.selectedOutputDevice.name,
                        hasArrow: true,
                        fg: fg,
                        fg3: fg3,
                        bd: bd,
                        onTap: () => _showOutputDeviceSheet(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Translation Language Section
                _buildSectionHeader('Translation Language', fg3),
                Container(
                  decoration: BoxDecoration(
                    color: sf,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: bd),
                  ),
                  child: Column(
                    children: [
                      _buildRow(
                        gifAsset: 'anim_translate.gif',
                        iconBg: sf2,
                        iconColor: AppTheme.emerald,
                        name: 'Default Target Language',
                        sub: '${state.targetLanguage.flag} ${state.targetLanguage.name}',
                        val: state.targetLanguage.name,
                        hasArrow: true,
                        fg: fg,
                        fg3: fg3,
                        bd: bd,
                        onTap: () {
                          LanguagePickerSheet.show(
                            context: context,
                            selectedLanguage: state.targetLanguage,
                            isDark: isDark,
                            onSelected: (lang) => state.setTargetLanguage(lang),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. App Preferences (Floating Overlay & Theme)
                _buildSectionHeader('App Preferences', fg3),
                Container(
                  decoration: BoxDecoration(
                    color: sf,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: bd),
                  ),
                  child: Column(
                    children: [
                      // Floating Overlay Toggle (Moved from Home Screen)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: sf2,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              alignment: Alignment.center,
                              child: const SyncDubFlaticon(assetName: 'anim_soundwave.gif', size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Floating Dubbing Icon',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: fg,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'Overlay icon on other apps, docks after 30s',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: fg3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: state.isFloatingEnabled,
                              activeThumbColor: AppTheme.emerald,
                              onChanged: (_) => state.toggleFloating(),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, thickness: 1, color: bd),

                      // PiP Overlay & Docking Configuration Screen Link
                      _buildRow(
                        gifAsset: 'anim_soundwave.gif',
                        iconBg: sf2,
                        iconColor: const Color(0xFF0284C7),
                        name: 'PiP Overlay & Compatible Apps',
                        sub: 'Size: ${state.overlaySize} · Dock: ${state.overlaySnapPosition}',
                        val: 'Configure',
                        valColor: const Color(0xFF0284C7),
                        hasArrow: true,
                        fg: fg,
                        fg3: fg3,
                        bd: bd,
                        onTap: () => state.goScreen(4), // Screen 4: PipOverlayScreen
                      ),

                      Divider(height: 1, thickness: 1, color: bd),

                      // Theme Toggle Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: sf2,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                isDark ? Iconsax.moon : Iconsax.sun_1,
                                size: 18,
                                color: isDark ? const Color(0xFF818CF8) : const Color(0xFFF59E0B),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dark Mode',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: fg,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    isDark ? 'Dark theme active' : 'Light theme active (Default)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: fg3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: isDark,
                              activeThumbColor: AppTheme.emerald,
                              onChanged: (_) => state.toggleTheme(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 5. Subscription Section
                _buildSectionHeader('Subscription & Real-Time Balance', fg3),
                Container(
                  decoration: BoxDecoration(
                    color: sf,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: bd),
                  ),
                  child: _buildRow(
                    gifAsset: 'anim_rocket.gif',
                    iconBg: AppTheme.amber.withValues(alpha: 0.12),
                    iconColor: AppTheme.amber,
                    name: 'Live Dubbing Quota',
                    sub: state.isCreditsLoaded
                        ? '${state.creditsRemaining.toStringAsFixed(0)} minutes available for real-time translation'
                        : 'Loading translation quota...',
                    val: 'Upgrade',
                    valColor: AppTheme.amber,
                    hasArrow: true,
                    fg: fg,
                    fg3: fg3,
                    bd: bd,
                    onTap: () => state.goScreen(6), // Screen 6: Paywall
                  ),
                ),
                const SizedBox(height: 16),

                // 6. About Section
                _buildSectionHeader('About', fg3),
                Container(
                  decoration: BoxDecoration(
                    color: sf,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: bd),
                  ),
                  child: Column(
                    children: [
                      _buildRow(
                        gifAsset: 'anim_shield.gif',
                        iconBg: sf2,
                        iconColor: AppTheme.emerald,
                        name: 'Privacy Policy',
                        sub: 'Zero-audio retention guarantee',
                        val: '',
                        hasArrow: true,
                        fg: fg,
                        fg3: fg3,
                        bd: bd,
                        onTap: () => _showPrivacyDialog(context, sf, bd, fg, fg2),
                      ),
                      Divider(height: 1, thickness: 1, color: bd),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/images/app_icon.png',
                              width: 28,
                              height: 28,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SyncDub Version',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: fg,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'v2.5.0 (Production Build)',
                                    style: TextStyle(fontSize: 11, color: fg3),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.emeraldDim,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Latest',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.emerald,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Bottom Sheet Modals for Settings ───────────────────────────────

  /// Audio Capture Source Bottom Sheet (Internal Video Audio vs Mic)
  void _showCaptureSourceSheet(BuildContext context) {
    state.triggerHaptic();
    final isDark = state.isDarkMode;
    final fg = AppTheme.textPrimary(isDark);
    final fg2 = AppTheme.textSecondary(isDark);
    final fg3 = AppTheme.textMuted(isDark);
    final bd = AppTheme.border(isDark);
    final sf = AppTheme.surface(isDark);
    final sf2 = AppTheme.surfaceElevated(isDark);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: sf,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: bd),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: fg3.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const SyncDubFlaticon(assetName: 'anim_soundwave.gif', size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Audio Capture Source',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Select how SyncDub AI captures audio to translate in real-time.',
                style: TextStyle(fontSize: 12, color: fg2),
              ),
              const SizedBox(height: 16),
              // Option 1: Direct Video Audio (Recommended)
              _buildSourceTile(
                ctx: ctx,
                title: 'Internal Video Audio',
                badge: 'RECOMMENDED',
                subtitle: 'Direct digital capture from YouTube, Instagram Reels, Netflix, and browsers. Zero room noise, full headphones support.',
                icon: Iconsax.video_play,
                isSelected: state.preferredCaptureMode == 'internal',
                onTap: () {
                  state.setPreferredCaptureMode('internal');
                  Navigator.pop(ctx);
                },
                fg: fg,
                fg2: fg2,
                sf2: sf2,
                bd: bd,
              ),
              const SizedBox(height: 10),
              // Option 2: Microphone
              _buildSourceTile(
                ctx: ctx,
                title: 'Microphone Loopback',
                badge: null,
                subtitle: 'Translates speech spoken into phone microphone or external headset mic.',
                icon: Iconsax.microphone,
                isSelected: state.preferredCaptureMode == 'mic',
                onTap: () {
                  state.setPreferredCaptureMode('mic');
                  Navigator.pop(ctx);
                },
                fg: fg,
                fg2: fg2,
                sf2: sf2,
                bd: bd,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSourceTile({
    required BuildContext ctx,
    required String title,
    required String? badge,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color fg,
    required Color fg2,
    required Color sf2,
    required Color bd,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.emeraldDim : sf2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.emerald : bd,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.emerald.withValues(alpha: 0.15) : bd.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: isSelected ? AppTheme.emerald : fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: fg,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppTheme.emerald,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'RECOMMENDED',
                            style: TextStyle(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: fg2, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isSelected)
              const Icon(Iconsax.tick_circle, color: AppTheme.emerald, size: 20),
          ],
        ),
      ),
    );
  }

  /// 1. Output Device Bottom Sheet (Queries physical phone devices live)
  void _showOutputDeviceSheet(BuildContext context) {
    state.triggerHaptic();
    state.refreshOutputDevices();

    final isDark = state.isDarkMode;
    final sf = AppTheme.surface(isDark);
    final fg = AppTheme.textPrimary(isDark);
    final fg3 = AppTheme.textMuted(isDark);
    final bd = AppTheme.border(isDark);
    final sf2 = AppTheme.surface2(isDark);

    showModalBottomSheet(
      context: context,
      backgroundColor: sf,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return ListenableBuilder(
          listenable: state,
          builder: (context, _) {
            final devices = state.availableOutputDevices;
            final current = state.selectedOutputDevice;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: bd,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Output Device',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: fg,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Iconsax.refresh, size: 20, color: AppTheme.emerald),
                          tooltip: 'Rescan Phone Devices',
                          onPressed: () => state.refreshOutputDevices(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Detected in real-time from your phone hardware',
                      style: TextStyle(fontSize: 12, color: fg3),
                    ),
                    const SizedBox(height: 16),
                    ...devices.map((dev) {
                      final isSelected = dev.id == current.id || dev.name == current.name;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.emeraldDim : AppTheme.surfaceElevated(isDark),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? AppTheme.emerald : bd,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.emeraldDim : sf2,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              dev.iconData,
                              size: 18,
                              color: isSelected ? AppTheme.emerald : fg,
                            ),
                          ),
                          title: Text(
                            dev.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: fg,
                            ),
                          ),
                          subtitle: Text(
                            dev.type.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? AppTheme.emerald : fg3,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Iconsax.tick_circle, color: AppTheme.emerald, size: 22)
                              : null,
                          onTap: () {
                            state.selectOutputDevice(dev);
                            Navigator.pop(ctx);
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Helper Builders ────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, Color fg3) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: fg3,
        ),
      ),
    );
  }

  Widget _buildRow({
    IconData? icon,
    String? gifAsset,
    required Color iconBg,
    required Color iconColor,
    required String name,
    required String sub,
    required String val,
    Color? valColor,
    required bool hasArrow,
    required Color fg,
    required Color fg3,
    required Color bd,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: gifAsset != null
                  ? SyncDubFlaticon(assetName: gifAsset, size: 20)
                  : Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 11,
                      color: fg3,
                    ),
                  ),
                ],
              ),
            ),
            if (val.isNotEmpty) ...[
              Text(
                val,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valColor ?? fg3,
                ),
              ),
              const SizedBox(width: 4),
            ],
            if (hasArrow)
              Icon(
                Iconsax.arrow_right_3,
                size: 16,
                color: fg3,
              ),
          ],
        ),
      ),
    );
  }


  void _showPrivacyDialog(BuildContext context, Color sf, Color bd, Color fg, Color fg2) {
    state.triggerHaptic();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: sf,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: bd),
        ),
        title: Row(
          children: [
            const Icon(Iconsax.shield_tick, color: AppTheme.emerald, size: 22),
            const SizedBox(width: 8),
            Text('Privacy Guarantee', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg)),
          ],
        ),
        content: Text(
          'SyncDub AI operates strictly in ephemeral real-time stream mode. Incoming and dubbed PCM audio chunks are processed in-memory and immediately discarded. No audio recordings or voice files are stored on any server.',
          style: TextStyle(fontSize: 13, color: fg2, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it', style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
