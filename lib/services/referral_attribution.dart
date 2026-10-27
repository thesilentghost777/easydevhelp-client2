import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads Play Install Referrer once and persists the influencer `ref` code.
class ReferralAttribution {
  static const _prefsRefKey = 'referral_ref';
  static const _prefsConsumedKey = 'install_referrer_consumed';
  static const baseWebUrl = 'https://2s-pay.2s-group.com';

  /// Returns a stored referral code, fetching from Play Install Referrer on
  /// first Android launch when none is stored yet.
  static Future<String?> resolveReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefsRefKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim().toUpperCase();
    }

    if (!Platform.isAndroid) {
      return null;
    }

    if (prefs.getBool(_prefsConsumedKey) == true) {
      return null;
    }

    try {
      final details = await PlayInstallReferrer.installReferrer;
      final raw = details.installReferrer;
      final code = parseReferralCode(raw);
      await prefs.setBool(_prefsConsumedKey, true);
      if (code != null) {
        await prefs.setString(_prefsRefKey, code);
        return code;
      }
    } catch (e, st) {
      debugPrint('Install referrer unavailable: $e\n$st');
      await prefs.setBool(_prefsConsumedKey, true);
    }

    return null;
  }

  /// Parses `ref=CODE` or `utm_content=CODE` from a Play Store referrer string.
  static String? parseReferralCode(String? referrer) {
    if (referrer == null || referrer.trim().isEmpty) {
      return null;
    }

    final decoded = Uri.decodeQueryComponent(referrer.trim());
    final params = Uri.splitQueryString(decoded);

    final ref = params['ref'] ?? params['utm_content'];
    if (ref == null || ref.trim().isEmpty) {
      return null;
    }

    return ref.trim().toUpperCase();
  }

  static String webEntryUrl(String? referralCode) {
    if (referralCode == null || referralCode.isEmpty) {
      return '$baseWebUrl/';
    }
    return '$baseWebUrl/register?ref=${Uri.encodeComponent(referralCode)}';
  }

  /// JS snippet to mirror the native ref into web storage used by the SPA.
  static String injectReferralJs(String referralCode) {
    final escaped = referralCode
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'");
    return """
(function(){
  try {
    sessionStorage.setItem('referral_ref', '$escaped');
    localStorage.setItem('referral_ref', '$escaped');
  } catch (e) {}
})();
""";
  }
}
