import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// What the server requires of this build. Null fields mean "nothing known".
class UpdateRequirement {
  final bool mandatory;
  final String message;
  final String updateUrl;
  final String latestVersionName;

  const UpdateRequirement({
    required this.mandatory,
    required this.message,
    required this.updateUrl,
    required this.latestVersionName,
  });
}

/// Mandatory-update gate backed by the public.app_config row in Supabase (migration 004).
///
/// The installed build number (versionCode) is compared with app_config.min_version_code.
/// If it is lower, the app shows a blocking update screen and does not open.
/// The last known minimum is cached, so a user who is offline cannot dodge an update that was
/// already required; with no cache and no network the app opens normally (never lock people out
/// because of a failed request).
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const String _kMinCode = 'upd_min_code';
  static const String _kMessage = 'upd_message';
  static const String _kUrl = 'upd_url';
  static const String _kLatest = 'upd_latest';
  static const String defaultUpdateUrl =
      'https://play.google.com/store/apps/details?id=com.syncdub.livedub';
  static const String defaultMessage =
      'A new version of SyncDub AI is required. Please update to continue.';

  /// Non-null (mandatory == true) while the installed build is too old.
  final ValueNotifier<UpdateRequirement?> required = ValueNotifier<UpdateRequirement?>(null);

  int? _buildNumber;
  bool _refreshing = false;

  Future<int> _installedBuild() async {
    final cached = _buildNumber;
    if (cached != null) return cached;
    final info = await PackageInfo.fromPlatform();
    final n = int.tryParse(info.buildNumber) ?? 0;
    _buildNumber = n;
    return n;
  }

  /// The update link comes from a database row, so it is only opened when it points to Google Play.
  /// Anything else (a tampered row, a typo) falls back to the app's own Play Store page.
  static String _safeUpdateUrl(String? raw) {
    final text = (raw ?? '').trim();
    final u = Uri.tryParse(text);
    if (u != null &&
        ((u.scheme == 'https' && u.host == 'play.google.com') || u.scheme == 'market')) {
      return text;
    }
    return defaultUpdateUrl;
  }

  UpdateRequirement? _evaluate({
    required int installed,
    required int? minCode,
    required String? message,
    required String? url,
    required String? latest,
  }) {
    if (minCode == null || installed >= minCode) return null;
    return UpdateRequirement(
      mandatory: true,
      message: (message == null || message.trim().isEmpty) ? defaultMessage : message.trim(),
      updateUrl: _safeUpdateUrl(url),
      latestVersionName: latest ?? '',
    );
  }

  /// Applies the cached requirement immediately (no network), then refreshes from Supabase.
  /// Safe to await at startup: the network part is capped at [timeout].
  Future<void> check({Duration timeout = const Duration(seconds: 3)}) async {
    try {
      final installed = await _installedBuild();
      final prefs = await SharedPreferences.getInstance();
      required.value = _evaluate(
        installed: installed,
        minCode: prefs.getInt(_kMinCode),
        message: prefs.getString(_kMessage),
        url: prefs.getString(_kUrl),
        latest: prefs.getString(_kLatest),
      );
    } catch (e) {
      debugPrint('[AppUpdate] cache read failed: $e');
    }
    await refresh(timeout: timeout);
  }

  /// Fetches the current requirement. Any failure keeps whatever is already known.
  Future<void> refresh({Duration timeout = const Duration(seconds: 3)}) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final installed = await _installedBuild();
      final row = await Supabase.instance.client
          .from('app_config')
          .select('min_version_code, latest_version_name, update_url, message')
          .eq('platform', 'android')
          .maybeSingle()
          .timeout(timeout);
      if (row == null) return;

      final minCode = (row['min_version_code'] as num?)?.toInt();
      final message = row['message'] as String?;
      final url = row['update_url'] as String?;
      final latest = row['latest_version_name'] as String?;

      final prefs = await SharedPreferences.getInstance();
      if (minCode != null) {
        await prefs.setInt(_kMinCode, minCode);
      } else {
        await prefs.remove(_kMinCode);
      }
      await prefs.setString(_kMessage, message ?? '');
      await prefs.setString(_kUrl, url ?? '');
      await prefs.setString(_kLatest, latest ?? '');

      required.value = _evaluate(
        installed: installed,
        minCode: minCode,
        message: message,
        url: url,
        latest: latest,
      );
    } catch (e) {
      debugPrint('[AppUpdate] refresh failed (keeping last known state): $e');
    } finally {
      _refreshing = false;
    }
  }
}
