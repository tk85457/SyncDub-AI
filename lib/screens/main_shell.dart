import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../models/translation_state.dart';
import '../theme/app_theme.dart';
import 'connecting_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'paywall_screen.dart';
import 'pip_overlay_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import '../widgets/motion_icon.dart';

class MainShell extends StatelessWidget {
  final TranslationState state;

  const MainShell({
    super.key,
    required this.state,
  });

  Future<bool?> _showExitDialog(BuildContext context, TranslationState state) {
    final isDark = state.isDarkMode;
    final isTranslating = state.isTranslating;

    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const SyncDubFlaticon(assetName: 'anim_rocket.gif', size: 26),
              const SizedBox(width: 10),
              Text(
                'Exit SyncDub AI?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: Text(
            isTranslating
                ? 'Live dubbing stream is currently running. Exiting will end your active translation session. Are you sure you want to exit?'
                : 'Are you sure you want to close the app?',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Stay',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text(
                'Exit App',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final isDark = state.isDarkMode;
        final bg = AppTheme.bg(isDark);
        final bd = AppTheme.border(isDark);
        final activeError = state.activeError;

        Widget currentScreen;
        // BINA LOGIN KE USER APP NA KHOL PAAYE: Strict Authentication Enforcement
        if (!state.isAuthenticated && state.currentScreen != 1) {
          currentScreen = LoginScreen(state: state);
        } else {
          switch (state.currentScreen) {
            case 0:
              currentScreen = LoginScreen(state: state);
              break;
            case 1:
              currentScreen = OnboardingScreen(state: state);
              break;
            case 2:
              currentScreen = ConnectingScreen(state: state);
              break;
            case 4:
              currentScreen = PipOverlayScreen(state: state);
              break;
            case 5:
              currentScreen = ProfileScreen(state: state);
              break;
            case 6:
              currentScreen = PaywallScreen(state: state);
              break;
            case 7:
              currentScreen = HistoryScreen(state: state);
              break;
            case 8:
              currentScreen = SettingsScreen(state: state);
              break;
            case 3:
            default:
              currentScreen = HomeScreen(state: state);
              break;
          }
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final handled = state.handleBackPress();
            if (!handled) {
              final shouldExit = await _showExitDialog(context, state);
              if (shouldExit == true) {
                SystemNavigator.pop();
              }
            }
          },
          child: Scaffold(
            backgroundColor: bg,
            body: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Column(
                  children: [
                    // Active Screen Content with smooth fade transitions
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: KeyedSubtree(
                          key: ValueKey<int>(state.currentScreen),
                          child: currentScreen,
                        ),
                      ),
                    ),

                    // Bottom Navigation Bar is ONLY visible for authenticated users on in-app screens
                    if (state.isAuthenticated && state.currentScreen >= 3 && state.currentScreen <= 8)
                      _buildBottomNav(state, isDark, bd),
                  ],
                ),

                // Global Enterprise Sanitized Error Banner
                if (activeError != null && state.currentScreen != 0)
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(16),
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Iconsax.warning_2, color: AppTheme.danger, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    activeError.title,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.danger,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    activeError.reason,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () => state.clearActiveError(),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Iconsax.close_circle,
                                  size: 16,
                                  color: isDark ? Colors.white60 : Colors.black45,
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
        ),
      );
    },
  );
}

  Widget _buildBottomNav(TranslationState state, bool isDark, Color bd) {
    final sf = AppTheme.surface(isDark);
    final fg = AppTheme.textPrimary(isDark);
    final fg3 = AppTheme.textMuted(isDark);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: sf,
        border: Border(top: BorderSide(color: bd)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            icon: Iconsax.home_2,
            gifAsset: 'anim_home.gif',
            label: 'Home',
            isSelected: state.currentScreen == 3,
            fg: fg,
            fg3: fg3,
            onTap: () => state.goScreen(3),
          ),
          _buildNavItem(
            icon: Iconsax.clock,
            gifAsset: 'anim_history.gif',
            label: 'History',
            isSelected: state.currentScreen == 7,
            fg: fg,
            fg3: fg3,
            onTap: () => state.goScreen(7),
          ),
          _buildNavItem(
            icon: Iconsax.user,
            gifAsset: 'anim_user.gif',
            label: 'Profile',
            isSelected: state.currentScreen == 5,
            fg: fg,
            fg3: fg3,
            onTap: () => state.goScreen(5),
          ),
          _buildNavItem(
            icon: Iconsax.setting_2,
            gifAsset: 'anim_settings.gif',
            label: 'Settings',
            isSelected: state.currentScreen == 8,
            fg: fg,
            fg3: fg3,
            onTap: () => state.goScreen(8),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String gifAsset,
    required String label,
    required bool isSelected,
    required Color fg,
    required Color fg3,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isSelected)
            SyncDubFlaticon(assetName: gifAsset, size: 22)
          else
            Icon(
              icon,
              size: 22,
              color: fg3,
            ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? fg : fg3,
            ),
          ),
        ],
      ),
    );
  }
}

