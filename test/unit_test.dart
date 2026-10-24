import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:avis_mobile/core/app_constants.dart';
import 'package:avis_mobile/core/secure_key_store.dart';
import 'package:avis_mobile/core/avis_session_controller.dart';
import 'package:avis_mobile/core/gemini_tool_declarations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppVersion & AppChannels Tests', () {
    test('AppVersion constants should reflect current version 3.32.0', () {
      expect(AppVersion.current, equals('3.32.0'));
      expect(AppVersion.displayName, equals('AVIS Mobile v3.32.0'));
      expect(AppVersion.fullEcosystem, contains('3.32.0'));
    });

    test('AppChannels method channels should have correct channel names', () {
      expect(AppChannels.audio.name, equals('com.example.avis_mobile/audio'));
      expect(AppChannels.automation.name, equals('com.example.avis_mobile/automation'));
      expect(AppChannels.permissions.name, equals('com.example.avis_mobile/permissions'));
      expect(AppChannels.screenStream.name, equals('com.example.avis_mobile/screen_stream'));
    });
  });

  group('GeminiToolDeclarations Registry Tests', () {
    test('getDeclarations should return complete tool catalog with valid schemas', () {
      final tools = GeminiToolDeclarations.getDeclarations();
      expect(tools.length, equals(43));

      final toolNames = GeminiToolDeclarations.getAllToolNames();
      expect(toolNames.length, equals(43));

      // Key core tools verification
      expect(toolNames, contains('remember_fact'));
      expect(toolNames, contains('get_device_telemetry'));
      expect(toolNames, contains('web_search'));
      expect(toolNames, contains('perform_screen_action'));
      expect(toolNames, contains('run_live_preview'));
      expect(toolNames, contains('show_youtube_studio_overlay'));

      // Validate all schemas have required keys
      for (final tool in tools) {
        expect(tool['name'], isNotEmpty);
        expect(tool['description'], isNotEmpty);
        expect(tool['parameters'], isA<Map<String, dynamic>>());
      }
    });
  });

  group('SecureKeyStore Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('encryptValue & decryptValue should correctly obfuscate and restore keys', () {
      const rawKey = 'AIzaSySecretSampleKey_987654321';
      final encrypted = SecureKeyStore.encryptValue(rawKey);

      expect(encrypted, startsWith('enc:v1:'));
      expect(encrypted, isNot(equals(rawKey)));

      final decrypted = SecureKeyStore.decryptValue(encrypted);
      expect(decrypted, equals(rawKey));
    });

    test('saveKeys should persist encrypted values on disk and loadKeys should decrypt', () async {
      final sampleKeys = ['AIzaSyKeyOne_12345', 'AIzaSyKeyTwo_67890'];
      await SecureKeyStore.saveKeys(sampleKeys);

      // Verify raw storage contains encrypted strings
      final prefs = await SharedPreferences.getInstance();
      final rawStored = prefs.getStringList('avis_gemini_api_keys') ?? [];
      expect(rawStored.length, equals(2));
      expect(rawStored.every((k) => k.startsWith('enc:v1:')), isTrue);

      // Verify loadKeys returns decrypted originals
      final loaded = await SecureKeyStore.loadKeys();
      expect(loaded, equals(sampleKeys));
    });

    test('loadKeys should seamlessly migrate legacy unencrypted keys', () async {
      // Simulate existing user with legacy plaintext key saved
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('avis_gemini_api_keys', ['AIzaSyLegacyKey_111']);

      // Call loadKeys
      final loaded = await SecureKeyStore.loadKeys();
      expect(loaded, equals(['AIzaSyLegacyKey_111']));

      // Confirm raw stored key is now migrated to encrypted format on disk
      final rawMigrated = prefs.getStringList('avis_gemini_api_keys') ?? [];
      expect(rawMigrated.first, startsWith('enc:v1:'));
    });

    test('addKey & removeKey should update stored keys correctly', () async {
      await SecureKeyStore.addKey('AIzaSyNewKey_999');
      var keys = await SecureKeyStore.loadKeys();
      expect(keys.contains('AIzaSyNewKey_999'), isTrue);

      await SecureKeyStore.removeKey(0, keys);
      keys = await SecureKeyStore.loadKeys();
      expect(keys.contains('AIzaSyNewKey_999'), isFalse);
    });

    test('saveActiveIndex & loadActiveIndex should persist selected index', () async {
      await SecureKeyStore.saveActiveIndex(2);
      final index = await SecureKeyStore.loadActiveIndex();
      expect(index, equals(2));
    });
  });

  group('AvisSessionController State Unit Tests', () {
    late AvisSessionController controller;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      controller = AvisSessionController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('Initial controller state should be default standby', () {
      expect(controller.activePersona, equals('AVIS'));
      expect(controller.isLiveSession, isFalse);
      expect(controller.liveAudioLevel, equals(0.0));
      expect(controller.isSpeaking, isFalse);
      expect(controller.isPassiveSilent, isFalse);
    });

    test('addApiKey should append key and notify listeners', () {
      controller.addApiKey('AIzaSyTestKey_111');
      expect(controller.apiKeys.length, equals(1));
      expect(controller.apiKey, equals('AIzaSyTestKey_111'));
      expect(controller.activeApiKeyIndex, equals(0));
    });

    test('selectApiKey should change active key index', () {
      controller.addApiKey('AIzaSyTestKey_111');
      controller.addApiKey('AIzaSyTestKey_222');
      expect(controller.apiKeys.length, equals(2));

      controller.selectApiKey(1);
      expect(controller.activeApiKeyIndex, equals(1));
      expect(controller.apiKey, equals('AIzaSyTestKey_222'));
    });

    test('removeApiKey should remove key and adjust index safely', () {
      controller.addApiKey('AIzaSyTestKey_111');
      controller.addApiKey('AIzaSyTestKey_222');
      controller.selectApiKey(1);

      controller.removeApiKey(1);
      expect(controller.apiKeys.length, equals(1));
      expect(controller.activeApiKeyIndex, equals(0));
    });

    test('setPersona should switch active persona cleanly', () {
      controller.setPersona('BIBA');
      expect(controller.activePersona, equals('BIBA'));

      controller.setPersona('AVIS');
      expect(controller.activePersona, equals('AVIS'));
    });

    test('toggleMute should toggle audio manager mute state', () {
      final initialMute = controller.audioManager.isMuted;
      controller.toggleMute();
      expect(controller.audioManager.isMuted, equals(!initialMute));
    });
  });
}
