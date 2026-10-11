import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../models/translation_state.dart';
import '../services/revenue_cat_service.dart';
import '../theme/app_theme.dart';

/// 100% Dynamic Paywall Screen powered by RevenueCat.
/// All products, prices, and descriptions are fetched live from RevenueCat & Google Play.
/// Zero hardcoded listings.
class PaywallScreen extends StatefulWidget {
  final TranslationState state;

  const PaywallScreen({super.key, required this.state});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Fetch latest offerings on enter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RevenueCatService().fetchOfferings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final isDark = state.isDarkMode;
    final fg = AppTheme.textPrimary(isDark);
    final fg2 = AppTheme.textSecondary(isDark);
    final fg3 = AppTheme.textMuted(isDark);
    final sf = AppTheme.surface(isDark);
    final sf2 = AppTheme.surface2(isDark);
    final bd = AppTheme.border(isDark);
    final rc = RevenueCatService();

    return ListenableBuilder(
      listenable: rc,
      builder: (context, _) {
        final packages = rc.availablePackages;
        final isLoading = rc.isLoading;
        final selectedPkg = (packages.isNotEmpty && _selectedIndex < packages.length)
            ? packages[_selectedIndex]
            : (packages.isNotEmpty ? packages.first : null);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Navigation Bar
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
                      'Recharge Minutes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                    // Restore Purchases Action
                    InkWell(
                      onTap: () async {
                        state.triggerHaptic();
                        final info = await rc.restorePurchases();
                        if (context.mounted) {
                          final hasPro = info?.entitlements.active.containsKey(RevenueCatService.entitlementPro) ?? false;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                hasPro
                                    ? 'Purchases Restored! Active Pro Entitlement verified.'
                                    : 'Restore completed. No previous active subscriptions found.',
                              ),
                              backgroundColor: hasPro ? AppTheme.emerald : Colors.blueGrey,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                        child: Text(
                          'Restore',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.emerald,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: bd, height: 1),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    // Hero Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.emeraldDim,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Iconsax.flash_1, size: 12, color: AppTheme.emerald),
                          SizedBox(width: 4),
                          Text(
                            'REVENUECAT LIVE CATALOG',
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
                      'Minutes That Never Expire',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: fg,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Buy once, use whenever you watch. Live packages synced from RevenueCat & Google Play.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: fg2,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Current Balance Ribbon
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sf2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: bd),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Your Current Balance:',
                            style: TextStyle(fontSize: 12, color: fg3, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${state.creditsRemaining.toStringAsFixed(0)} Mins',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.emerald,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dynamic Package List from RevenueCat
                    if (isLoading && packages.isEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            const CircularProgressIndicator(color: AppTheme.emerald),
                            const SizedBox(height: 16),
                            Text(
                              'Fetching live packages from RevenueCat...',
                              style: TextStyle(fontSize: 13, color: fg3),
                            ),
                          ],
                        ),
                      ),
                    ] else if (packages.isEmpty) ...[
                      // Empty / Pending Configuration State
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: sf,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: bd),
                        ),
                        child: Column(
                          children: [
                            const Icon(Iconsax.info_circle, size: 36, color: Colors.amber),
                            const SizedBox(height: 12),
                            Text(
                              'Connecting to RevenueCat Catalog',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Packages are propagating from RevenueCat Dashboard. Tap refresh or preview the native paywall below.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: fg2, height: 1.4),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => rc.fetchOfferings(),
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Refresh Offerings'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.emerald,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton.icon(
                                  onPressed: () => rc.presentPaywall(),
                                  icon: const Icon(Icons.launch, size: 16),
                                  label: const Text('Native Paywall'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: fg,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Render Live Dynamic Packages
                      for (int i = 0; i < packages.length; i++) ...[
                        _buildDynamicPackageCard(
                          package: packages[i],
                          isSelected: _selectedIndex == i,
                          onTap: () {
                            setState(() {
                              _selectedIndex = i;
                            });
                          },
                          sf: sf,
                          bd: bd,
                          fg: fg,
                          fg3: fg3,
                        ),
                        if (i < packages.length - 1) const SizedBox(height: 10),
                      ],
                    ],

                    const SizedBox(height: 18),

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
                          _buildFeatureRow('Lifetime Validity: Minutes yours forever with no expiry', fg),
                          const SizedBox(height: 8),
                          _buildFeatureRow('Sub-300ms Ultra-Low Latency: Real-time synchronized dubbing', fg),
                          const SizedBox(height: 8),
                          _buildFeatureRow('SyncDub Neural Pipeline: All 70+ languages & studio voices included', fg),
                          const SizedBox(height: 8),
                          _buildFeatureRow('Universal Support: Works across YouTube, Netflix, & Phone Apps', fg),
                          const SizedBox(height: 8),
                          _buildFeatureRow('Zero Commitments: Strictly one-time purchase with no auto-renewal', fg),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Dynamic CTA Button
                    if (selectedPkg != null) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  state.triggerHaptic();
                                  final success = await state.purchaseRevenueCatPackage(selectedPkg);
                                  if (context.mounted && success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                           'Payment successful! Your minutes are being added to your account.',
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
                          child: isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                )
                              : Text(
                                  'Get ${_cleanTitle(selectedPkg.storeProduct.title)} · ${selectedPkg.storeProduct.priceString}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Additional Options: Customer Center & Native Paywall triggers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () => rc.presentCustomerCenter(),
                          icon: const Icon(Icons.manage_accounts, size: 16, color: AppTheme.emerald),
                          label: const Text(
                            'Customer Center',
                            style: TextStyle(fontSize: 12, color: AppTheme.emerald, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: () => rc.presentPaywall(),
                          icon: const Icon(Icons.fullscreen, size: 16, color: AppTheme.emerald),
                          label: const Text(
                            'Full Paywall View',
                            style: TextStyle(fontSize: 12, color: AppTheme.emerald, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),
                    Text(
                      'Secured by Google Play Billing via RevenueCat · Minutes are added right after payment',
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
      },
    );
  }

  /// Builds a dynamic package card with live data from RevenueCat
  Widget _buildDynamicPackageCard({
    required Package package,
    required bool isSelected,
    required VoidCallback onTap,
    required Color sf,
    required Color bd,
    required Color fg,
    required Color fg3,
  }) {
    final storeProduct = package.storeProduct;
    final title = _cleanTitle(storeProduct.title);
    final price = storeProduct.priceString;
    final desc = storeProduct.description.isNotEmpty
        ? storeProduct.description
        : 'One-time minute recharge pack for live AI dubbing';
    final minutes = RevenueCatService.parseMinutesFromPackage(package);
    final badge = _getBadgeForPackage(package, minutes);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.emeraldDim : sf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppTheme.emerald : bd,
                width: isSelected ? 1.8 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppTheme.emerald : bd,
                              width: 2,
                            ),
                            color: isSelected ? AppTheme.emerald : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 13, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: fg,
                              ),
                            ),
                            Text(
                              minutes > 0 ? '$minutes Minutes · One-Time' : 'One-Time Minute Pack',
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
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: fg,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
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

  /// Removes Google Play "(AppName)" suffix if present in product title
  String _cleanTitle(String rawTitle) {
    return rawTitle.replaceAll(RegExp(r'\s*\([^)]*\)$'), '').trim();
  }

  /// Assign badges dynamically based on minutes or identifier
  String? _getBadgeForPackage(Package package, int minutes) {
    final id = package.identifier.toLowerCase();
    if (minutes == 300 || id.contains('pro')) {
      return 'MOST POPULAR';
    }
    if (minutes == 700 || id.contains('power')) {
      return 'BEST VALUE';
    }
    return null;
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
