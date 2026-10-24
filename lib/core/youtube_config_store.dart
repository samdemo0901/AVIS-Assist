import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_constants.dart';
import 'secure_key_store.dart';

/// Managed Storage for YouTube Channel Intelligence Config, API Keys, and Saved Channels.
class YouTubeConfigStore {
  static const String _keyApiKey = 'avis_yt_api_key';
  static const String _keyEnabled = 'avis_yt_enabled';
  static const String _keyChannels = 'avis_yt_channels_json';

  static Future<String> loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final rawSaved = prefs.getString(_keyApiKey) ?? '';
    if (rawSaved.isEmpty) return GoogleServicesConfig.masterApiKey;

    final decrypted = SecureKeyStore.decryptValue(rawSaved);
    if (!rawSaved.startsWith('enc:v1:') && decrypted.isNotEmpty) {
      // Auto-migrate legacy plaintext key to encrypted format
      await saveApiKey(decrypted);
    }
    return decrypted.isNotEmpty ? decrypted : GoogleServicesConfig.masterApiKey;
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_keyApiKey);
    } else {
      await prefs.setString(_keyApiKey, SecureKeyStore.encryptValue(trimmed));
    }
  }

  static Future<bool> loadEnabledState() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? true;
  }

  static Future<void> saveEnabledState(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
  }

  static Future<List<Map<String, dynamic>>> loadChannels() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_keyChannels);
    if (rawJson == null || rawJson.trim().isEmpty) {
      return [];
    }
    try {
      final decoded = json.decode(rawJson);
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(
          decoded.map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }
    } catch (_) {}
    return [];
  }

  static Future<void> saveChannels(List<Map<String, dynamic>> channels) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(channels);
    await prefs.setString(_keyChannels, encoded);
  }

  static const String _keyOAuthToken = 'avis_yt_oauth_token';
  static const String _keyOAuthEmail = 'avis_yt_oauth_email';
  static const String _keyOAuthChannelTitle = 'avis_yt_oauth_channel_title';
  static const String _keyOAuthAvatarUrl = 'avis_yt_oauth_avatar_url';

  static Future<String> loadOAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyOAuthToken) ?? '';
    if (raw.isEmpty) return '';

    final decrypted = SecureKeyStore.decryptValue(raw);
    if (!raw.startsWith('enc:v1:') && decrypted.isNotEmpty) {
      // Auto-migrate legacy plaintext OAuth token to encrypted format
      await prefs.setString(_keyOAuthToken, SecureKeyStore.encryptValue(decrypted));
    }
    return decrypted;
  }

  static Future<String> loadOAuthEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyOAuthEmail) ?? '';
  }

  static Future<String> loadOAuthChannelTitle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyOAuthChannelTitle) ?? '';
  }

  static Future<String> loadOAuthAvatarUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyOAuthAvatarUrl) ?? '';
  }

  static Future<void> saveOAuthData({
    required String token,
    required String email,
    required String channelTitle,
    required String avatarUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final encToken = SecureKeyStore.encryptValue(token.trim());
    await prefs.setString(_keyOAuthToken, encToken);
    await prefs.setString(_keyOAuthEmail, email.trim());
    await prefs.setString(_keyOAuthChannelTitle, channelTitle.trim());
    await prefs.setString(_keyOAuthAvatarUrl, avatarUrl.trim());
  }

  static Future<void> clearOAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOAuthToken);
    await prefs.remove(_keyOAuthEmail);
    await prefs.remove(_keyOAuthChannelTitle);
    await prefs.remove(_keyOAuthAvatarUrl);
  }

  static Future<Map<String, dynamic>?> getActiveChannel() async {
    final channels = await loadChannels();
    for (final c in channels) {
      if (c['isActive'] == true) return c;
    }
    return channels.isNotEmpty ? channels.first : null;
  }

  static Future<void> setActiveChannel(String channelId) async {
    final channels = await loadChannels();
    for (final c in channels) {
      c['isActive'] = (c['id'] == channelId || c['handle'] == channelId);
    }
    await saveChannels(channels);
  }
}
