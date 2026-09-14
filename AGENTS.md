# Agent & Contributor Guidelines — SyncDub AI

## Project Overview
SyncDub AI is a real-time, low-latency (<380ms) neural speech dubbing Flutter application for Android. It captures incoming speaker audio, streams it to an AI proxy for speech-to-text, translation, and TTS synthesis, and plays it via Android `AudioTrack` while ducking original video audio.

## Tech Stack
- **Framework**: Flutter 3.27+ (Dart 3.x)
- **Platforms**: Android (Kotlin foreground service, AudioRecord, AudioTrack)
- **Backend/Auth**: Supabase Auth (Google OAuth 2.0 PKCE) & Supabase Postgres
- **Icons**: Iconsax Flutter & uncropped `Gradient AI Head Play Icon.png`
- **State**: `ChangeNotifier` (`TranslationState`) + `ListenableBuilder`

## Non-Negotiable Invariants & Rules
1. **Mandatory Login**:
   - The user MUST authenticate via Google before accessing any app features (Home, History, Settings, Profile).
   - There must **NEVER** be a "Skip" button on the `LoginScreen`.
   - `TranslationState.goScreen()` will strictly redirect unauthenticated navigation back to `LoginScreen` (screen 0).
2. **Android Back-Button Behavior**:
   - Pressing back on `LoginScreen` or `OnboardingScreen` must **NEVER** navigate into the app.
   - It triggers the system "Exit SyncDub AI?" confirmation dialog.
3. **Master App Icon**:
   - The master icon is located at `assets/images/app_icon.png`.
   - It MUST always be displayed uncropped with `BoxFit.contain`. Never cut off its gradient edges or head silhouette.
4. **Onboarding Carousel**:
   - Shown strictly on first launch before login.
   - Must remain 100% full-screen edge-to-edge (`viewportFraction: 1.0`).
   - Supports interactive demo dubbing, floating overlay mock, 1-tap permissions, and live language selection.
5. **No Visual Overflows**:
   - All screens must use `LayoutBuilder`, `SingleChildScrollView`, or `Flexible` widgets to ensure zero render overflows on any screen size.

## Build & Test Commands
- Check lint & types: `flutter analyze lib` (Must have 0 issues)
- Build release APK: `flutter build apk --release`
- Run debug on Android: `flutter run`
- Install APK via ADB: `adb install -r build/app/outputs/flutter-apk/app-release.apk`
- Launch via ADB: `adb shell am start -n com.syncdub.livedub/.MainActivity`
