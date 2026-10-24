import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'app_constants.dart';
import 'secure_key_store.dart';
import 'gemini_live_client.dart';
import 'audio_stream_manager.dart';
import 'mobile_memory_manager.dart';

/// Central Session & AI Brain State Controller for AVIS Mobile.
/// Encapsulates audio streams, WebSocket Gemini client, API keys,
/// diagnostic logs, transcripts, permissions, and screen cast.
class AvisSessionController extends ChangeNotifier {
  // Core AI Brain Engines
  late final AudioStreamManager audioManager;
  late final MobileMemoryManager memoryManager;
  GeminiLiveClient? geminiClient;

  // AI Session State
  String _activePersona = "AVIS";
  String get activePersona => _activePersona;

  final List<String> _apiKeys = [];
  List<String> get apiKeys => List.unmodifiable(_apiKeys);

  int _activeApiKeyIndex = 0;
  int get activeApiKeyIndex => _activeApiKeyIndex;

  String get apiKey => (_apiKeys.isNotEmpty && _activeApiKeyIndex < _apiKeys.length)
      ? _apiKeys[_activeApiKeyIndex]
      : "";

  bool _isLiveSession = false;
  bool get isLiveSession => _isLiveSession;
  int _consecutiveFailovers = 0;

  String _liveStatusMessage = "● STANDBY";
  String get liveStatusMessage => _liveStatusMessage;

  // Transcripts
  final List<Map<String, String>> _transcriptHistory = [];
  List<Map<String, String>> get transcriptHistory => List.unmodifiable(_transcriptHistory);

  String _latestUserTranscript = "";
  String get latestUserTranscript => _latestUserTranscript;

  String _latestAiTranscript = "";
  String get latestAiTranscript => _latestAiTranscript;

  // Diagnostics & Telemetry
  double _liveAudioLevel = 0.0;
  double get liveAudioLevel => _liveAudioLevel;

  String _keyVerificationStatus = "UNTESTED";
  String get keyVerificationStatus => _keyVerificationStatus;

  Color _keyVerificationColor = AppTheme.alertAmber;
  Color get keyVerificationColor => _keyVerificationColor;

  List<String> get logs => geminiClient?.logs ?? ["● System initialized in standby mode."];
  int get speakerPacketsReceived => geminiClient?.speakerPacketsReceived ?? 0;
  bool get isSpeaking => geminiClient?.isSpeaking ?? false;
  bool get isPassiveSilent => geminiClient?.isPassiveSilent ?? false;

  // APCS System Permissions State
  Map<String, bool> _systemPermissions = {
    "audio": true,
    "camera": false,
    "sms": false,
    "notificationListener": false,
    "accessibility": false,
  };
  Map<String, bool> get systemPermissions => Map.unmodifiable(_systemPermissions);

  // Screen Cast State
  bool _isScreenCastActive = false;
  bool get isScreenCastActive => _isScreenCastActive;
  StreamSubscription? _screenSubscription;
  Timer? _screenCastTimeoutTimer;

  // Stream Subscriptions
  StreamSubscription? _statusSub;
  StreamSubscription? _userTransSub;
  StreamSubscription? _aiTransSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _logSub;
  StreamSubscription? _audioLevelSub;

  // UI Callback hooks
  VoidCallback? onShowSandboxOverlay;
  VoidCallback? onShowYouTubeStudioOverlay;
  VoidCallback? get onShowYouTubeHudOverlay => onShowYouTubeStudioOverlay;
  set onShowYouTubeHudOverlay(VoidCallback? callback) => onShowYouTubeStudioOverlay = callback;
  void Function(String code, String language, String title)? onRequestRunLivePreview;
  void Function(String message, {bool isError})? onToastMessage;
  VoidCallback? onNoApiKeysAvailable;

  AvisSessionController() {
    audioManager = AudioStreamManager();
    memoryManager = MobileMemoryManager();
  }

