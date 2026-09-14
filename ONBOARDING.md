# SyncDub AI — Developer & Codebase Onboarding Guide

Welcome to the **SyncDub AI** codebase! This document provides an exhaustive, practical onboarding guide for developers, engineers, and AI agents contributing to this repository.

---

## 1. Project Overview

**SyncDub AI** is a real-time, low-latency (<380ms) neural speech dubbing and translation application for Android (built with Flutter and Kotlin native services). It enables users to watch any foreign video (on YouTube, Instagram Reels, Netflix, Twitch, or live lectures) and hear it dubbed in their native language in real-time.

### Core Value Propositions
- **Zero-Latency Neural Dubbing**: Captures incoming audio directly from the device speaker or microphone, streams PCM chunks via WebSocket to an AI proxy, and plays synthesized neural speech.
- **Background Floating Overlay**: Keeps dubbing active when the user switches to YouTube or Reels via a native Android `FloatingOverlayService` that auto-docks to the screen edge after 10s of inactivity.
- **Smart Audio Ducking**: Automatically dips background media volume to 20% whenever the AI dubbed voice speaks, and smoothly restores it when silent.
- **Strict Privacy**: Zero user audio is ever recorded, stored, or indexed.

---

## 2. Tech Stack

| Layer | Technology | Version / Details |
|---|---|---|
| **Frontend Framework** | Flutter | 3.27+ (Dart 3.x) |
| **Native Platform** | Android (Kotlin) | API Level 26+ (Android 8.0 to Android 15) |
| **Audio Capture** | Android `AudioRecord` | 16kHz / 44.1kHz mono PCM capture |
| **Audio Playback** | Android `AudioTrack` | Real-time PCM streaming buffer |
| **Floating Overlay** | Android `WindowManager` + `Service` | Foreground service with auto-docking |
| **Authentication** | Supabase Auth | Google OAuth 2.0 (PKCE) |
| **Database & Realtime** | Supabase Postgres | User profiles, subscription plans, credits |
| **Payment & Billing** | RevenueCat / StoreKit | Google Play Billing integration |
| **Iconography** | Iconsax Flutter | Modern dual-tone & outline icon suite |

---

## 3. Architecture Map

