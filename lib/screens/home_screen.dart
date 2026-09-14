import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../models/translation_state.dart';
import '../theme/app_theme.dart';
import '../utils/app_error_handler.dart';
import '../widgets/language_picker_sheet.dart';
import '../widgets/master_connect_button.dart';
import '../widgets/motion_icon.dart';
import '../widgets/syncdub_waveform.dart';

class HomeScreen extends StatelessWidget {
  final TranslationState state;

  const HomeScreen({super.key, required this.state});

  void _openLangPicker(BuildContext context) {
    state.triggerHaptic();
    LanguagePickerSheet.show(
      context: context,
      selectedLanguage: state.targetLanguage,
      isDark: state.isDarkMode,
      onSelected: (lang) => state.setTargetLanguage(lang),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = state.isDarkMode;
    final fg = AppTheme.textPrimary(isDark);
    final fg2 = AppTheme.textSecondary(isDark);
    final fg3 = AppTheme.textMuted(isDark);
    final sf = AppTheme.surface(isDark);
    final sf2 = AppTheme.surface2(isDark);
    final bd = AppTheme.border(isDark);
    final dub = state.isTranslating;
    final connecting = state.isConnecting;
    final lang = state.targetLanguage;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top App Header with App Icon and Theme Toggle Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: bd)),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SyncDub AI',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: fg,
                      ),
                    ),
                    Text(
                      'Real-Time Live Translation',
                      style: TextStyle(fontSize: 10, color: fg3),
                    ),
                  ],
                ),
                const Spacer(),
                // Real-Time Minutes Chip (Top Header Badge - tap opens Profile & Quota)
                InkWell(
                  onTap: () {
                    state.triggerHaptic();
                    state.goScreen(5); // Open Profile & Quota screen
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTheme.emeraldDim,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Iconsax.timer_1,
                          size: 16,
                          color: AppTheme.emerald,
                        ),
                        const SizedBox(width: 6),
                        if (!state.isCreditsLoaded)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.emerald,
                            ),
                          )
                        else
                          Text(
                            '${state.creditsRemaining.toStringAsFixed(0)} min',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.emerald,
                              letterSpacing: -0.2,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Translation Pipeline Language Card
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: sf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: bd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/images/app_icon.png',
                      width: 18,
                      height: 18,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'TRANSLATION PIPELINE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: fg3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Source Box
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: sf2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: bd),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'SOURCE AUDIO',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                    color: fg3,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: state.isInternalAudioActive
                                        ? AppTheme.emerald.withValues(alpha: 0.12)
                                        : AppTheme.amber.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    state.isInternalAudioActive ? 'VIDEO' : 'MIC',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: state.isInternalAudioActive ? AppTheme.emerald : AppTheme.amber,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const SyncDubFlaticon(assetName: 'anim_translate.gif', size: 20),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Auto Detect',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: fg,
                                        ),
                                      ),
                                      Text(
                                        state.isInternalAudioActive ? 'Direct Video Stream' : 'Microphone',
                                        style: TextStyle(fontSize: 10, color: fg2),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppTheme.emeraldDim,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Iconsax.arrow_right_3, size: 14, color: AppTheme.emerald),
                      ),
                    ),

                    // Target Box
                    Expanded(
                      child: InkWell(
                        onTap: () => _openLangPicker(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: sf2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TARGET LANGUAGE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                  color: fg3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(lang.flag, style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          lang.name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: fg,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          lang.abbr,
                                          style: TextStyle(fontSize: 10, color: fg2),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Iconsax.arrow_down_1, size: 12, color: fg3),
                                ],
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

          // 4. In-Box Contextual Error Card (Handles Mic Error and Offline without separate screen)
          if (state.activeError != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: state.activeError!.type == AppErrorType.microphone
                      ? AppTheme.amber.withValues(alpha: 0.10)
                      : AppTheme.danger.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: state.activeError!.type == AppErrorType.microphone
                        ? AppTheme.amber.withValues(alpha: 0.35)
                        : AppTheme.danger.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      state.activeError!.type == AppErrorType.microphone
                          ? Iconsax.microphone_slash
                          : Iconsax.cloud_cross,
                      color: state.activeError!.type == AppErrorType.microphone
                          ? AppTheme.amber
                          : AppTheme.danger,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.activeError!.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: state.activeError!.type == AppErrorType.microphone
                                  ? AppTheme.amber
                                  : AppTheme.danger,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            state.activeError!.reason,
                            style: TextStyle(
                              fontSize: 11,
                              color: fg,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  if (state.activeError!.type == AppErrorType.microphone) {
                                    state.requestMicPermission();
                                  } else {
                                    state.retryConnection();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: state.activeError!.type == AppErrorType.microphone
                                      ? AppTheme.amber
                                      : AppTheme.danger,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  state.activeError!.recoveryAction,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () => state.clearActiveError(),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Dismiss',
                                  style: TextStyle(fontSize: 11, color: fg3),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // 5. Authentic Chrome Extension Waveform Master Connect Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: MasterConnectButton(state: state),
          ),

          // 5. Authentic Live Audio Waveform (Chrome Extension Multi-Harmonic Wave)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: sf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: bd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/images/app_icon.png',
                          width: 18,
                          height: 18,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'LIVE AUDIO WAVEFORM',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: fg3,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state.isPaused)
                          const Icon(Iconsax.pause, size: 10, color: AppTheme.amber)
                        else if (dub)
                          SyncDubLiveSoundWaveIcon(height: 10, color: AppTheme.emerald)
                        else if (connecting)
                          const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF38BDF8)))
                        else
                          const Icon(Iconsax.minus, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          state.isPaused
                              ? 'PAUSED'
                              : dub
                                  ? (state.isInternalAudioActive ? 'VIDEO AUDIO LIVE' : 'MIC STREAM LIVE')
                                  : connecting
                                      ? 'CONNECTING…'
                                      : 'Standby',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: state.isPaused
                                ? AppTheme.amber
                                : dub
                                    ? AppTheme.emerald
                                    : connecting
                                        ? const Color(0xFF38BDF8)
                                        : fg3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Chrome Extension Harmonic Sine Waveform
                SyncDubLiveWaveform(
                  isLive: dub,
                  isConnecting: connecting,
                  isPaused: state.isPaused,
                  height: 48,
                ),

                const SizedBox(height: 10),
                if (dub) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ORIGINAL AUDIO',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: fg3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.liveOriginalText,
                        style: TextStyle(
                          fontSize: 12,
                          color: fg,
                          height: 1.4,
                        ),
                      ),
                      Divider(color: bd, height: 16),
                      Text(
                        'DUBBED STREAM · ${lang.name.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: AppTheme.emerald,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.liveDubbedText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.emerald,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Tap Start Live Dubbing to monitor stream',
                        style: TextStyle(
                          fontSize: 12,
                          color: fg3,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 6. Audio Ducking & Volume Sliders (Real-time volume control)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                  'AUDIO DUCKING & BALANCE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: fg3,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Iconsax.volume_low_1, size: 16, color: fg3),
                        const SizedBox(width: 6),
                        Text('Original Audio Volume', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: fg)),
                      ],
                    ),
                    Text('${(state.originalVolume * 100).toInt()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg2)),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    activeTrackColor: fg,
                    inactiveTrackColor: bd,
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: state.originalVolume,
                    onChanged: (v) => state.setOriginalVolume(v),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Auto-Duck to 15%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: fg)),
                          const SizedBox(height: 2),
                          Text('Automatically lowers video audio when dub plays', style: TextStyle(fontSize: 11, color: fg3)),
                        ],
                      ),
                    ),
                    Switch(
                      value: state.isAutoDuckEnabled,
                      activeThumbColor: AppTheme.emerald,
                      onChanged: (_) => state.toggleAutoDuck(),
                    ),
                  ],
                ),
                Divider(color: bd, height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Iconsax.volume_high, size: 16, color: AppTheme.emerald),
                        const SizedBox(width: 6),
                        Text('Dubbed Voice Volume', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: fg)),
                      ],
                    ),
                    Text('${(state.dubbedVolume * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.emerald)),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    activeTrackColor: AppTheme.emerald,
                    inactiveTrackColor: bd,
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: state.dubbedVolume,
                    onChanged: (v) => state.setDubbedVolume(v),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 90),
        ],
      ),
    );
  }
}