  void initialize() {
    // Load persisted API keys
    loadApiKeysFromStore();

    // Audio level listener
    _audioLevelSub = audioManager.audioLevelStream.listen((lvl) {
      _liveAudioLevel = _isLiveSession ? lvl : 0.0;
      notifyListeners();
    });

    // Phone call auto-pause & resume
    audioManager.onPhoneCallStateChanged = (isCallActive) {
      if (isCallActive) {
        geminiClient?.addLog("📞 Incoming/Active phone call: Auto-pausing AVIS voice.");
        audioManager.setMute(true);
        geminiClient?.interruptAi();
      } else {
        geminiClient?.addLog("📞 Phone call ended: Auto-resuming AVIS voice.");
        audioManager.setMute(false);
      }
      notifyListeners();
    };

    // Power button assist intent auto-start
    audioManager.onAssistLaunch = () {
      if (!_isLiveSession) {
        geminiClient?.addLog("⚡ Launched via Digital Assistant Power Button. Auto-starting AVIS voice...");
        toggleLiveSession();
      }
    };

    // Notification quick action handlers
    audioManager.onNotificationMuteToggled = () {
      geminiClient?.addLog("🎙️ Mic mute toggled from Android notification: ${audioManager.isMuted ? 'MUTED' : 'UNMUTED'}");
      notifyListeners();
    };

    audioManager.onNotificationEndSession = () {
      geminiClient?.addLog("⏹️ Session ended via Android notification.");
      if (_isLiveSession) {
        toggleLiveSession();
      }
    };

    // Permissions & early client init
    AppChannels.audio.invokeMethod("requestPermissions");
    refreshSystemPermissions();
    _initGeminiClient();
  }

  Future<void> loadApiKeysFromStore() async {
    final savedKeys = await SecureKeyStore.loadKeys();
    final savedIndex = await SecureKeyStore.loadActiveIndex();
    _apiKeys.clear();
    _apiKeys.addAll(savedKeys);
    _activeApiKeyIndex = (savedIndex < savedKeys.length) ? savedIndex : 0;
    notifyListeners();

    if (_apiKeys.isEmpty) {
      onNoApiKeysAvailable?.call();
    }
  }

  void selectApiKey(int index) {
    if (index >= 0 && index < _apiKeys.length) {
      _activeApiKeyIndex = index;
      _keyVerificationStatus = "UNTESTED";
      _keyVerificationColor = AppTheme.alertAmber;
      SecureKeyStore.saveActiveIndex(index);
      geminiClient?.addLog("🔑 Switched active Gemini API Key to #${index + 1}");
      notifyListeners();
    }
  }

  Future<void> _handleAutoKeyFailover() async {
    if (_apiKeys.isEmpty) {
      onToastMessage?.call("No Gemini API keys configured for failover", isError: true);
      return;
    }
    if (_apiKeys.length <= 1) {
      onToastMessage?.call("⚠️ Quota limit hit — only 1 API Key in matrix", isError: true);
      geminiClient?.addLog("❌ API Key quota limit reached. Add additional keys in Settings.");
      return;
    }
    if (_consecutiveFailovers >= _apiKeys.length) {
      geminiClient?.addLog("❌ All ${_apiKeys.length} API keys in stored matrix failed or exceeded quota.");
      onToastMessage?.call("All stored API keys exceeded quota", isError: true);
      _consecutiveFailovers = 0;
      return;
    }

    _consecutiveFailovers++;
    final oldIdx = _activeApiKeyIndex;
    final nextIdx = (_activeApiKeyIndex + 1) % _apiKeys.length;
    _activeApiKeyIndex = nextIdx;
    _keyVerificationStatus = "UNTESTED";
    _keyVerificationColor = AppTheme.alertAmber;
    SecureKeyStore.saveActiveIndex(nextIdx);

    final msg = "⚠️ Key #${oldIdx + 1} Limit Hit — Auto-switched to Key #${nextIdx + 1}";
    onToastMessage?.call(msg, isError: true);
    geminiClient?.addLog("🔄 $msg. Reconnecting Live Voice Session...");
    notifyListeners();

    // Exponential backoff delay (1s -> 2s) to prevent key exhaustion on transient network drops
    final backoffMs = math.min(2500, 1000 * _consecutiveFailovers);
    await Future.delayed(Duration(milliseconds: backoffMs));
    _initGeminiClient();
    await geminiClient?.connect();
  }