```
┌────────────────────────────────────────────────────────────────────────┐
│                          SyncDub App UI Layer                          │
│                                                                        │
│   ┌────────────────────┐   ┌────────────────────┐   ┌──────────────┐   │
│   │  OnboardingScreen  │──>│    LoginScreen     │──>│  MainShell   │   │
│   │  (1st Launch Only) │   │ (Strictly Locked)  │   │  (Tabs & Nav)│   │
│   └────────────────────┘   └────────────────────┘   └──────┬───────┘   │
│                                                            │           │
│   ┌────────────────────────────────────────────────────────┴───────┐   │
│   │ Screens: HomeScreen | ProfileScreen | SettingsScreen | Paywall │   │
│   └────────────────────────────────┬───────────────────────────────┘   │
└────────────────────────────────────┼───────────────────────────────────┘
                                     │ Reactive ChangeNotifier
┌────────────────────────────────────▼───────────────────────────────────┐
│                      Core State (TranslationState)                     │
│                                                                        │
│  - Dubbing & Audio State (isTranslating, isPaused, latency, autoDuck)  │
│  - Auth & Profile (Google User, Credits, Plan: Starter/Pro/Studio)     │
│  - Navigation Stack & Android Back-Button Interception                 │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │ MethodChannel / EventChannel
┌────────────────────────────────────▼───────────────────────────────────┐
│                  Native Android Layer (Kotlin)                         │
│                                                                        │
│   ┌───────────────────────────────┐   ┌─────────────────────────────┐  │
│   │         MainActivity          │   │    FloatingOverlayService   │  │
│   │  - AudioRecord Capture Loop   │   │  - Floating Pill Widget     │  │
│   │  - AudioTrack Streaming Loop  │   │  - 10s Auto-Docking Engine  │  │
│   │  - Audio Ducking Hardware Vol │   │  - Quick Language Switcher  │  │
│   └───────────────────────────────┘   └─────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Key Entry Points & Source Map

### Flutter Layer (`lib/`)

- **`lib/main.dart`**: Root application entry point. Initializes `WidgetsFlutterBinding`, pre-caches critical assets (`app_icon.png`, animated GIFs), and sets up the light/dark theme with `ListenableBuilder`.
- **`lib/screens/main_shell.dart`**: Main screen coordinator. Enforces strict login authentication, manages navigation between tabs (`HomeScreen`, `ProfileScreen`, `SettingsScreen`, etc.), and intercepts Android system back-press events using `PopScope`.
- **`lib/screens/onboarding_screen.dart`**: Full-screen edge-to-edge carousel shown strictly on first app launch. Features live dubbing demo, interactive floating capsule mock, 1-tap permission granters, audio ducking visualization, and target language selection.
- **`lib/screens/login_screen.dart`**: Minimalist, secure Google Sign-In portal. Skip button is strictly removed; login is mandatory before accessing the app. System back button triggers the "Exit SyncDub AI?" popup.
- **`lib/screens/home_screen.dart`**: Primary live dubbing dashboard. Big pulsating start/stop button, input/output language selectors, real-time waveform visualizer, latency meter, and floating overlay quick-toggle.
- **`lib/models/translation_state.dart`**: The single source of truth for the app. Manages dubbing states, volume levels, persistent user settings (via `SharedPreferences`), and real-time Supabase profile sync.
- **`lib/services/floating_overlay_manager.dart`**: Flutter-to-Android bridge that controls the native floating overlay service.

### Native Android Layer (`android/`)

- **`android/app/src/main/kotlin/com/syncdub/livedub/MainActivity.kt`**:
  - Registers `MethodChannel("com.syncdub.livedub/audio")`.
  - Implements low-latency PCM audio capture using `AudioRecord`.
  - Implements low-latency PCM audio playback using `AudioTrack`.
  - Controls hardware media volume attenuation for smart audio ducking.
- **`android/app/src/main/kotlin/com/syncdub/livedub/FloatingOverlayService.kt`**:
  - Android foreground service displaying the floating pill over external apps (YouTube, Reels).
  - Handles drag-to-reposition, snap-to-edge, and 10-second inactivity auto-docking.
  - Controls dubbing pause/resume and language switching directly from the overlay.

---

## 5. Directory Map

```
SyncDub App/
├── android/                         # Native Android Gradle project
│   ├── app/src/main/
│   │   ├── kotlin/com/syncdub/livedub/
│   │   │   ├── MainActivity.kt      # AudioRecord & AudioTrack bridges
│   │   │   └── FloatingOverlayService.kt # Background floating widget
│   │   ├── res/                     # Mipmaps, drawables, splash screen
│   │   └── AndroidManifest.xml      # Permissions (Mic, Overlay, Foreground)
├── assets/
│   └── images/
│       ├── app_icon.png             # Uncropped 1254x1254 master app icon
│       ├── google_logo.png          # High-res Google branding
│       └── anim_*.gif               # Micro-animations for UI
├── lib/
│   ├── constants/
│   │   └── languages.dart           # 100+ supported languages with flags & ISO codes
│   ├── models/
│   │   ├── translation_state.dart   # Central ChangeNotifier state
│   │   ├── app_error.dart           # User-facing error structures
│   │   └── history_session.dart     # Persisted session records
│   ├── screens/
│   │   ├── onboarding_screen.dart   # Full-screen carousel onboarding
│   │   ├── login_screen.dart        # Mandatory Google Auth
│   │   ├── main_shell.dart          # Root scaffold & back-button handler
│   │   ├── home_screen.dart         # Live dubbing dashboard
│   │   ├── profile_screen.dart      # User credits, plan, sign-out
│   │   ├── settings_screen.dart     # Audio ducking, volume, device routing
│   │   ├── history_screen.dart      # Real saved dubbing logs
│   │   └── paywall_screen.dart      # Pro & Studio subscription upgrade
│   ├── services/
│   │   ├── auth_service.dart        # Supabase OAuth & session manager
│   │   ├── backend_service.dart     # WebSocket / WebRTC streaming client
│   │   ├── floating_overlay_manager.dart # Overlay platform channel wrapper
│   │   └── audio_device_service.dart# Audio routing (Speaker/Earpiece/BT)
│   ├── theme/
│   │   └── app_theme.dart           # Curated dark/light theme tokens
│   └── widgets/
│       ├── syncdub_waveform.dart    # Live audio visualizer
│       ├── language_picker_sheet.dart# Filterable language search modal
│       └── motion_icon.dart         # Animated icon wrapper
├── pubspec.yaml                     # Dependencies and asset declarations
├── ONBOARDING.md                    # This developer guide
└── AGENTS.md                        # AI agent & contributor rules
```

---

## 6. End-to-End Audio Dubbing Lifecycle

```
[Phone Speaker / Mic] 
         │
         ▼ (1) AudioRecord captures 16kHz PCM chunks
