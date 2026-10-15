import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../models/translation_state.dart';
import '../theme/app_theme.dart';
import '../utils/app_error_handler.dart';
import '../widgets/app_error_widget.dart';
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

class MainShell extends StatefulWidget {
  final TranslationState state;

  const MainShell({
    super.key,
    required this.state,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  /// The last error already shown, so one error is never shown twice.
  AppError? _lastShownError;

  /// Home-screen errors appear as a floating pill snackbar (like YouTube / Netflix) instead of a
  /// card inside the layout, so the connect button and the rest of the screen never move.
  void _surfaceHomeError(TranslationState state) {
    final error = state.activeError;
    if (error == null || identical(error, _lastShownError)) return;
    if (!state.isAuthenticated || state.currentScreen != 3) return;
    _lastShownError = error;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showAppErrorSnackBar(
        context,
        error,
        bottomOffset: 84, // sits above the bottom navigation bar
        onRetry: () {
          if (error.type == AppErrorType.microphone) {
            state.requestMicPermission();
          } else {
            state.retryConnection();
          }
        },
      );
      state.clearActiveError();
    });
  }

  StreamSubscription<double>? _creditSub;

  /// Announces added minutes ONLY when the server balance really increased (webhook processed).
  void _onCreditAdded(double added) {
    if (!mounted) return;
    final txt = added == added.roundToDouble() ? added.toStringAsFixed(0) : added.toStringAsFixed(1);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('$txt minutes added to your account'),
        backgroundColor: AppTheme.emerald,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _creditSub = widget.state.creditedEvents.listen(_onCreditAdded);
  }

  @override
  void dispose() {
    _creditSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      widget.state.refreshOutputDevices();
      widget.state.wakeBackend();
    }
  }

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
              const SyncDubFlaticon(assetName: 'anim_rocket.webp', size: 26),
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
      listenable: widget.state,
      builder: (context, _) {
        final state = widget.state;
        final isDark = state.isDarkMode;
        final bg = AppTheme.bg(isDark);
        final bd = AppTheme.border(isDark);
        _surfaceHomeError(state);

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
              top: state.currentScreen != 1,
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
            gifAsset: 'anim_home.webp',
            label: 'Home',
            isSelected: state.currentScreen == 3,
            fg: fg,
            fg3: fg3,
            onTap: () => state.goScreen(3),
          ),
          _buildNavItem(
            icon: Iconsax.clock,
            gifAsset: 'anim_history.webp',
            label: 'History',
            isSelected: state.currentScreen == 7,
            fg: fg,
            fg3: fg3,
            onTap: () => state.goScreen(7),
          ),
          _buildNavItem(
            icon: Iconsax.user,
            gifAsset: 'anim_user.webp',
            label: 'Profile',
            isSelected: state.currentScreen == 5,
            fg: fg,
            fg3: fg3,
            onTap: () => state.goScreen(5),
          ),
          _buildNavItem(
            icon: Iconsax.setting_2,
            gifAsset: 'anim_settings.webp',
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

