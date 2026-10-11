import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/app_error_handler.dart';

/// Enterprise-grade fallback widget displayed if any widget build throws an error.
/// Prevents the ugly red/grey screen of death and offers an elegant recovery action.
class AppErrorFallbackWidget extends StatelessWidget {
  final FlutterErrorDetails? details;
  final VoidCallback? onRetry;

  const AppErrorFallbackWidget({
    super.key,
    this.details,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final rawMessage = details?.exceptionAsString() ?? 'A display error occurred.';
    final sanitized = AppErrorHandler.sanitize(rawMessage);

    return Material(
      color: AppTheme.darkBg,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing Warning Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.amber.withValues(alpha: 0.12),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Iconsax.warning_2,
                      color: Colors.amber,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // App Title
                const Text(
                  'SyncDub AI Notice',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),

                // Sanitized message
                Text(
                  sanitized.reason,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Retry Button
                if (onRetry != null)
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Iconsax.refresh, size: 18),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable contextual in-screen error banner matching world-class enterprise UX
class AppErrorBanner extends StatelessWidget {
  final AppError error;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  const AppErrorBanner({
    super.key,
    required this.error,
    this.onAction,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isAmber = error.type == AppErrorType.microphone ||
        error.type == AppErrorType.rateLimit ||
        error.type == AppErrorType.timeout;

    final accentColor = isAmber ? AppTheme.amber : AppTheme.danger;

    final IconData icon = switch (error.type) {
      AppErrorType.microphone => Iconsax.microphone_slash,
      AppErrorType.network => Iconsax.wifi_square,
      AppErrorType.rateLimit => Iconsax.timer,
      AppErrorType.timeout => Iconsax.clock,
      AppErrorType.video => Iconsax.video_remove,
      AppErrorType.quota => Iconsax.flash_1,
      AppErrorType.auth => Iconsax.shield_cross,
      _ => Iconsax.warning_2,
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  error.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  error.reason,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Colors.white70,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (onAction != null)
                      ElevatedButton(
                        onPressed: onAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          error.recoveryAction,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    if (onDismiss != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: onDismiss,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Dismiss',
                          style: TextStyle(fontSize: 11, color: Colors.white54),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays an industry-standard floating pill error SnackBar (similar to YouTube / Netflix).
/// Never causes layout shift, overflow, or screen distortion.
void showAppErrorSnackBar(
  BuildContext context,
  AppError error, {
  VoidCallback? onRetry,
}) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.hideCurrentSnackBar();

  final isAmber = error.type == AppErrorType.microphone ||
      error.type == AppErrorType.rateLimit ||
      error.type == AppErrorType.timeout;
  final accentColor = isAmber ? AppTheme.amber : AppTheme.danger;

  final IconData icon = switch (error.type) {
    AppErrorType.microphone => Iconsax.microphone_slash,
    AppErrorType.network => Iconsax.wifi_square,
    AppErrorType.rateLimit => Iconsax.timer,
    AppErrorType.timeout => Iconsax.clock,
    AppErrorType.video => Iconsax.video_remove,
    AppErrorType.quota => Iconsax.flash_1,
    AppErrorType.auth => Iconsax.shield_cross,
    _ => Iconsax.warning_2,
  };

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      backgroundColor: const Color(0xFF1E293B),
      elevation: 8,
      duration: const Duration(seconds: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accentColor.withValues(alpha: 0.35), width: 1),
      ),
      content: Row(
        children: [
          Icon(icon, color: accentColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  error.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  error.reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      action: onRetry != null
          ? SnackBarAction(
              label: error.recoveryAction,
              textColor: AppTheme.emerald,
              onPressed: onRetry,
            )
          : null,
    ),
  );
}


