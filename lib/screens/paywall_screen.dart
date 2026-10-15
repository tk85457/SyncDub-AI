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
  bool _isRestoring = false;

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
        final products = rc.displayProducts;
        final isLoading = rc.isLoading;
        final selectedProduct = (products.isNotEmpty && _selectedIndex < products.length)
            ? products[_selectedIndex]
            : (products.isNotEmpty ? products.first : null);

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
                    // Restore Purchases Action (real time: RevenueCat restore, then server balance is re-read)
                    InkWell(
                      onTap: (_isRestoring || isLoading)
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              setState(() => _isRestoring = true);
                              final result = await state.restoreRevenueCatPurchases();
                              if (!mounted) return;
                              setState(() => _isRestoring = false);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(result.message),
                                  backgroundColor: result.ok ? AppTheme.emerald : Colors.blueGrey,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                        child: _isRestoring
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.emerald),
                              )
                            : Text(
                                'Restore',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isLoading ? fg3 : AppTheme.emerald,
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
                      'Buy once, use whenever you watch. Your minutes never expire.',
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
                    if (isLoading && products.isEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            const CircularProgressIndicator(color: AppTheme.emerald),
                            const SizedBox(height: 16),
                            Text(
                              'Loading prices...',
                              style: TextStyle(fontSize: 13, color: fg3),
                            ),
                          ],
                        ),
                      ),
                    ] else if (products.isEmpty) ...[
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
                              'Prices are not available right now',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              rc.lastErrorMessage ?? 'Prices are not available right now. Please try again in a little while.',
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
                                  label: const Text('Try again'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.emerald,
                                    foregroundColor: Colors.white,
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
                      for (int i = 0; i < products.length; i++) ...[
                        _buildDynamicPackageCard(
                          product: products[i],
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
                        if (i < products.length - 1) const SizedBox(height: 10),
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
                          _buildFeatureRow('All 70+ languages and studio voices included', fg),
                          const SizedBox(height: 8),
                          _buildFeatureRow('Works with YouTube, Netflix and other apps on your phone', fg),
                          const SizedBox(height: 8),
                          _buildFeatureRow('One-time purchase, no subscription, no auto-renewal', fg),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Payment received by Google Play, waiting for the server (webhook) to add the minutes
                    if (state.hasPendingPurchaseCredit) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.emeraldDim,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.emerald),
                        ),
                        child: Row(
                          children: [
                            if (state.isAwaitingCredit)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.emerald),
                              )
                            else
                              const Icon(Iconsax.tick_circle, size: 16, color: AppTheme.emerald),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                state.isAwaitingCredit
                                    ? 'Confirming your payment... your minutes will be added as soon as it is confirmed.'
                                    : 'Payment received. Your minutes will be added automatically once it is confirmed.',
                                style: TextStyle(fontSize: 12, color: fg, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Dynamic CTA Button
                    if (selectedProduct != null) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (isLoading || state.isAwaitingCredit)
                              ? null
                              : () async {
                                  state.triggerHaptic();
                                  final accepted = await state.purchaseStoreProduct(selectedProduct);
                                  // No "minutes added" message and no redirect here: Google Play accepting the
                                  // payment is NOT the credit. The server adds the minutes after the RevenueCat
                                  // webhook; only then does the app announce it and return Home.
                                  if (!accepted && context.mounted) {
                                    final err = state.activeError;
                                    if (err != null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(err.reason),
                                          backgroundColor: Colors.blueGrey,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      );
                                      state.clearActiveError();
                                    }
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
                          child: (isLoading || state.isAwaitingCredit)
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                )
                              : Text(
                                  'Get ${_cleanTitle(selectedProduct.title)} · ${_cleanPrice(selectedProduct.priceString)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    Text(
                      'Secure payment through Google Play',
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

  /// Builds a minute-pack card with live data from Google Play / RevenueCat
  Widget _buildDynamicPackageCard({
    required StoreProduct product,
    required bool isSelected,
    required VoidCallback onTap,
    required Color sf,
    required Color bd,
    required Color fg,
    required Color fg3,
  }) {
    final title = _cleanTitle(product.title);
    final price = _cleanPrice(product.priceString);
    final minutes = RevenueCatService.parseMinutesFromProduct(product);
    final badge = _getBadgeForProduct(product, minutes);

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

  /// Removes every "(...)" / "[...]" segment from the Google Play title (app name, extra price, notes)
  String _cleanTitle(String rawTitle) {
    return rawTitle
        .replaceAll(RegExp(r'\s*[\(\[][^\)\]]*[\)\]]'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  /// Shows ONLY the real Google Play price: any bracketed second price/note is dropped
  String _cleanPrice(String rawPrice) {
    final cleaned = rawPrice.replaceAll(RegExp(r'\s*[\(\[][^\)\]]*[\)\]]'), '').trim();
    return cleaned.isEmpty ? rawPrice : cleaned;
  }

  /// Assign badges dynamically based on minutes or identifier
  String? _getBadgeForProduct(StoreProduct product, int minutes) {
    final id = product.identifier.toLowerCase();
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
