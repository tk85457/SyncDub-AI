import 'dart:ui';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/translation_state.dart';
import 'screens/main_shell.dart';
import 'services/app_update_service.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_error_widget.dart';
import 'widgets/update_gate.dart';

void main() async {
  // 1. Ensure Flutter bindings are safely initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Release builds print nothing: debugPrint still writes to logcat in release, where any app with log access
  // (adb, bug-report tools) could read user ids, purchase states and error details.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // 2. Install Global Flutter Framework Error Handler
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[SyncDub Global Error] FlutterError caught: ${details.exceptionAsString()}');
  };

  // 3. Install Global Asynchronous Platform Error Handler (Dart / Platform Channels / Isolates)
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[SyncDub Global Async Error] Caught: $error');
    return true; // Mark as handled to prevent process abort
  };

  // 4. Install Custom ErrorWidget Builder (Zero Red/Grey Screen of Death)
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return AppErrorFallbackWidget(details: details);
  };

  // 5. Safe Startup Initialization with Fallbacks
  bool hasCompletedOnboarding = false;
  bool isAuthenticated = false;

  try {
    final prefs = await SharedPreferences.getInstance();
    hasCompletedOnboarding = prefs.getBool('hasCompletedOnboarding') ?? false;
  } catch (e) {
    debugPrint('[SyncDub Startup] SharedPreferences init error: $e');
  }

  try {
    await AuthService().initialize();
    isAuthenticated = AuthService().isAuthenticated;
  } catch (e) {
    debugPrint('[SyncDub Startup] AuthService init error: $e');
  }

  // Mandatory-update check (needs Supabase initialised above). Applies the cached requirement
  // instantly, then refreshes from the server (3s cap) so the first frame is already gated.
  try {
    await AppUpdateService.instance.check();
  } catch (e) {
    debugPrint('[SyncDub Startup] AppUpdate check error: $e');
  }

  runApp(SyncDubApp(
    initialHasCompletedOnboarding: hasCompletedOnboarding,
    initialIsAuthenticated: isAuthenticated,
  ));
}

class SyncDubApp extends StatefulWidget {
  final bool initialHasCompletedOnboarding;
  final bool initialIsAuthenticated;

  const SyncDubApp({
    super.key,
    this.initialHasCompletedOnboarding = false,
    this.initialIsAuthenticated = false,
  });

  @override
  State<SyncDubApp> createState() => _SyncDubAppState();
}

class _SyncDubAppState extends State<SyncDubApp> {
  late final TranslationState _translationState;

  @override
  void initState() {
    super.initState();
    _translationState = TranslationState(
      initialHasCompletedOnboarding: widget.initialHasCompletedOnboarding,
      initialIsAuthenticated: widget.initialIsAuthenticated,
    );
  }

  bool _preloaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_preloaded) {
      _preloaded = true;
      _preloadImages();
    }
  }

  void _preloadImages() {
    const images = [
      'assets/images/app_icon.webp',
      'assets/images/google_logo.webp',
    ];
    for (final path in images) {
      precacheImage(AssetImage(path), context).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _translationState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _translationState.darkModeNotifier,
      builder: (context, isDark, _) {
        return MaterialApp(
          title: 'SyncDub AI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          // Wraps the whole Navigator: no screen, route or dialog can sit above the update gate.
          builder: (context, child) => UpdateGate(child: child ?? const SizedBox.shrink()),
          home: MainShell(state: _translationState),
        );
      },
    );
  }
}
