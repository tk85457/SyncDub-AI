import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../models/translation_state.dart';
import '../theme/app_theme.dart';
import '../widgets/motion_icon.dart';

class ProfileScreen extends StatefulWidget {
  final TranslationState state;

  const ProfileScreen({super.key, required this.state});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isRefreshing = false;

  Future<void> _refreshRealtimeData() async {
    setState(() => _isRefreshing = true);
    widget.state.triggerHaptic();
    await widget.state.checkBackendHealth();
    if (mounted) {
      setState(() => _isRefreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Real-time profile and quota synchronized'),
          duration: const Duration(milliseconds: 1400),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.emerald,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showLegalDialog(String title, String content) {
    widget.state.triggerHaptic();
    final isDark = widget.state.isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.border(isDark)),
        ),
        title: Row(
          children: [
            const Icon(Iconsax.shield_tick, color: AppTheme.emerald, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary(isDark),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary(isDark),
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Understood',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.emerald),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final isDark = state.isDarkMode;
    final bg = AppTheme.bg(isDark);
    final fg = AppTheme.textPrimary(isDark);
    final fg2 = AppTheme.textSecondary(isDark);
    final fg3 = AppTheme.textMuted(isDark);
    final sf = AppTheme.surface(isDark);
    final sf2 = AppTheme.surface2(isDark);
    final bd = AppTheme.border(isDark);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Bar: App Logo + Title on Left, Refresh on Right (No Back Button)
              Row(
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
                        'Profile & Account',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: fg,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: _isRefreshing ? null : _refreshRealtimeData,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: sf2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: bd),
                      ),
                      alignment: Alignment.center,
                      child: _isRefreshing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.emerald,
                              ),
                            )
                          : Icon(Iconsax.refresh, size: 18, color: fg2),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 2. User Identity Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: sf,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: bd),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3), width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: state.userAvatarUrl != null
                            ? Image.network(
                                state.userAvatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Image.asset(
                                  'assets/images/app_icon.png',
                                  fit: BoxFit.contain,
                                ),
                              )
                            : Image.asset(
                                'assets/images/app_icon.png',
                                fit: BoxFit.contain,
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  state.userName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: fg,
                                    letterSpacing: -0.3,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const SyncDubFlaticon(assetName: 'anim_verified.gif', size: 16),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            state.userEmail ?? 'Connected Google Account',
                            style: TextStyle(
                              fontSize: 12,
                              color: fg2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.emeraldDim,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Iconsax.verify, size: 12, color: AppTheme.emerald),
                                const SizedBox(width: 4),
                                Text(
                                  'VERIFIED ACCOUNT',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.emerald,
                                    letterSpacing: 0.5,
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

              const SizedBox(height: 16),

              // 3. Real-Time Minutes & Quota Card (Realtime Data Display)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                        : [const Color(0xFFF8FAFC), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
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
                            const SyncDubFlaticon(assetName: 'anim_rocket.gif', size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Live Dubbing Quota',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: fg,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.emerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'LIVE SYNC',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.emerald,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          state.isCreditsLoaded
                              ? state.creditsRemaining.toStringAsFixed(1)
                              : '...',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: fg,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Minutes Remaining',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.emerald,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Visual progress indicator
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (state.creditsRemaining / 3000.0).clamp(0.05, 1.0),
                        minHeight: 6,
                        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.emerald),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Completed Sessions: ${state.historySessions.length}',
                          style: TextStyle(fontSize: 12, color: fg3),
                        ),
                        InkWell(
                          onTap: () {
                            state.triggerHaptic();
                            state.goScreen(6); // Open Paywall/Subscription
                          },
                          child: const Text(
                            '+ Add Minutes',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.emerald,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 4. Subscription & Plans Section
              Text(
                'SUBSCRIPTION & BILLING',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: fg3,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: sf,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: bd),
                ),
                child: Column(
                  children: [
                    _buildSettingsTile(
                      icon: Iconsax.crown,
                      iconColor: const Color(0xFFF59E0B),
                      title: 'Manage Subscription',
                      subtitle: state.isCreditsLoaded
                          ? '${state.creditsRemaining.toStringAsFixed(0)} live minutes available'
                          : 'Syncing subscription quota...',
                      trailing: Icon(Iconsax.arrow_right_3, size: 16, color: fg3),
                      onTap: () {
                        state.triggerHaptic();
                        state.goScreen(6);
                      },
                    ),
                    Divider(height: 1, color: bd),
                    _buildSettingsTile(
                      icon: Iconsax.card,
                      iconColor: const Color(0xFF6366F1),
                      title: 'View All Plans & Add-ons',
                      subtitle: 'Explore unlimited real-time translation tiers',
                      trailing: Icon(Iconsax.arrow_right_3, size: 16, color: fg3),
                      onTap: () {
                        state.triggerHaptic();
                        state.goScreen(6);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 5. Legal & Privacy Buttons
              Text(
                'LEGAL & TRANSPARENCY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: fg3,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: sf,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: bd),
                ),
                child: Column(
                  children: [
                    _buildSettingsTile(
                      icon: Iconsax.shield_tick,
                      iconColor: AppTheme.emerald,
                      title: 'Privacy Policy',
                      subtitle: 'Zero audio storage & ephemeral stream guarantee',
                      trailing: Icon(Iconsax.arrow_right_3, size: 16, color: fg3),
                      onTap: () => _showLegalDialog(
                        'Privacy Policy',
                        'SyncDub AI operates on a strict zero-retention ephemeral privacy architecture.\n\n'
                        '1. Audio Processing: Your microphone and device audio are processed strictly in-memory over an encrypted TLS WebSocket stream to generate real-time dubbing. Once translated, audio buffers are instantly cleared from RAM.\n\n'
                        '2. Zero Audio Recordings: SyncDub AI never records, saves, archives, or analyzes your voice for AI training. No audio files are ever stored on any server.\n\n'
                        '3. Account Data: Only your email and chosen subscription tier are retained to manage account authentication and quota.',
                      ),
                    ),
                    Divider(height: 1, color: bd),
                    _buildSettingsTile(
                      icon: Iconsax.document_text,
                      iconColor: const Color(0xFF0284C7),
                      title: 'Terms of Service',
                      subtitle: 'Usage guidelines and subscription agreements',
                      trailing: Icon(Iconsax.arrow_right_3, size: 16, color: fg3),
                      onTap: () => _showLegalDialog(
                        'Terms of Service',
                        'By using SyncDub AI, you agree to our standard terms:\n\n'
                        '1. Service Availability: SyncDub AI provides sub-300ms real-time dubbing powered by the Gemini 3.5 Live translation pipeline.\n\n'
                        '2. Permitted Use: You are authorized to use SyncDub AI for personal translation across YouTube, social videos, and live media.\n\n'
                        '3. Subscriptions & Quotas: Subscriptions are billed per your selected billing cycle. Quotas are refreshed automatically at renewal.',
                      ),
                    ),
                    Divider(height: 1, color: bd),
                    _buildSettingsTile(
                      icon: Iconsax.lock,
                      iconColor: const Color(0xFF8B5CF6),
                      title: 'Security & Encryption',
                      subtitle: 'End-to-end TLS 1.3 socket transmission',
                      trailing: Icon(Iconsax.arrow_right_3, size: 16, color: fg3),
                      onTap: () => _showLegalDialog(
                        'Security & Encryption',
                        'All sound streams sent to SyncDub servers are secured using 256-bit TLS 1.3 cryptographic transport. Audio buffers are isolated per user session with instant ephemeral teardown upon session termination.',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 6. Fast Sign Out Button
              InkWell(
                onTap: () async {
                  final shouldSignOut = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: sf,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: bd),
                      ),
                      title: Text(
                        'Sign Out?',
                        style: TextStyle(fontWeight: FontWeight.w800, color: fg),
                      ),
                      content: Text(
                        'Are you sure you want to sign out of SyncDub AI?',
                        style: TextStyle(color: fg2, fontSize: 13),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('Cancel', style: TextStyle(color: fg3)),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.danger,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  );

                  if (shouldSignOut == true) {
                    await state.handleSignOut();
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.danger.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Iconsax.logout, size: 18, color: AppTheme.danger),
                      SizedBox(width: 10),
                      Text(
                        'Sign Out',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Footer App Version
              Center(
                child: Text(
                  'SyncDub AI v2.4.0 (Production Release)',
                  style: TextStyle(fontSize: 11, color: fg3),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    final isDark = widget.state.isDarkMode;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary(isDark),
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
