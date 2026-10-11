import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_error_handler.dart';
import 'backend_service.dart';

class AuthResult {
  final bool success;
  final User? user;
  final AppError? error;

  const AuthResult({
    required this.success,
    this.user,
    this.error,
  });
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String googleClientId =
      '621619576044-sfj1k8q06uan9cg34tdqf9slj77orlkg.apps.googleusercontent.com';

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Supabase.initialize(
        url: SyncDubBackendConfig.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: SyncDubBackendConfig.supabaseAnonKey,
      );
      _initialized = true;
      debugPrint('[AuthService] Supabase initialized successfully.');
    } catch (e) {
      debugPrint('[AuthService] Supabase initialization error: ${AppError.fromException(e).reason}');
    }
  }

  SupabaseClient get client => Supabase.instance.client;

  User? get currentUser => _initialized ? client.auth.currentUser : null;
  User? get user => currentUser;
  String? get userId => currentUser?.id;
  Session? get currentSession => _initialized ? client.auth.currentSession : null;
  bool get isAuthenticated => currentSession != null;

  String? get userEmail => currentUser?.email;

  String get userName {
    final meta = currentUser?.userMetadata;
    if (meta != null) {
      final fullName = meta['full_name'] ?? meta['name'];
      if (fullName != null && fullName.toString().trim().isNotEmpty) {
        return fullName.toString();
      }
    }
    if (userEmail != null && userEmail!.contains('@')) {
      return userEmail!.split('@').first;
    }
    return 'SyncDub Creator';
  }

  String? get userAvatarUrl {
    final meta = currentUser?.userMetadata;
    return meta?['avatar_url']?.toString() ?? meta?['picture']?.toString();
  }

  String? get accessToken => currentSession?.accessToken;

  /// Returns a valid, fresh access token, auto-refreshing the session if expired
  Future<String?> getFreshAccessToken() async {
    if (!_initialized) return null;
    try {
      final session = client.auth.currentSession;
      if (session == null) return null;
      if (session.isExpired) {
        debugPrint('[AuthService] Supabase session is expired. Refreshing token...');
        final res = await client.auth.refreshSession();
        return res.session?.accessToken ?? session.accessToken;
      }
      return session.accessToken;
    } catch (e) {
      debugPrint('[AuthService] refreshSession error: $e');
      return client.auth.currentSession?.accessToken;
    }
  }

  /// Maps a native Google Sign-In / Supabase failure to a clear, actionable error.
  AppError _nativeSignInError(Object e) {
    final text = e.toString();
    if (text.contains('ApiException: 10') || text.contains('DEVELOPER_ERROR')) {
      return AppError(
        title: 'Google Sign-In Not Configured',
        reason: 'This app build is not registered with Google (package name / SHA-1 mismatch).',
        recoveryAction: 'Install the official Play Store version of the app',
        type: AppErrorType.auth,
      );
    }
    if (text.contains('ApiException: 7') || text.contains('network_error')) {
      return AppError(
        title: 'No Connection',
        reason: 'Could not reach Google. Please check your internet connection.',
        recoveryAction: 'Retry sign-in',
        type: AppErrorType.network,
      );
    }
    if (text.contains('ApiException: 12501') || text.contains('sign_in_canceled')) {
      return AppError(
        title: 'Sign-In Cancelled',
        reason: 'Google account selection was closed without selecting an account.',
        recoveryAction: 'Tap Continue with Google to select your account',
        type: AppErrorType.auth,
      );
    }
    return AppError.fromException(e, context: 'Google Sign-In');
  }

  /// Secure Google Sign In with native Google Play Services + Supabase
  Future<AuthResult> signInWithGoogle() async {
    try {
      debugPrint('[AuthService] Attempting Google Sign In...');

      // 1. Try Native Google Sign In
      try {
        final GoogleSignIn googleSignIn = GoogleSignIn(
          serverClientId: googleClientId,
          scopes: ['email', 'profile'],
        );

        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          // User deliberately dismissed/cancelled Google account picker
          return AuthResult(
            success: false,
            error: AppError(
              title: 'Sign-In Cancelled',
              reason: 'Google account selection was closed without selecting an account.',
              recoveryAction: 'Tap Continue with Google to select your account',
              type: AppErrorType.auth,
            ),
          );
        }

        final googleAuth = await googleUser.authentication;
        final idToken = googleAuth.idToken;
        final accessToken = googleAuth.accessToken;

        if (idToken != null) {
          final res = await client.auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
            accessToken: accessToken,
          );
          if (res.session != null) {
            debugPrint('[AuthService] Supabase session established via native Google Sign In!');
            // Auto-provision initial profile if needed
            await fetchUserProfile();
            return AuthResult(success: true, user: res.user);
          }
        }
        // Google answered but gave no ID token (or Supabase returned no session).
        return AuthResult(
          success: false,
          error: AppError(
            title: 'Sign-In Failed',
            reason: 'Google did not return a valid sign-in token. Please try again.',
            recoveryAction: 'Tap Continue with Google to retry',
            type: AppErrorType.auth,
          ),
        );
      } catch (nativeErr) {
        // Never fall back to browser OAuth: it leaves the app and lands on the website. The real
        // reason is logged and mapped to a clear message instead.
        debugPrint('[AuthService] Native Google Sign In failed: $nativeErr');
        return AuthResult(success: false, error: _nativeSignInError(nativeErr));
      }
    } catch (e) {
      final sanitized = AppError.fromException(e, context: 'Google Sign-In');
      debugPrint('[AuthService] Google Sign In error: ${sanitized.reason}');
      return AuthResult(
        success: false,
        error: sanitized,
      );
    }
  }

  /// Sign out the current user safely
  Future<void> signOut() async {
    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut().catchError((_) => null);
    } catch (_) {}

    if (_initialized) {
      try {
        await client.auth.signOut();
      } catch (e) {
        debugPrint('[AuthService] Sign out error: ${AppError.fromException(e).reason}');
      }
    }
  }

  /// Real-time stream of the current user's profile from Supabase
  Stream<List<Map<String, dynamic>>>? get profileStream {
    if (!_initialized || !isAuthenticated || currentUser == null) return null;
    try {
      return client
          .from('profiles')
          .stream(primaryKey: ['id'])
          .eq('id', currentUser!.id);
    } catch (e) {
      debugPrint('[AuthService] profileStream creation error: ${AppError.fromException(e).reason}');
      return null;
    }
  }

  /// Reads the signed-in user's profile (translation minutes & plan) from Supabase.
  ///
  /// READ-ONLY by design: row-level security forbids the app from writing to `profiles`, so a user
  /// can never give themselves minutes. Only the Render server (service role) changes balances.
  /// Returns null when the row does not exist yet or cannot be read; the caller then asks the server
  /// (/api/user-plan), which creates the profile with the free signup minutes on first use.
  Future<Map<String, dynamic>?> fetchUserProfile() async {
    if (!isAuthenticated || currentUser == null) return null;
    try {
      final res = await client
          .from('profiles')
          .select('plan, translation_minutes_remaining')
          .eq('id', currentUser!.id)
          .maybeSingle();

      final minutes = (res?['translation_minutes_remaining'] as num?)?.toDouble();
      if (res == null || minutes == null) return null;
      return {
        'plan': res['plan']?.toString() ?? 'free',
        'minutes': minutes,
      };
    } catch (e) {
      debugPrint('[AuthService] fetchUserProfile error: ${AppError.fromException(e).reason}');
      return null;
    }
  }
}
