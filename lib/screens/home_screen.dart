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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Top App Header with App Icon and Theme Toggle Button (PINNED AT THE TOP ON ALL PHONES)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: sf,
            border: Border(bottom: BorderSide(color: bd)),
          ),
          child: Row(
            children: [
              Image.asset(
                'assets/images/app_icon.webp',
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        size: 15,
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

        // Scrollable content below pinned header
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. Translation Pipeline Language Card
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.all(13),
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
                            'assets/images/app_icon.webp',
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
                                const SyncDubFlaticon(assetName: 'anim_translate.webp', size: 20),
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
                                           state.isSwitchingLanguage ? 'Reconnecting…' : lang.abbr,
                                           style: TextStyle(
                                             fontSize: 10,
                                             color: state.isSwitchingLanguage ? AppTheme.emerald : fg2,
                                             fontWeight: state.isSwitchingLanguage ? FontWeight.w700 : FontWeight.w500,
                                           ),
                                         ),
                                       ],
                                     ),
                                   ),
                                   if (state.isSwitchingLanguage)
                                     const SizedBox(
                                       width: 12,
                                       height: 12,
                                       child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.emerald),
                                     )
                                   else
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(13),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: MasterConnectButton(state: state),
          ),

          // 5. Authentic Live Audio Waveform (Chrome Extension Multi-Harmonic Wave)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(13),
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
                          'assets/images/app_icon.webp',
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
                          const Icon(
                            Iconsax.pause,
                            size: 10,
                            color: AppTheme.amber,
                          )
                        else if (dub)
                          SyncDubLiveSoundWaveIcon(height: 10, color: AppTheme.emerald)
                        else if (connecting)
                          const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF38BDF8)))
                        else
                          const Icon(Iconsax.minus, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          state.isAutoPaused
                              ? 'SILENCE · PAUSED'
                              : state.isPaused
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
              ],
            ),
          ),

          // 6. Audio Balance & Volume Sliders (Real-time volume control)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: sf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: bd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AUDIO BALANCE & VOLUME',
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
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            state.originalVolume <= 0.05
                                ? Iconsax.volume_cross
                                : (state.originalVolume < 0.60
                                    ? Iconsax.volume_low_1
                                    : Iconsax.volume_high),
                            size: 16,
                            color: state.originalVolume <= 0.05
                                ? AppTheme.danger
                                : (state.originalVolume < 0.60
                                    ? AppTheme.amber
                                    : AppTheme.emerald),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Original Video Audio',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: fg),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(state.originalVolume * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: state.originalVolume <= 0.05
                                ? AppTheme.danger
                                : (state.originalVolume < 0.60
                                    ? AppTheme.amber
                                    : AppTheme.emerald),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (state.originalVolume <= 0.05
                                    ? AppTheme.danger
                                    : (state.originalVolume < 0.60
                                        ? AppTheme.amber
                                        : AppTheme.emerald))
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: (state.originalVolume <= 0.05
                                      ? AppTheme.danger
                                      : (state.originalVolume < 0.60
                                          ? AppTheme.amber
                                          : AppTheme.emerald))
                                  .withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            state.originalVolume <= 0.05
                                ? 'Off (0%)'
                                : (state.originalVolume < 0.60
                                    ? 'Ducked (~20%)'
                                    : 'Full (100%)'),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: state.originalVolume <= 0.05
                                  ? AppTheme.danger
                                  : (state.originalVolume < 0.60
                                      ? AppTheme.amber
                                      : AppTheme.emerald),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    activeTrackColor: state.originalVolume <= 0.05
                        ? AppTheme.danger
                        : (state.originalVolume < 0.60
                            ? AppTheme.amber
                            : AppTheme.emerald),
                    inactiveTrackColor: bd,
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: state.originalVolume.clamp(0.0, 1.0),
                    min: 0.0,
                    max: 1.0,
                    onChanged: (v) => state.setOriginalVolume(v),
                    onChangeEnd: (v) => state.persistOriginalVolume(v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 1, bottom: 2),
                  child: Text(
                    state.originalVolume <= 0.05
                        ? '0% - 5%: Original video audio is off so dubbed voice is heard alone.'
                        : (state.originalVolume < 0.60
                            ? '5% - 60%: Active video audio is ducked to background (~20%) so dubbed voice is clear.'
                            : '60% - 100%: Original video plays at full volume alongside dubbed voice.'),
                    style: TextStyle(fontSize: 10.5, color: fg3, height: 1.25),
                  ),
                ),
                Divider(color: bd, height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Iconsax.volume_high, size: 16, color: AppTheme.emerald),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Dubbed Voice Volume',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: fg),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${(state.dubbedVolume * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.emerald)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: state.dubbedVolume == 0.0
                                ? AppTheme.danger.withValues(alpha: 0.12)
                                : AppTheme.emerald.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: state.dubbedVolume == 0.0
                                  ? AppTheme.danger.withValues(alpha: 0.3)
                                  : AppTheme.emerald.withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            state.dubbedVolume == 0.0 ? 'Muted' : 'Real-Time',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: state.dubbedVolume == 0.0 ? AppTheme.danger : AppTheme.emerald,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                    value: state.dubbedVolume.clamp(0.0, 1.0),
                    min: 0.0,
                    max: 1.0,
                    onChanged: (v) => state.setDubbedVolume(v),
                    onChangeEnd: (v) => state.persistDubbedVolume(v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 1, bottom: 2),
                  child: Text(
                    'Changes the dubbed voice loudness instantly, even while it is speaking.',
                    style: TextStyle(fontSize: 10, color: fg3, height: 1.25),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 60),
        ],
      ),
    ),
  ),
],
);
  }
}