  void addApiKey(String newKey) {
    final trimmed = newKey.trim();
    if (trimmed.isEmpty) return;
    if (!_apiKeys.contains(trimmed)) {
      _apiKeys.add(trimmed);
    }
    _activeApiKeyIndex = _apiKeys.indexOf(trimmed);
    _keyVerificationStatus = "UNTESTED";
    _keyVerificationColor = AppTheme.alertAmber;
    SecureKeyStore.saveKeys(List.from(_apiKeys));
    SecureKeyStore.saveActiveIndex(_activeApiKeyIndex);
    geminiClient?.addLog("🔑 Added new Gemini API Key to matrix.");
    notifyListeners();
  }

  void removeApiKey(int index) {
    if (index >= 0 && index < _apiKeys.length) {
      _apiKeys.removeAt(index);
      if (_activeApiKeyIndex >= _apiKeys.length) {
        _activeApiKeyIndex = math.max(0, _apiKeys.length - 1);
      }
      SecureKeyStore.saveKeys(List.from(_apiKeys));
      SecureKeyStore.saveActiveIndex(_activeApiKeyIndex);
      notifyListeners();
    }
  }

  Future<void> refreshSystemPermissions() async {
    try {
      final dynamic res = await AppChannels.permissions.invokeMethod("checkAllPermissions");
      if (res is Map) {
        _systemPermissions = {
          "audio": res["audio"] == true,
          "camera": res["camera"] == true,
          "sms": res["sms"] == true,
          "notificationListener": res["notificationListener"] == true,
          "accessibility": res["accessibility"] == true,
        };
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> requestRuntimePermission(String perm) async {
    try {
      await AppChannels.permissions.invokeMethod("requestRuntimePermission", {"permission": perm});
      await Future.delayed(const Duration(milliseconds: 600));
      refreshSystemPermissions();
    } catch (_) {}
  }

  Future<void> openSystemSetting(String target) async {
    try {
      await AppChannels.permissions.invokeMethod("openSettings", {"target": target});
    } catch (_) {}
  }

  Future<void> toggleFlashlightDirect() async {
    try {
      await AppChannels.automation.invokeMethod("controlFlashlight", {"action": "TOGGLE"});
      geminiClient?.addLog("🔦 Direct Flashlight Toggled.");
    } catch (e) {
      geminiClient?.addLog("❌ Flashlight error: $e");
    }
  }

  Future<void> openWifiSettingsDirect() async {
    try {
      await AppChannels.automation.invokeMethod("controlWifi", {"action": "OPEN_SETTINGS"});
      geminiClient?.addLog("📶 Wi-Fi settings panel opened.");
    } catch (e) {
      geminiClient?.addLog("❌ Wi-Fi panel error: $e");
    }
  }

  Future<void> launchAppDirect(String appName) async {
    try {
      await AppChannels.automation.invokeMethod("launchApp", {"appName": appName});
      geminiClient?.addLog("📱 Launching $appName directly...");
    } catch (e) {
      geminiClient?.addLog("❌ App launch error: $e");
    }
  }

  Future<void> testTypographyDirect() async {
    try {
      await AppChannels.automation.invokeMethod("typeText", {
        "text": "Hello Azhar! AVIS live typography is active.",
        "typographyCadence": true,
        "pressEnter": false,
      });
      geminiClient?.addLog("⌨️ Testing live typography cadence typing...");
    } catch (e) {
      geminiClient?.addLog("❌ Typography test error: $e");
    }
  }

  void togglePassiveListeningMode() {
    if (geminiClient == null) return;
    if (geminiClient!.isPassiveSilent) {
      geminiClient?.exitPassiveSilentMode();
      _liveStatusMessage = "Live Connected";
    } else {
      geminiClient?.enterPassiveSilentMode();
      _liveStatusMessage = "👁️ PASSIVE (SILENT LISTENING)";
    }
    notifyListeners();
  }

  void _initGeminiClient() {
    _cleanupGeminiClient();

    geminiClient = GeminiLiveClient(
      apiKey: apiKey,
      audioManager: audioManager,
      memoryManager: memoryManager,
      currentProfile: _activePersona,
    );

    geminiClient!.onRequestSwitchProfile = (target) {
      setPersona(target);
    };

    geminiClient!.onRequestSwitchAudioRoute = (route) {
      audioManager.switchAudioRoute(route);
      geminiClient?.addLog("🎧 Voice command routed audio output to: $route");
      notifyListeners();
    };

    geminiClient!.onShowSandboxPopup = (title) {
      onShowSandboxOverlay?.call();
      geminiClient?.addLog("📦 Voice command launched Mobile Sandbox Overlay.");
    };

    geminiClient!.onRequestShowYouTubeStudio = () {
      onShowYouTubeStudioOverlay?.call();
      geminiClient?.addLog("🔴 Voice command launched YouTube Creator Studio Overlay.");
    };

    geminiClient!.onRequestRunLivePreview = (code, language, title) {
      onRequestRunLivePreview?.call(code, language, title);
      geminiClient?.addLog("🚀 Launched Live Playground ($language) for '$title'.");
    };

    geminiClient!.onRequestToggleScreenCast = (enable) {
      toggleScreenCast(enable);
    };

    geminiClient!.onRequestNextApiKey = () {
      _handleAutoKeyFailover();
    };

    _statusSub = geminiClient!.statusStream.listen((msg) {
      _liveStatusMessage = msg;
      notifyListeners();
    });

    _logSub = geminiClient!.logStream.listen((log) {
      notifyListeners();
    });

    _stateSub = geminiClient!.stateStream.listen((state) {
      _isLiveSession = state != GeminiSessionState.disconnected &&
          state != GeminiSessionState.error;
      if (state == GeminiSessionState.connected || state == GeminiSessionState.listening) {
        _consecutiveFailovers = 0;
      }
      if (state == GeminiSessionState.disconnected || state == GeminiSessionState.error) {
        audioManager.startSimulatedMicStream();
      }
      notifyListeners();
    });

    _userTransSub = geminiClient!.userTranscriptStream.listen((text) {
      if (text.trim().isNotEmpty) {
        _latestUserTranscript = text;
        _transcriptHistory.add({'sender': 'Azhar', 'text': text});
        notifyListeners();
      }
    });

    _aiTransSub = geminiClient!.aiTranscriptStream.listen((text) {
      if (text.trim().isNotEmpty) {
        _latestAiTranscript = text;
        _transcriptHistory.add({'sender': _activePersona, 'text': text});
        notifyListeners();
      }
    });
  }

  void _cleanupGeminiClient() {
    _statusSub?.cancel();
    _stateSub?.cancel();
    _userTransSub?.cancel();
    _aiTransSub?.cancel();
    _logSub?.cancel();
    geminiClient?.disconnect();
    geminiClient = null;
  }

  Future<void> toggleScreenCast([bool? forceState]) async {
    final targetState = forceState ?? !_isScreenCastActive;
    if (targetState == _isScreenCastActive) return;

    if (!targetState) {
      _screenCastTimeoutTimer?.cancel();
      _screenCastTimeoutTimer = null;
      _screenSubscription?.cancel();
      _screenSubscription = null;
      try {
        await AppChannels.automation.invokeMethod("stopScreenCast");
      } catch (_) {}
      _isScreenCastActive = false;
      onToastMessage?.call("Screen Cast Stopped", isError: false);
      notifyListeners();
    } else {
      try {
        final dynamic started = await AppChannels.automation.invokeMethod("startScreenCast");
        if (started == true) {
          onToastMessage?.call("Requesting Screen Capture — Accept Android Prompt", isError: false);
          _listenToScreenStream();

          _screenCastTimeoutTimer?.cancel();
          _screenCastTimeoutTimer = Timer(const Duration(seconds: 5), () {
            if (!_isScreenCastActive) {
              _screenSubscription?.cancel();
              _screenSubscription = null;
              onToastMessage?.call("Screen Cast timed out — no frames received", isError: true);
              notifyListeners();
            }
          });
        } else {
          onToastMessage?.call("Could not start Screen Cast", isError: true);
        }
      } catch (e) {
        onToastMessage?.call("Screen Cast error: $e", isError: true);
      }
    }
  }

  DateTime? _lastScreenFrameTime;

  void _listenToScreenStream() {
    _screenSubscription?.cancel();
    _screenSubscription = AppChannels.screenStream
        .receiveBroadcastStream()
        .listen((dynamic data) {
      if (data is Uint8List && geminiClient != null) {
        final now = DateTime.now();
        // Throttle screen cast frames to max 2 FPS (500ms minimum interval)
        if (_lastScreenFrameTime != null &&
            now.difference(_lastScreenFrameTime!).inMilliseconds < 500) {
          return;
        }
        _lastScreenFrameTime = now;

        if (!_isScreenCastActive) {
          _screenCastTimeoutTimer?.cancel();
          _screenCastTimeoutTimer = null;
          _isScreenCastActive = true;
          onToastMessage?.call("Screen Cast Live — Streaming to AI Vision", isError: false);
          notifyListeners();
        }
        geminiClient?.sendScreenFrameChunk(data);
      }
    }, onError: (err) {
      _screenCastTimeoutTimer?.cancel();
      _screenCastTimeoutTimer = null;
      _isScreenCastActive = false;
      onToastMessage?.call("Screen Stream error: $err", isError: true);
      notifyListeners();
    });
  }

  Future<void> testApiKey() async {
    _keyVerificationStatus = "TESTING...";
    _keyVerificationColor = AppTheme.alertAmber;
    notifyListeners();

    try {
      final client = HttpClient();
      final uri = Uri.parse("https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey");
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 8));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200 && body.contains("models/")) {
        _keyVerificationStatus = "VALID (200 OK)";
        _keyVerificationColor = AppTheme.cyberGreen;
        geminiClient?.addLog("✅ API Key verified: Google 200 OK (models catalog accessible)");
      } else {
        _keyVerificationStatus = "FAILED (${response.statusCode})";
        _keyVerificationColor = Colors.redAccent;
        geminiClient?.addLog("❌ API Key check failed: HTTP ${response.statusCode}");
      }
    } catch (e) {
      _keyVerificationStatus = "NET ERROR";
      _keyVerificationColor = Colors.redAccent;
      geminiClient?.addLog("❌ API Key check exception: $e");
    }
    notifyListeners();
  }

