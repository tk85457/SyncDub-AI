import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_update_service.dart';
import '../theme/app_theme.dart';

/// Shows [child] normally, but replaces the whole app with a blocking update screen while the
/// server requires a newer build. Re-checks every time the app returns to the foreground.
class UpdateGate extends StatefulWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppUpdateService.instance.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UpdateRequirement?>(
      valueListenable: AppUpdateService.instance.required,
      builder: (context, req, _) {
        if (req == null || !req.mandatory) return widget.child;
        return _ForceUpdateScreen(requirement: req);
      },
    );
  }
}

class _ForceUpdateScreen extends StatelessWidget {
  final UpdateRequirement requirement;
  const _ForceUpdateScreen({required this.requirement});

  Future<void> _openStore() async {
    final web = Uri.parse(requirement.updateUrl);
    try {
      final ok = await launchUrl(web, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {}
    try {
      await launchUrl(
        Uri.parse('market://details?id=com.syncdub.livedub'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = AppTheme.textPrimary(isDark);
    final fg2 = AppTheme.textSecondary(isDark);

    // Back button must not get the user past the gate.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/app_icon.webp', width: 84, height: 84),
                const SizedBox(height: 28),
                Text(
                  'Update required',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: fg),
                ),
                const SizedBox(height: 12),
                Text(
                  requirement.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.4, color: fg2),
                ),
                if (requirement.latestVersionName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Latest version: ${requirement.latestVersionName}',
                    style: TextStyle(fontSize: 12, color: fg2),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _openStore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emerald,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Update now',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