[MainActivity.kt] 
         │
         ▼ (2) Binary MethodChannel sends chunks to Flutter
[AudioPipelineService]
         │
         ▼ (3) WebSocket streams audio to Neural Server
[SyncDub AI Proxy]
         │ ├── Speech-to-Text (STT)
         │ ├── Neural Translation (e.g. EN -> HI)
         │ └── Neural Voice Synthesis (TTS)
         │
         ▼ (4) Streams dubbed PCM chunks back to Flutter
[MainActivity.kt]
         │
         ├──> (5) AudioTrack plays dubbed voice to speaker
         │
         └──> (6) Smart Audio Ducking drops original video volume to 20%
```

---

## 7. Development & Contribution Conventions

### 1. Mandatory Authentication Rule
- The app must **NEVER** allow bypassing the Login screen.
- Skip buttons on the Login screen are forbidden.
- If an unauthenticated user attempts to navigate to in-app screens (Home, Profile, Settings), `TranslationState.goScreen()` must redirect to `0` (Login).

### 2. Android Back-Button Handling
- Back press on `LoginScreen` or `OnboardingScreen` must **NEVER** push the user into the app.
- It must return `false` in `handleBackPress()`, triggering the system "Exit SyncDub AI?" confirmation dialog.

### 3. Master App Icon Integrity
- The master icon (`assets/images/app_icon.png` from `Gradient AI Head Play Icon.png`) must always be rendered with `BoxFit.contain` and **zero cropping**.
- Never wrap the icon in a clipped shape that truncates its gradient head silhouette.

### 4. Responsive UI & Zero Overflows
- All screens must use `LayoutBuilder`, `SingleChildScrollView`, or `Flexible` constraints to ensure flawless display across compact screens and tall flagships alike.

---

## 8. Common Developer Commands

```powershell
# 1. Fetch dependencies
flutter pub get

# 2. Run static analysis (MUST pass with 0 errors)
flutter analyze lib

# 3. Run on connected Android device in debug mode
flutter run

# 4. Build optimized release APK
flutter build apk --release

# 5. Install release APK directly via ADB
adb install -r build/app/outputs/flutter-apk/app-release.apk

# 6. Launch app on device via ADB
adb shell am start -n com.syncdub.livedub/.MainActivity
```

---

## 9. Where to Look

| If you want to... | Look at... |
|---|---|
| Modify onboarding slides or animations | `lib/screens/onboarding_screen.dart` |
| Change Google Login or OAuth configuration | `lib/services/auth_service.dart` & `lib/screens/login_screen.dart` |
| Tweak real-time audio ducking or PCM buffer | `android/app/src/main/kotlin/com/syncdub/livedub/MainActivity.kt` |
| Adjust floating widget behavior or auto-dock timer | `android/app/src/main/kotlin/com/syncdub/livedub/FloatingOverlayService.kt` |
| Add new supported languages | `lib/constants/languages.dart` |
| Alter user plans or credit deduction logic | `lib/models/translation_state.dart` & `lib/services/backend_service.dart` |
| Customize app styling, fonts, or palette | `lib/theme/app_theme.dart` |