  Future<void> testSpeakerChime() async {
    geminiClient?.addLog("🔊 Test Speaker Chime dispatched to native AudioTrack");
    await audioManager.testSpeakerChime();
  }

  Future<void> testHardwareMic() async {
    geminiClient?.addLog("🎙️ Testing Hardware Microphone stream...");
    try {
      AppChannels.audio.invokeMethod("requestPermissions");
      await audioManager.startRealMic();
    } catch (e) {
      geminiClient?.addLog("❌ Mic test error: $e");
    }
  }

  Future<void> toggleLiveSession() async {
    if (_isLiveSession) {
      audioManager.playSciFiEndChime();
      await geminiClient?.disconnect();
      audioManager.cancelSimulation();
      _isLiveSession = false;
      _liveAudioLevel = 0.0;
      _liveStatusMessage = "● STANDBY";
      notifyListeners();
    } else {
      if (apiKey.trim().isEmpty) {
        onNoApiKeysAvailable?.call();
        return;
      }
      audioManager.playSciFiStartChime();
      audioManager.cancelSimulation();
      _initGeminiClient();
      await geminiClient?.connect();
      notifyListeners();
    }
  }

  void setPersona(String persona) {
    if (_activePersona == persona) return;
    _activePersona = persona;
    geminiClient?.switchPersona(persona);
    notifyListeners();
  }

  void toggleMute() {
    audioManager.toggleMute();
    notifyListeners();
  }

  void interruptAi() {
    geminiClient?.interruptAi();
    notifyListeners();
  }

  void sendTextMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (!_isLiveSession) {
      await toggleLiveSession();
      await Future.delayed(const Duration(milliseconds: 600));
    }

    geminiClient?.sendTextMessage(trimmed);
  }

  void clearLogs() {
    geminiClient?.logs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _screenCastTimeoutTimer?.cancel();
    _screenSubscription?.cancel();
    _cleanupGeminiClient();
    _audioLevelSub?.cancel();
    audioManager.dispose();
    super.dispose();
  }
}
