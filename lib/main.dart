import 'package:flutter/material.dart';
import 'models/translation_state.dart';
import 'screens/main_shell.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SyncDubApp());
}

class SyncDubApp extends StatefulWidget {
  const SyncDubApp({super.key});

  @override
  State<SyncDubApp> createState() => _SyncDubAppState();
}

class _SyncDubAppState extends State<SyncDubApp> {
  late final TranslationState _translationState;

  @override
  void initState() {
    super.initState();
    _translationState = TranslationState();
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
      'assets/images/app_icon.png',
      'assets/images/google_logo.png',
      'assets/images/anim_soundwave.gif',
      'assets/images/anim_speed.gif',
      'assets/images/anim_home.gif',
      'assets/images/anim_history.gif',
      'assets/images/anim_settings.gif',
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
    return ListenableBuilder(
      listenable: _translationState,
      builder: (context, _) {
        return MaterialApp(
          title: 'SyncDub AI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: _translationState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: MainShell(state: _translationState),
        );
      },
    );
  }
}
