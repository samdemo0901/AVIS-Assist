import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================
/// AVIS Mobile — Secure Credential & API Key Store
/// Persists Gemini API keys and credentials using an obfuscated/
/// encrypted cryptographic envelope to prevent plaintext storage
/// on disk, with transparent auto-migration for legacy keys.
/// ============================================================
class SecureKeyStore {
  static const String _keysListPref = 'avis_gemini_api_keys';
  static const String _activeIndexPref = 'avis_active_key_index';
  static const String _encPrefix = 'enc:v1:';

  // Salt seed mask for internal bitwise envelope
  static const List<int> _maskKey = [
    0x41, 0x56, 0x49, 0x53, // A V I S
    0x5F, 0x4E, 0x45, 0x55, // _ N E U
    0x52, 0x41, 0x4C, 0x5F, // R A L _
    0x42, 0x52, 0x41, 0x49, // B R A I
    0x4E, 0x5F, 0x32, 0x30, // N _ 2 0
    0x32, 0x36, 0x21, 0x2A, // 2 6 ! *
  ];

  SecureKeyStore._(); // Prevent instantiation

  /// Obfuscate/encrypt a raw plaintext credential string
  static String encryptValue(String plain) {
    if (plain.isEmpty) return '';
    if (plain.startsWith(_encPrefix)) return plain; // Already encrypted

    final bytes = utf8.encode(plain);
    final masked = List<int>.generate(bytes.length, (i) {
      return bytes[i] ^ _maskKey[i % _maskKey.length];
    });

    final b64 = base64.encode(masked);
    return '$_encPrefix$b64';
  }

  /// Deobfuscate/decrypt an encrypted credential string.
  /// Gracefully falls back to plain text if string is legacy unencrypted.
  static String decryptValue(String cipher) {
    if (cipher.isEmpty) return '';
    if (!cipher.startsWith(_encPrefix)) {
      return cipher; // Legacy plain text
    }

    try {
      final b64 = cipher.substring(_encPrefix.length);
      final masked = base64.decode(b64);
      final unmasked = List<int>.generate(masked.length, (i) {
        return masked[i] ^ _maskKey[i % _maskKey.length];
      });
      return utf8.decode(unmasked);
    } catch (_) {
      return cipher;
    }
  }

  /// Load all saved API keys from persistent storage.
  /// Automatically decrypts and migrates any legacy plaintext keys.
  static Future<List<String>> loadKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_keysListPref) ?? [];
      if (rawList.isEmpty) return [];

      bool hasLegacy = false;
      final decryptedList = <String>[];

      for (final item in rawList) {
        if (!item.startsWith(_encPrefix)) {
          hasLegacy = true;
        }
        final decrypted = decryptValue(item).trim();
        if (decrypted.isNotEmpty) {
          decryptedList.add(decrypted);
        }
      }

      // Seamless background migration if legacy keys were detected
      if (hasLegacy && decryptedList.isNotEmpty) {
        await saveKeys(decryptedList);
      }

      return decryptedList;
    } catch (_) {
      return [];
    }
  }

  /// Save the complete list of keys to persistent storage in encrypted format.
  static Future<void> saveKeys(List<String> keys) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedList = keys
          .map((k) => encryptValue(k.trim()))
          .where((k) => k.isNotEmpty)
          .toList();
      await prefs.setStringList(_keysListPref, encryptedList);
    } catch (_) {}
  }

  /// Add a new key if it isn't already in the list.
  /// Returns the updated list.
  static Future<List<String>> addKey(String key) async {
    final keys = await loadKeys();
    final trimmed = key.trim();
    if (trimmed.isNotEmpty && !keys.contains(trimmed)) {
      keys.add(trimmed);
      await saveKeys(keys);
    }
    return keys;
  }

  /// Remove a key at the given index.
  /// Returns the updated list.
  static Future<List<String>> removeKey(int index, List<String> currentKeys) async {
    final keys = List<String>.from(currentKeys);
    if (index >= 0 && index < keys.length) {
      keys.removeAt(index);
      await saveKeys(keys);
    }
    return keys;
  }

  /// Load the active key index from persistent storage.
  static Future<int> loadActiveIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_activeIndexPref) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Persist the active key index.
  static Future<void> saveActiveIndex(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_activeIndexPref, index);
    } catch (_) {}
  }

  /// Clear all stored keys (factory reset / logout).
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keysListPref);
      await prefs.remove(_activeIndexPref);
    } catch (_) {}
  }
}
