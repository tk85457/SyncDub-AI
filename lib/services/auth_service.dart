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
      } catch (nativeErr) {
        debugPrint('[AuthService] Native Google Sign In exception. Trying browser OAuth fallback...');
      }

      // 2. Fallback: Supabase Web OAuth Flow with deep link
      final res = await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'syncdub://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );

      return AuthResult(success: res);
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

  /// Fetch user profile (translation minutes & plan) directly from Supabase
  Future<Map<String, dynamic>?> fetchUserProfile() async {
    if (!isAuthenticated || currentUser == null) return null;
    try {
      final res = await client
          .from('profiles')
          .select('plan, translation_minutes_remaining')
          .eq('id', currentUser!.id)
          .maybeSingle();

      if (res != null) {
        return {
          'plan': res['plan']?.toString() ?? 'pro',
          'minutes': (res['translation_minutes_remaining'] as num?)?.toDouble() ?? 3000.0,
        };
      } else {
        // Auto-provision initial profile with 3000 free minutes for newly logged-in user
        try {
          await client.from('profiles').upsert({
            'id': currentUser!.id,
            'plan': 'pro',
            'translation_minutes_remaining': 3000.0,
          });
          return {
            'plan': 'pro',
            'minutes': 3000.0,
          };
        } catch (upsertErr) {
          debugPrint('[AuthService] Profile auto-provision error: $upsertErr');
        }
      }
    } catch (e) {
      debugPrint('[AuthService] fetchUserProfile error: ${AppError.fromException(e).reason}');
    }
    return null;
  }

  /// Persist updated subscription plan and remaining translation minutes to Supabase
  Future<bool> updateUserProfile({
    required String plan,
    required double minutes,
  }) async {
    if (!isAuthenticated || currentUser == null) return false;
    try {
      await client.from('profiles').upsert({
        'id': currentUser!.id,
        'plan': plan,
        'translation_minutes_remaining': minutes,
      });
      debugPrint('[AuthService] Supabase profile updated: plan=$plan, minutes=$minutes');
      return true;
    } catch (e) {
      debugPrint('[AuthService] updateUserProfile error: ${AppError.fromException(e).reason}');
      return false;
    }
  }
}
