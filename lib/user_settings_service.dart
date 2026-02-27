import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserSettingsService {
  static const String profileKey = 'default';
  static const String signatureBucket = 'officer-signatures';
  static const String _kLocalNextSerialNoPrefix = 'local_next_serial_no_';
  static const String _kLocalOfficerNamePrefix = 'local_officer_name_';
  static const String _kLocalLanguagePrefix = 'local_language_';
  static const String _kLocalSignaturePathPrefix = 'local_signature_path_';

  static SupabaseClient get _client => Supabase.instance.client;
  static User? get _currentUser => _client.auth.currentUser;
  static String get _resolvedProfileKey => _currentUser?.id ?? profileKey;
  static String get _localNextSerialNoKey =>
      '$_kLocalNextSerialNoPrefix$_resolvedProfileKey';
  static String get _localOfficerNameKey =>
      '$_kLocalOfficerNamePrefix$_resolvedProfileKey';
  static String get _localLanguageKey =>
      '$_kLocalLanguagePrefix$_resolvedProfileKey';
  static String get _localSignaturePathKey =>
      '$_kLocalSignaturePathPrefix$_resolvedProfileKey';

  static Future<Map<String, dynamic>?> fetchSettings() async {
    Map<String, dynamic>? baseSettings;
    try {
      final result = await _client
          .from('user_settings')
          .select(
            'profile_key, language, collecting_officer_name, signature_image_path, next_serial_no',
          )
          .eq('profile_key', _resolvedProfileKey)
          .maybeSingle();
      if (result != null) {
        baseSettings = Map<String, dynamic>.from(result);
      }
    } catch (_) {
      // Ignore fallback table errors.
    }
    final localLanguage = await _readLocalLanguage();
    final localOfficer = await _readLocalOfficerName();
    final localSignature = await _readLocalSignaturePath();
    final localNext = await _readLocalNextSerialNo();
    if (localNext != null ||
        (localLanguage != null && localLanguage.isNotEmpty) ||
        (localOfficer != null && localOfficer.isNotEmpty) ||
        (localSignature != null && localSignature.isNotEmpty)) {
      final merged = <String, dynamic>{...?baseSettings};
      if (localLanguage != null && localLanguage.isNotEmpty) {
        merged['language'] = localLanguage;
      }
      if (localOfficer != null && localOfficer.isNotEmpty) {
        merged['collecting_officer_name'] = localOfficer;
      }
      if (localSignature != null && localSignature.isNotEmpty) {
        merged['signature_image_path'] = localSignature;
      }
      if (localNext != null) {
        merged['next_serial_no'] = localNext;
      }
      baseSettings = merged;
    }

    final userId = _currentUser?.id;
    if (userId == null) return baseSettings;

    try {
      final profile = await _client
          .from('user_profiles')
          .select('signature_image_path')
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) return baseSettings;

      final merged = <String, dynamic>{...?baseSettings};
      final userSignaturePath =
          (profile['signature_image_path'] ?? '').toString().trim();
      if (userSignaturePath.isNotEmpty) {
        merged['signature_image_path'] = userSignaturePath;
      }
      return merged;
    } catch (_) {
      return baseSettings;
    }
  }

  static Future<String> uploadSignature({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final ext = fileName.contains('.') ? fileName.split('.').last : 'png';
    final ownerKey = _currentUser?.id ?? profileKey;
    final path =
        '$ownerKey/signature_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.storage.from(signatureBucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return path;
  }

  static Future<void> saveSettings({
    required String language,
    required String collectingOfficerName,
    String? signatureImagePath,
    int? nextSerialNo,
  }) async {
    await _saveLocalLanguage(language);
    await _saveLocalOfficerName(collectingOfficerName);
    if (signatureImagePath != null && signatureImagePath.trim().isNotEmpty) {
      await _saveLocalSignaturePath(signatureImagePath);
    }

    final payload = <String, dynamic>{
      'profile_key': _resolvedProfileKey,
      'language': language,
      'collecting_officer_name': collectingOfficerName,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (signatureImagePath != null) {
      payload['signature_image_path'] = signatureImagePath;
    }
    if (nextSerialNo != null) {
      payload['next_serial_no'] = nextSerialNo;
    }

    if (nextSerialNo != null) {
      await _saveLocalNextSerialNo(nextSerialNo);
    }

    try {
      await _client.from('user_settings').upsert(
            payload,
            onConflict: 'profile_key',
          );
    } catch (_) {
      // Keep local settings usable while offline.
    }

    if (signatureImagePath != null && _currentUser != null) {
      try {
        await _client.from('user_profiles').update({
          'signature_image_path': signatureImagePath,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', _currentUser!.id);
      } catch (_) {
        // Signature sync can be retried when online.
      }
    }
  }

  static String? publicSignatureUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    return _client.storage.from(signatureBucket).getPublicUrl(path);
  }

  static Future<int?> consumeNextSerialNo() async {
    try {
      final result = await _client.rpc(
        'consume_next_serial_no',
        params: {'p_profile_key': _resolvedProfileKey},
      );
      final serial = _asInt(result);
      if (serial != null) {
        await _saveLocalNextSerialNo(serial + 1);
      }
      return serial;
    } catch (_) {
      return consumeLocalSerialNo();
    }
  }

  static Future<void> setNextSerialNo(int nextSerialNo) async {
    await _saveLocalNextSerialNo(nextSerialNo);
    try {
      await _client.from('user_settings').upsert(
        {
          'profile_key': _resolvedProfileKey,
          'next_serial_no': nextSerialNo,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'profile_key',
      );
    } catch (_) {
      // Keep local value if offline.
    }
  }

  static Future<Map<String, dynamic>?> fetchMySerialStatus() async {
    final localNext = await _readLocalNextSerialNo();
    try {
      final result = await _client.rpc('get_my_serial_status');
      if (result == null) return null;

      Map<String, dynamic>? map;
      if (result is List && result.isNotEmpty) {
        map = Map<String, dynamic>.from(result.first as Map);
      }

      if (result is Map) {
        map = Map<String, dynamic>.from(result);
      }

      if (map != null) {
        final remoteNext = int.tryParse((map['next_serial_no'] ?? '').toString());
        if (localNext != null && (remoteNext == null || localNext > remoteNext)) {
          map['next_serial_no'] = localNext;
        } else if (remoteNext != null &&
            (localNext == null || remoteNext > localNext)) {
          await _saveLocalNextSerialNo(remoteNext);
        }
        return map;
      }
    } catch (_) {
      // Fallback to local serial when offline.
    }

    if (localNext == null) return null;
    return <String, dynamic>{'next_serial_no': localNext};
  }

  static Future<int?> consumeMySerialNo() async {
    final localCurrent = await _readLocalNextSerialNo() ?? 1;
    try {
      final result = await _client.rpc('consume_my_serial_no');
      final serial = _asInt(result);
      final effectiveSerial = serial == null
          ? localCurrent
          : (serial >= localCurrent ? serial : localCurrent);
      await _saveLocalNextSerialNo(effectiveSerial + 1);
      return effectiveSerial;
    } catch (_) {
      return consumeLocalSerialNo();
    }
  }

  static Future<int?> consumeLocalSerialNo() async {
    final current = await _readLocalNextSerialNo() ?? 1;
    await _saveLocalNextSerialNo(current + 1);
    return current;
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static Future<int?> _readLocalNextSerialNo() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_localNextSerialNoKey);
    return value != null && value > 0 ? value : null;
  }

  static Future<void> _saveLocalNextSerialNo(int value) async {
    if (value <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_localNextSerialNoKey, value);
  }

  static Future<String?> _readLocalOfficerName() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_localOfficerNameKey)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static Future<void> _saveLocalOfficerName(String value) async {
    final v = value.trim();
    if (v.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localOfficerNameKey, v);
  }

  static Future<String?> _readLocalLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_localLanguageKey)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static Future<void> _saveLocalLanguage(String value) async {
    final v = value.trim();
    if (v.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localLanguageKey, v);
  }

  static Future<String?> _readLocalSignaturePath() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_localSignaturePathKey)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static Future<void> _saveLocalSignaturePath(String value) async {
    final v = value.trim();
    if (v.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localSignaturePathKey, v);
  }
}
