import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../models/translation_state.dart';
import '../theme/app_theme.dart';

class PaywallScreen extends StatelessWidget {
  final TranslationState state;

  const PaywallScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final isDark = state.isDarkMode;
    final fg = AppTheme.textPrimary(isDark);
    final fg2 = AppTheme.textSecondary(isDark);
    final fg3 = AppTheme.textMuted(isDark);
    final sf = AppTheme.surface(isDark);
    final sf2 = AppTheme.surface2(isDark);
    final bd = AppTheme.border(isDark);
    final isYearly = state.billingCycle == 'yearly';
    final sel = state.selectedPlan;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // App Nav Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () => state.goScreen(3), // Back to Home
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
                Text(
                  'Upgrade',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),
          Divider(color: bd, height: 1),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                // Hero
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldDim,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Iconsax.flash_1, size: 12, color: AppTheme.emerald),
                      SizedBox(width: 4),
                      Text(
                        'SYNC DUB PRO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.emerald,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Unlimited Live Dubbing',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: fg,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Break the 45-minute limit. Instant real-time neural translation with zero delay.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: fg2,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),

                // Billing Cycle Toggle
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: sf2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: bd),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => state.setBillingCycle('monthly'),
                          borderRadius: BorderRadius.circular(9),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !isYearly ? (isDark ? const Color(0xFF090D16) : Colors.white) : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: !isYearly ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)] : [],
                            ),
                            child: Center(
                              child: Text(
                                'Monthly Billing',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: !isYearly ? fg : fg3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => state.setBillingCycle('yearly'),
                          borderRadius: BorderRadius.circular(9),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isYearly ? (isDark ? const Color(0xFF090D16) : Colors.white) : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: isYearly ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)] : [],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Annual',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isYearly ? fg : fg3,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.emeraldDim,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'SAVE 25%',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.emerald,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Plan Cards
                _buildPlanCard(
                  title: 'Starter (Current)',
                  price: '₹0',
                  unit: '/ mo',
                  desc: '45 mins/month · 320ms latency · Standard translation',
                  isSelected: sel == 0,
                  badge: null,
                  onTap: () => state.selectPlan(0),
                  sf: sf,
                  bd: bd,
                  fg: fg,
                  fg3: fg3,
                ),
                const SizedBox(height: 10),
                _buildPlanCard(
                  title: 'SyncDub Pro',
                  price: isYearly ? '₹599' : '₹799',
                  unit: '/ mo',
                  desc: 'Unlimited dubbing · Sub-200ms latency · Dedicated GPU nodes',
                  isSelected: sel == 1,
                  badge: 'MOST POPULAR',
                  onTap: () => state.selectPlan(1),
                  sf: sf,
                  bd: bd,
                  fg: fg,
                  fg3: fg3,
                ),
                const SizedBox(height: 10),
                _buildPlanCard(
                  title: 'Creator Studio',
                  price: isYearly ? '₹1,499' : '₹1,999',
                  unit: '/ mo',
                  desc: 'Studio acoustic precision · Multi-track system audio · Priority VIP',
                  isSelected: sel == 2,
                  badge: null,
                  onTap: () => state.selectPlan(2),
                  sf: sf,
                  bd: bd,
                  fg: fg,
                  fg3: fg3,
                ),
                const SizedBox(height: 16),

                // Feature Matrix Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: sf,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: bd),
                  ),
                  child: Column(
                    children: [
                      _buildFeatureRow('Unlimited Live Minutes: No session timeouts', fg),
                      const SizedBox(height: 8),
                      _buildFeatureRow('Sub-200ms Ultra-Low Latency: Direct priority stream', fg),
                      const SizedBox(height: 8),
                      _buildFeatureRow('Neural Audio Pipeline: Ultra-clear real-time translated audio', fg),
                      const SizedBox(height: 8),
                      _buildFeatureRow('Multi-Track Audio Loopback: Dub YouTube, Reels & Calls', fg),
                      const SizedBox(height: 8),
                      _buildFeatureRow('Background Floating PiP: Dub over any app', fg),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // CTA Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      state.triggerHaptic();
                      await state.activateSubscription();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${state.userPlan} Activated! ${state.creditsRemaining.toStringAsFixed(0)} minutes added.',
                            ),
                            backgroundColor: AppTheme.emerald,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                        state.goScreen(3);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      foregroundColor: isDark ? const Color(0xFF090D16) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Start 7-Day Free Trial',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Cancel anytime in App Store · Zero commitment',
                  style: TextStyle(
                    fontSize: 11,
                    color: fg3,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String unit,
    required String desc,
    required bool isSelected,
    required String? badge,
    required VoidCallback onTap,
    required Color sf,
    required Color bd,
    required Color fg,
    required Color fg3,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.emeraldDim : sf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppTheme.emerald : bd,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? AppTheme.emerald : fg,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          price,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: fg,
                          ),
                        ),
                        Text(
                          ' $unit',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: fg3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11,
                    color: fg3,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            top: -9,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.emerald,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFeatureRow(String text, Color fg) {
    return Row(
      children: [
        const Icon(
          Iconsax.tick_circle,
          size: 16,
          color: AppTheme.emerald,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: fg,
            ),
          ),
        ),
      ],
    );
  }
}
