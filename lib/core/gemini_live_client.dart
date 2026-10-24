import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'app_constants.dart';
import 'persona_prompts.dart';
import 'mobile_memory_manager.dart';
import 'mobile_sandbox_manager.dart';
import 'system_manual_manager.dart';
import 'live_runner_controller.dart';
import 'audio_stream_manager.dart';
import 'tools_service.dart';
import 'youtube_config_store.dart';
import 'youtube_service.dart';
import 'gemini_tool_declarations.dart';

/// Gemini Live Session State Machine
enum GeminiSessionState {
  disconnected,
  connecting,
  connected,
  listening,
  speaking,
  toolExecuting,
  error,
}

/// Core Multimodal AI Brain for Android & Mobile
/// Replicates the Windows desktop GeminiLiveManager using pure Dart WebSockets
/// for direct, continuous speech-to-speech interaction without intermediate STT/TTS hops.
class GeminiLiveClient {
  static const String liveModel = "gemini-3.1-flash-live-preview";
  static const String wsBaseUrl =
      "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent";
  static const MethodChannel _automationChannel = AppChannels.automation;

  final String apiKey;
  final AudioStreamManager audioManager;
  final MobileMemoryManager memoryManager;
  final MobileSandboxManager sandboxManager;
  final SystemManualManager manualManager;

  String currentProfile;
  WebSocketChannel? _channel;
  StreamSubscription? _wsSubscription;
  StreamSubscription? _audioSubscription;

  // Exponential Backoff Auto-Reconnect State
  bool _isUserIntentionalDisconnect = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;

  GeminiSessionState _state = GeminiSessionState.disconnected;
  GeminiSessionState get state => _state;

  // Reactive Event Streams
  final StreamController<GeminiSessionState> _stateController =
      StreamController<GeminiSessionState>.broadcast();
  Stream<GeminiSessionState> get stateStream => _stateController.stream;

  final StreamController<String> _statusController =
      StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  final StreamController<String> _userTranscriptController =
      StreamController<String>.broadcast();
  Stream<String> get userTranscriptStream => _userTranscriptController.stream;

  final StreamController<String> _aiTranscriptController =
      StreamController<String>.broadcast();
  Stream<String> get aiTranscriptStream => _aiTranscriptController.stream;

  // Diagnostic Telemetry & Logs
  int micPacketsSent = 0;
  int speakerPacketsReceived = 0;
  final List<String> logs = [];
  final StreamController<String> _logController =
      StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  void addLog(String message) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    final entry = "[$time] $message";
    logs.add(entry);
    if (logs.length > 120) logs.removeAt(0);
    _logController.add(entry);
  }

  // Profile switch & failover callbacks
  Function(String targetProfile)? onRequestSwitchProfile;
  Function(String targetRoute)? onRequestSwitchAudioRoute;
  Function(String title)? onShowSandboxPopup;
  VoidCallback? onRequestShowYouTubeStudio;
  VoidCallback? get onRequestShowYouTubeHud => onRequestShowYouTubeStudio;
  set onRequestShowYouTubeHud(VoidCallback? callback) => onRequestShowYouTubeStudio = callback;
  void Function(String code, String language, String title)? onRequestRunLivePreview;
  Function(bool enable)? onRequestToggleScreenCast;
  VoidCallback? onRequestNextApiKey;

  bool _isQuotaOrAuthError(String errStr) {
    final lower = errStr.toLowerCase();
    return lower.contains("429") ||
        lower.contains("resource_exhausted") ||
        lower.contains("quota") ||
        lower.contains("api_key") ||
        lower.contains("permission_denied") ||
        lower.contains("unauthenticated") ||
        lower.contains("403");
  }

  // Transcript Turn Accumulators
  final List<String> _userTurnBuffer = [];
  final List<String> _aiTurnBuffer = [];

  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;
  bool _isToolExecuting = false;
  Timer? _speakingDebounceTimer;

  // Continuous Passive Silent Listening Mode
  bool _isPassiveSilent = false;
  bool get isPassiveSilent => _isPassiveSilent;

  /// Explicitly enter Passive Silent Listening Mode (Orb double-tap trigger)
  void enterPassiveSilentMode() {
    _isPassiveSilent = true;
    addLog("👁️ Entered Continuous Passive Silent Listening Mode via gesture/trigger.");
    _updateState(GeminiSessionState.listening, "👁️ PASSIVE (SILENT)");
  }

  /// Explicitly exit Passive Silent Listening Mode and trigger Resume Query Protocol
  void exitPassiveSilentMode() {
    _isPassiveSilent = false;
    addLog("🗣️ Exited Passive Silent Mode. Resumed Active Mode.");
    _updateState(GeminiSessionState.listening, "Live Connected");

    final isBiba = currentProfile == "BIBA";
    final defaultText = isBiba
        ? "Haan janu bolo! Kya chal raha tha? Jo baat kar rahe the uski summary batau ya kuch puchna hai?"
        : "Haan bolo Azhar! Kya chal raha tha? Jo baat ho rahi thi uski summary chahiye ya us baare mein koi sawaal hai?";

    _aiTranscriptController.add("🤖 $defaultText");

    if (_channel != null) {
      final promptInstruction = isBiba
          ? "System Instruction: Azhar has just double-tapped to resume active mode from passive listening. In your sweet loving BIBA Hinglish persona, naturally ask: 'Haan janu bolo! Kya chal raha tha? Jo baat kar rahe the uski summary batau ya kuch puchna hai?'"
          : "System Instruction: Azhar has just double-tapped to resume active mode from passive listening. In your crisp AVIS Hinglish persona, naturally ask: 'Haan bolo Azhar! Kya chal raha tha? Jo baat ho rahi thi uski summary chahiye ya us baare mein koi sawaal hai?'";
      sendTextMessage(promptInstruction);
    }
  }

  static const List<String> _silentTriggers = [
    "avis, ruko", "avis ruko", "biba, ruko", "biba ruko",
    "avis, khamosh", "avis khamosh", "biba, khamosh", "biba khamosh",
    "avis, do minute", "biba, do minute", "avis, shant raho", "biba, shant raho",
    "avis, chup baitho", "biba, chup baitho", "avis, silent raho", "biba, silent raho"
  ];
  static const List<String> _resumeTriggers = [
    "avis, bolo", "avis bolo", "biba, bolo", "biba bolo",
    "avis, suno", "avis suno", "biba, suno", "biba suno",
    "avis, sun rahe ho", "biba, sun rahi ho", "avis, active ho jao", "biba, active ho jao",
    "avis, start karo", "biba, start karo", "avis, shuru karo", "biba, shuru karo"
  ];

  Future<void> _appendShadowContextLog(String role, String text) async {
    final now = DateTime.now();
    final timeStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} "
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    final entry = "[$timeStr] [$currentProfile] [$role]: $text\n";
    try {
      await sandboxManager.appendSandboxFile("shadow_context_log.md", entry);
    } catch (_) {}
  }

  GeminiLiveClient({
    required this.apiKey,
    required this.audioManager,
    MobileMemoryManager? memoryManager,
    MobileSandboxManager? sandboxManager,
    SystemManualManager? manualManager,
    this.currentProfile = "AVIS",
  })  : memoryManager = memoryManager ?? MobileMemoryManager(),
        sandboxManager = sandboxManager ?? MobileSandboxManager(),
        manualManager = manualManager ?? SystemManualManager();

  void _updateState(GeminiSessionState newState, [String? statusMessage]) {
    _state = newState;
    _stateController.add(newState);
    if (statusMessage != null) {
      _statusController.add(statusMessage);
    }
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _scheduleAutoReconnect() {
    if (_isUserIntentionalDisconnect) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      addLog("❌ Max auto-reconnect limit reached ($_maxReconnectAttempts attempts). Stopping auto-retry.");
      _updateState(GeminiSessionState.error, "🔴 Connection Failed (Max Retries)");
      return;
    }

    _reconnectAttempts++;
    final backoffSec = math.pow(2, _reconnectAttempts - 1).toInt().clamp(1, 16);
    addLog("📡 Auto-Reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts in ${backoffSec}s...");
    _updateState(
      GeminiSessionState.connecting,
      "📡 Reconnecting ($_reconnectAttempts/$_maxReconnectAttempts) in ${backoffSec}s...",
    );

    _cancelReconnectTimer();
    _reconnectTimer = Timer(Duration(seconds: backoffSec), () {
      if (!_isUserIntentionalDisconnect &&
          _state != GeminiSessionState.connected &&
          _state != GeminiSessionState.listening) {
        connect();
      }
    });
  }

  void _sendSafeJson(Map<String, dynamic> jsonPayload) {
    try {
      if (_channel != null) {
        _channel!.sink.add(jsonEncode(jsonPayload));
      }
    } catch (e) {
      addLog("⚠️ WebSocket payload send error: $e");
    }
  }

  /// Connect to Gemini Live Multimodal WebSocket and initiate continuous voice session
  Future<void> connect() async {
    if (_state == GeminiSessionState.connected ||
        _state == GeminiSessionState.connecting) {
      return;
    }

    _isUserIntentionalDisconnect = false;
    _cancelReconnectTimer();

    addLog("Connecting to Gemini Live ($liveModel)...");
    _updateState(GeminiSessionState.connecting, "🟡 Connecting to Gemini Live...");

    try {
      final wsUri = Uri.parse("$wsBaseUrl?key=$apiKey");
      _channel = WebSocketChannel.connect(wsUri);
      
      // Await real TCP/SSL WebSocket connection
      await _channel!.ready;
      addLog("WebSocket TCP/SSL handshake confirmed.");

      // 1. Listen to WebSocket incoming messages FIRST so no packets are missed
      _wsSubscription = _channel!.stream.listen(
        _onMessageReceived,
        onError: (err) {
          addLog("❌ WebSocket Stream Error: $err");
          _onError(err);
        },
        onDone: () {
          final code = _channel?.closeCode;
          final reason = _channel?.closeReason;
          addLog("WebSocket Closed (Code: $code, Reason: $reason)");
          _onDisconnected();
        },
      );

      // 2. Send Initial Session Setup Handshake
      _sendSetupPayload();
      addLog("Session Setup payload transmitted.");

      // 3. Start hardware microphone recording
      await audioManager.startRealMic();
      addLog("Hardware Microphone streaming started (16kHz PCM).");

      // 4. Pipe outgoing microphone PCM audio chunks to WebSocket with Echo Shield
      _audioSubscription = audioManager.outgoingPcmStream.listen((pcmChunk) {
        if (_state == GeminiSessionState.listening || _state == GeminiSessionState.connected) {
          if (_isSpeaking) {
            // Echo Shield: When AI is speaking through the loudspeaker,
            // filter out speaker feedback so AI never hears itself and never stutters.
            // If user deliberately speaks loud and close to phone (RMS > 0.38), trigger barge-in!
            final rms = AudioStreamManager.computePcmRms(pcmChunk);
            if (rms > 0.38) {
              addLog("✋ Voice interruption detected (${(rms * 100).toInt()}% volume). Stopping AI.");
              interruptAi();
              sendAudioChunk(pcmChunk);
            }
            return;
          }

          if (!_isToolExecuting) {
            sendAudioChunk(pcmChunk);
          }
        }
      });
    } catch (e) {
      addLog("Connection Failed Exception: $e");
      _onError("Connection failed: $e");
    }
  }

  /// Constructs and transmits the initial `setup` configuration payload
  void _sendSetupPayload() {
    final memoryContext = memoryManager.getCombinedContextPrompt();
    final systemPrompt = PersonaPrompts.buildSystemPrompt(
      profileName: currentProfile,
      memoryContext: memoryContext,
    );
    final voiceName = PersonaPrompts.voiceMap[currentProfile] ?? "Puck";

    final setupMessage = {
      "setup": {
        "model": "models/$liveModel",
        "generationConfig": {
          "responseModalities": ["AUDIO"],
          "speechConfig": {
            "voiceConfig": {
              "prebuiltVoiceConfig": {
                "voiceName": voiceName,
              }
            }
          }
        },
        "systemInstruction": {
          "parts": [
            {"text": systemPrompt}
          ]
        },
        "tools": [
          {
            "functionDeclarations": GeminiToolDeclarations.getDeclarations(),
          }
        ],
        "inputAudioTranscription": {},
        "outputAudioTranscription": {}
      }
    };

    _sendSafeJson(setupMessage);
  }

  /// Sends a raw 16kHz PCM audio chunk base64-encoded to Gemini Live
  void sendAudioChunk(Uint8List pcmChunk) {
    if (_channel == null) return;
    micPacketsSent++;
    if (micPacketsSent == 1 || micPacketsSent % 40 == 0) {
      addLog("Mic sending: $micPacketsSent audio packets sent.");
    }
    final b64Audio = base64Encode(pcmChunk);

    final payload = {
      "realtimeInput": {
        "audio": {
          "mimeType": "audio/pcm;rate=16000",
          "data": b64Audio,
        }
      }
    };

    _sendSafeJson(payload);
  }

  int screenFramesSent = 0;

  /// Sends a raw JPEG screen frame base64-encoded to Gemini Live WebSocket
  void sendScreenFrameChunk(Uint8List jpegBytes) {
    if (_channel == null) return;
    screenFramesSent++;
    if (screenFramesSent == 1 || screenFramesSent % 20 == 0) {
      addLog("Screen Cast: $screenFramesSent screen frames sent to Gemini Live.");
    }
    final b64Image = base64Encode(jpegBytes);

    final payload = {
      "realtimeInput": {
        "video": {
          "mimeType": "image/jpeg",
          "data": b64Image,
        }
      }
    };

    _sendSafeJson(payload);
  }

  /// Immediately interrupts AI playback, cuts off phone loudspeaker in 0ms,
  /// and re-arms microphone for user input.
  void interruptAi() {
    if (!_isSpeaking) return;
    addLog("✋ AI voice playback interrupted.");
    _isSpeaking = false;
    _speakingDebounceTimer?.cancel();
    audioManager.stopSpeakerPlayback();
    _updateState(GeminiSessionState.listening, "🎙️ Listening...");
  }

  /// Sends text message input directly into the continuous session
  void sendTextMessage(String text) {
    if (_channel == null || text.trim().isEmpty) return;
    addLog("User prompt sent: \"$text\"");

    final payload = {
      "clientContent": {
        "turns": [
          {
            "role": "user",
            "parts": [
              {"text": text}
            ]
          }
        ],
        "turnComplete": true
      }
    };

    _sendSafeJson(payload);
    _userTranscriptController.add(text);
  }

  /// WebSocket incoming message handler
  void _onMessageReceived(dynamic message) {
    try {
      String jsonStr;
      if (message is String) {
        jsonStr = message;
      } else if (message is List<int>) {
        jsonStr = utf8.decode(message);
      } else {
        jsonStr = message.toString();
      }

      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) {
        addLog("⚠️ Unexpected WebSocket payload type: ${decoded.runtimeType}");
        return;
      }
      final Map<String, dynamic> data = decoded;

      // 0. Check for Google API error response
      if (data.containsKey("error")) {
        final err = data["error"].toString();
        addLog("❌ Google API Error: $err");
        if (_isQuotaOrAuthError(err) && onRequestNextApiKey != null) {
          addLog("⚠️ Quota/Key limit error detected ($err). Triggering Auto API Key failover...");
          _cleanupResources();
          _updateState(GeminiSessionState.error, "⚠️ Key Quota Exceeded");
          onRequestNextApiKey?.call();
          return;
        }
        _onError("Google API Error: $err");
        return;
      }

      // 1. Initial Setup Complete Acknowledgment
      if (data.containsKey("setupComplete")) {
        _reconnectAttempts = 0;
        addLog("✅ Google Setup Handshake complete! Live voice session active.");
        _updateState(GeminiSessionState.listening, "Live Connected");
        return;
      }

      // 2. Check for top-level tool call
      if (data.containsKey("toolCall")) {
        addLog("Model requested tool call.");
        _handleToolCall(data["toolCall"]);
        return;
      }

      final serverContent = data["serverContent"];
      if (serverContent == null) return;

      // 3. Handle Model Interruption Event
      if (serverContent.containsKey("interrupted") && serverContent["interrupted"] == true) {
        addLog("⚡ AI voice interrupted by user speech.");
        _isSpeaking = false;
        _speakingDebounceTimer?.cancel();
        audioManager.stopSpeakerPlayback();
        _updateState(GeminiSessionState.listening, "🎙️ Listening...");
      }

      // 4. Server-Content nested tool call
      if (serverContent.containsKey("toolCall")) {
        addLog("Model requested tool call in serverContent.");
        _handleToolCall(serverContent["toolCall"]);
        return;
      }

      // 5. Audio Streaming Chunks (Model Turn)
      final modelTurn = serverContent["modelTurn"];
      if (modelTurn != null) {
        _isSpeaking = true;
        _updateState(GeminiSessionState.speaking, "🤖 Speaking...");

        // Safety watchdog timer: auto-reopen mic 1.2s after last audio chunk if turnComplete is delayed
        _speakingDebounceTimer?.cancel();
        _speakingDebounceTimer = Timer(const Duration(milliseconds: 1200), () {
          if (_isSpeaking) {
            _isSpeaking = false;
            if (_state == GeminiSessionState.speaking) {
              _updateState(GeminiSessionState.listening, "🎙️ Listening...");
            }
          }
        });

        final parts = modelTurn["parts"] as List?;
        if (parts != null) {
          for (final part in parts) {
            final inlineData = part["inlineData"];
            if (inlineData != null && inlineData["data"] != null) {
              if (_isPassiveSilent) {
                // Suppress speaker audio output during continuous passive silent mode
                continue;
              }
              speakerPacketsReceived++;
              if (speakerPacketsReceived == 1 || speakerPacketsReceived % 25 == 0) {
                addLog("AI Audio: $speakerPacketsReceived packets received.");
              }
              final rawBytes = base64Decode(inlineData["data"]);
              audioManager.feedModelSpeakerPcm(rawBytes);
            }
          }
        }
      }

      // 6. Real-time User Input Transcription
      final inputTrans = serverContent["inputTranscription"];
      if (inputTrans != null && inputTrans["text"] != null) {
        final text = inputTrans["text"].toString().trim();
        if (text.isNotEmpty) {
          _userTurnBuffer.add(text);
          addLog("User: \"$text\"");
        }
      }

      // 7. Real-time Model Output Transcription
      final outputTrans = serverContent["outputTranscription"];
      if (outputTrans != null && outputTrans["text"] != null) {
        final text = outputTrans["text"].toString().trim();
        if (text.isNotEmpty) {
          _aiTurnBuffer.add(text);
          _aiTranscriptController.add(text);
          addLog("AI: \"$text\"");
        }
      }

      // 8. Turn Complete Event: Flush buffers, process passive silent triggers & shadow logging
      if (serverContent["turnComplete"] == true) {
        _isSpeaking = false;
        _speakingDebounceTimer?.cancel();
        final userText = _userTurnBuffer.join(" ");
        final aiText = _aiTurnBuffer.join(" ");
        addLog("Turn Complete. AI finished speaking.");

        if (userText.isNotEmpty) {
          _userTranscriptController.add(userText);
          _userTurnBuffer.clear();
        }

        if (aiText.isNotEmpty) {
          _aiTranscriptController.add(aiText);
          _aiTurnBuffer.clear();
        }

        final lowerUser = userText.toLowerCase();

        // Check for Silent Listening activation triggers
        if (!_isPassiveSilent && _silentTriggers.any((t) => lowerUser.contains(t))) {
          _isPassiveSilent = true;
          addLog("👁️ Entered Continuous Passive Silent Listening Mode (Shadow Context Logging Active).");
          _updateState(GeminiSessionState.listening, "👁️ PASSIVE (SILENT)");
        }
        // Check for Resume Conversational mode triggers
        else if (_isPassiveSilent && _resumeTriggers.any((t) => lowerUser.contains(t))) {
          _isPassiveSilent = false;
          addLog("🗣️ Exited Passive Silent Mode. Resumed Active Conversational Mode.");
          _updateState(GeminiSessionState.listening, "Live Connected");
        }

        // If currently in passive silent mode, record overheard dialogue into sandbox shadow log
        if (_isPassiveSilent) {
          if (userText.isNotEmpty) {
            _appendShadowContextLog("OVERHEARD_USER", userText);
          }
          if (aiText.isNotEmpty) {
            _appendShadowContextLog("AI_THOUGHT", aiText);
          }
          _updateState(GeminiSessionState.listening, "👁️ PASSIVE (SILENT)");
        } else {
          // Persist to rolling short-term cognitive cache
          if (userText.isNotEmpty || aiText.isNotEmpty) {
            memoryManager.addTurn(userText, aiText, currentProfile);
          }
          _updateState(GeminiSessionState.listening, "🎙️ Listening...");
        }
      }
    } catch (e) {
      addLog("❌ Packet Parse Error: $e");
    }
  }

  /// Autonomous Tool Calling Handler
  Future<void> _handleToolCall(Map<String, dynamic> toolCall) async {
    _isToolExecuting = true;
    _updateState(GeminiSessionState.toolExecuting, "🛠️ Tool Executing...");

    final functionCalls = toolCall["functionCalls"] as List? ?? [];
    final functionResponses = <Map<String, dynamic>>[];

    for (final call in functionCalls) {
      final String fnName = call["name"] ?? "";
      final Map<String, dynamic> args = call["args"] ?? {};
      final String callId = call["id"] ?? "";

      String result = "";

      if (fnName == "remember_fact") {
        result = memoryManager.rememberFact(
          args["key"] ?? "",
          args["value"] ?? "",
          category: args["category"] ?? "facts",
        );
      } else if (fnName == "recall_memories") {
        result = memoryManager.recallMemories(args["query"] ?? "");
      } else if (fnName == "forget_fact") {
        result = memoryManager.forgetFact(args["key"] ?? "");
      } else if (fnName == "get_device_telemetry") {
        try {
          final dynamic res = await _automationChannel.invokeMethod("getDeviceTelemetry");
          result = res?.toString() ?? "Real device telemetry retrieved successfully.";
        } catch (e) {
          result = "Mobile Telemetry Error: $e";
        }
      } else if (fnName == "get_current_datetime") {
        final now = DateTime.now();
        final dayNames = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
        final monthNames = ['January','February','March','April','May','June','July','August','September','October','November','December'];
        final dayOfWeek = dayNames[now.weekday - 1];
        final monthName = monthNames[now.month - 1];
        final hour12 = now.hour == 0 ? 12 : (now.hour > 12 ? now.hour - 12 : now.hour);
        final amPm = now.hour >= 12 ? 'PM' : 'AM';
        final timeStr = '${hour12.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} $amPm';
        final dateStr = '$dayOfWeek, ${now.day} $monthName ${now.year}';
        final tz = now.timeZoneOffset;
        final tzStr = 'UTC${tz.isNegative ? '' : '+'}${tz.inHours}:${(tz.inMinutes % 60).abs().toString().padLeft(2, '0')}';
        result = "REAL DEVICE CLOCK — Time: $timeStr | Date: $dateStr | Timezone: $tzStr (${now.timeZoneName})";
      } else if (fnName == "open_permission_settings") {
        final settingType = (args["setting_type"] ?? "APP_DETAILS").toString().toUpperCase();
        try {
          final dynamic res = await _automationChannel.invokeMethod("openPermissionSettings", {"settingType": settingType});
          if (res is Map && res["success"] == true) {
            result = "Opened Android $settingType settings page for Azhar to grant permission.";
          } else {
            result = "Failed to open $settingType settings: ${res is Map ? res['error'] : 'Unknown error'}";
          }
        } catch (e) {
          result = "Error opening settings: $e";
        }
      } else if (fnName == "start_screen_cast") {
        onRequestToggleScreenCast?.call(true);
        result = "Screen Cast request initiated. Real-time screen video streaming is starting.";
      } else if (fnName == "stop_screen_cast") {
        onRequestToggleScreenCast?.call(false);
        result = "Screen Cast stopped.";
      } else if (fnName == "switch_persona") {
        final target = (args["target_persona"] ?? "BIBA").toString().toUpperCase();
        result = "Switching persona to $target.";
        onRequestSwitchProfile?.call(target);
      } else if (fnName == "switch_audio_route") {
        final targetRoute = (args["target"] ?? "SPEAKER").toString().toUpperCase();
        onRequestSwitchAudioRoute?.call(targetRoute);
        result = "Audio output routed successfully to $targetRoute.";
      } else if (fnName == "control_flashlight") {
        final action = (args["action"] ?? "TOGGLE").toString().toUpperCase();
        try {
          final dynamic res = await _automationChannel.invokeMethod("controlFlashlight", {"action": action});
          if (res is Map && res["success"] == true) {
            final isOn = res["isTorchOn"] == true;
            result = "Flashlight ${isOn ? 'turned ON' : 'turned OFF'}.";
          } else {
            result = "Flashlight control failed: ${res is Map ? res['error'] : 'Unknown error'}";
          }
        } catch (e) {
          result = "Flashlight error: $e";
        }
      } else if (fnName == "control_wifi") {
        final action = (args["action"] ?? "STATUS").toString().toUpperCase();
        try {
          final dynamic res = await _automationChannel.invokeMethod("controlWifi", {"action": action});
          if (res is Map) {
            if (action == "STATUS") {
              final enabled = res["isWifiEnabled"] == true;
              final connected = res["isConnected"] == true;
              final ssid = res["ssid"] ?? "";
              result = "Wi-Fi is ${enabled ? 'ENABLED' : 'DISABLED'}. Status: ${connected ? 'Connected to $ssid' : 'Disconnected'}.";
            } else {
              result = "Opened Wi-Fi settings panel on screen.";
            }
          } else {
            result = "Wi-Fi status check completed.";
          }
        } catch (e) {
          result = "Wi-Fi control error: $e";
        }
      } else if (fnName == "control_bluetooth") {
        final action = (args["action"] ?? "TOGGLE").toString().toUpperCase();
        try {
          final dynamic res = await _automationChannel.invokeMethod("controlBluetooth", {"action": action});
          if (res is Map && res["success"] == true) {
            final enabled = res["enabled"] == true;
            result = "Bluetooth is now ${enabled ? 'ENABLED (ON)' : 'DISABLED (OFF)'}.";
          } else {
            result = "Bluetooth control result: ${res is Map ? res['message'] : 'Action performed'}";
          }
        } catch (e) {
          result = "Bluetooth control error: $e";
        }
      } else if (fnName == "control_brightness") {
        final level = int.tryParse(args["level"]?.toString() ?? "50") ?? 50;
        try {
          final dynamic res = await _automationChannel.invokeMethod("controlBrightness", {"level": level});
          if (res is Map && res["success"] == true) {
            final newLevel = res["level"] ?? level;
            result = "Screen brightness set to $newLevel%.";
          } else {
            result = "Brightness control result: ${res is Map ? res['message'] : 'Action performed'}";
          }
        } catch (e) {
          result = "Brightness control error: $e";
        }
      } else if (fnName == "read_sms_messages") {
        final limit = int.tryParse(args["limit"]?.toString() ?? "5") ?? 5;
        final query = args["query"]?.toString();
        try {
          final dynamic res = await _automationChannel.invokeMethod("readSms", {"limit": limit, "query": query});
          if (res is Map) {
            if (res["error"] == "PERMISSION_DENIED") {
              result = "SMS permission grant nahi hai Azhar. Settings mein jaa kar SMS permission allow karein.";
            } else if (res["success"] == true) {
              final msgs = res["messages"] as List? ?? [];
              if (msgs.isEmpty) {
                result = "Inbox mein koi matching SMS message nahi mila.";
              } else {
                final formatted = msgs.take(3).map((m) {
                  final s = m["sender"] ?? "Unknown";
                  final b = m["body"] ?? "";
                  return "[$s]: $b";
                }).join(" | ");
                result = "Found ${msgs.length} messages. Recent: $formatted";
              }
            } else {
              result = "SMS check error: ${res['error']}";
            }
          } else {
            result = "SMS query completed.";
          }
        } catch (e) {
          result = "SMS query error: $e";
        }
      } else if (fnName == "read_active_notifications") {
        final limit = int.tryParse(args["limit"]?.toString() ?? "5") ?? 5;
        final filter = args["app_filter"]?.toString();
        try {
          final dynamic res = await _automationChannel.invokeMethod("readNotifications", {"limit": limit, "filter": filter});
          if (res is Map) {
            if (res["error"] == "LISTENER_DISABLED") {
              result = "Notification Access grant nahi hai Azhar. Settings mein Notification Access allow karein.";
            } else if (res["success"] == true) {
              final notifs = res["notifications"] as List? ?? [];
              if (notifs.isEmpty) {
                result = "Abhi koi active notification nahi hai.";
              } else {
                final formatted = notifs.take(4).map((n) {
                  final title = n["title"] ?? "";
                  final text = n["text"] ?? "";
                  return "$title: $text";
                }).join(" | ");
                result = "Active Notifications (${notifs.length}): $formatted";
              }
            } else {
              result = "Notifications error: ${res['error']}";
            }
          } else {
            result = "Notifications read completed.";
          }
        } catch (e) {
          result = "Notification read error: $e";
        }
      } else if (fnName == "perform_screen_action") {
        final action = (args["action"] ?? "HOME").toString().toUpperCase();
        final targetText = args["target_text"]?.toString();
        try {
          final dynamic res = await _automationChannel.invokeMethod("performScreenAction", {
            "action": action,
            "targetText": targetText,
          });
          if (res is Map) {
            if (res["error"] == "ACCESSIBILITY_DISABLED") {
              result = "AVIS Screen Assistant Accessibility service band hai. Settings > Accessibility mein ja kar isse ON karein.";
            } else if (res["success"] == true) {
              if (action == "SCREEN_CONTENT") {
                final elements = res["elements"] as List? ?? [];
                result = "Screen elements: ${elements.take(10).join(', ')}";
              } else {
                result = "Navigation action '$action' completed successfully.";
              }
            } else {
              result = "Action '$action' nahi ho saka: ${res['error'] ?? 'element not responsive'}";
            }
          } else {
            result = "Screen action finished.";
          }
        } catch (e) {
          result = "Screen action error: $e";
        }
      } else if (fnName == "open_app" || fnName == "launch_app") {
        final appName = (args["app_name"] ?? "").toString().trim();
        try {
          final dynamic res = await _automationChannel.invokeMethod("launchApp", {"appName": appName});
          if (res is Map && res["success"] == true) {
            final launched = res["appName"] ?? appName;
            result = "Application '$launched' successfully open ho gayi hai.";
          } else {
            result = "Application '$appName' launch nahi ho saki: ${res is Map ? res['message'] : 'App not found'}";
          }
        } catch (e) {
          result = "App launch error: $e";
        }
      } else if (fnName == "write_sandbox_file") {
        final filename = (args["filename"] ?? "").toString().trim();
        final content = (args["content"] ?? "").toString();
        result = await sandboxManager.writeSandboxFile(filename, content);
      } else if (fnName == "read_sandbox_file") {
        final filename = (args["filename"] ?? "").toString().trim();
        result = await sandboxManager.readSandboxFile(filename);
      } else if (fnName == "list_sandbox_files") {
        result = await sandboxManager.listSandboxFiles();
      } else if (fnName == "delete_sandbox_file") {
        final filename = (args["filename"] ?? "").toString().trim();
        result = await sandboxManager.deleteSandboxFile(filename);
      } else if (fnName == "type_text") {
        final text = (args["text"] ?? "").toString();
        final targetField = args["target_field"]?.toString();
        // Code-level safety guard: Auto-send / auto-submit is strictly blocked without explicit confirmation
        const pressEnter = false;
        final typographyCadence = args["typography_cadence"] != false;

        try {
          final dynamic res = await _automationChannel.invokeMethod("typeText", {
            "text": text,
            "targetField": targetField,
            "pressEnter": pressEnter,
            "typographyCadence": typographyCadence,
          });
          if (res is Map) {
            if (res["error"] == "ACCESSIBILITY_DISABLED") {
              result = "AVIS Accessibility Service band hai Azhar. Settings mein jaa kar isse enable karein taaki main type kar saku.";
            } else if (res["success"] == true) {
              result = "Text successfully typed into field: \"$text\". IMPORTANT: DO NOT automatically press enter or submit. Now speak back to Azhar/Janu: 'Maine type kar diya hai: \"$text\". Kya ise send ya search karun?' and WAIT for user voice confirmation.";
            } else {
              result = "Typing failed: Active input field nahi mila.";
            }
          } else {
            result = "Typing completed.";
          }
        } catch (e) {
          result = "Typing error: $e";
        }
      } else if (fnName == "show_code_popup") {
        final code = (args["code"] ?? "").toString();
        final language = (args["language"] ?? "text").toString();
        final title = (args["title"] ?? "").toString();

        try {
          final dynamic res = await _automationChannel.invokeMethod("showCodePopup", {
            "code": code,
            "language": language,
            "title": title,
          });
          if (res is String) {
            result = res;
          } else {
            result = "Code overlay displayed successfully.";
          }
        } catch (e) {
          result = "Code overlay error: $e";
        }
      } else if (fnName == "show_sandbox_popup") {
        final title = (args["title"] ?? "Sandbox File Manager").toString();
        onShowSandboxPopup?.call(title);
        try {
          final dynamic res = await _automationChannel.invokeMethod("showSandboxPopup", {
            "title": title,
          });
          if (res is String) {
            result = res;
          } else {
            result = "Sandbox overlay displayed successfully on screen.";
          }
        } catch (e) {
          result = "Sandbox overlay displayed via in-app UI.";
        }
      } else if (fnName == "create_calendar_event") {
        final title = (args["title"] ?? "").toString();
        final description = (args["description"] ?? "").toString();
        final daysFromNow = int.tryParse(args["days_from_now"]?.toString() ?? "0") ?? 0;
        final hour = int.tryParse(args["hour"]?.toString() ?? "12") ?? 12;
        final minute = int.tryParse(args["minute"]?.toString() ?? "0") ?? 0;
        final durationMinutes = int.tryParse(args["duration_minutes"]?.toString() ?? "30") ?? 30;
        final location = (args["location"] ?? "").toString();

        final now = DateTime.now();
        final targetDate = DateTime(now.year, now.month, now.day + daysFromNow, hour, minute);
        final startMillis = targetDate.millisecondsSinceEpoch;

        try {
          final dynamic res = await _automationChannel.invokeMethod("createCalendarEvent", {
            "title": title,
            "description": description,
            "startMillis": startMillis,
            "durationMinutes": durationMinutes,
            "location": location,
          });
          if (res is Map && res["success"] == true) {
            result = "Calendar Event '$title' successfully scheduled for $targetDate ($durationMinutes mins).";
          } else {
            result = "Calendar error: ${res is Map ? res['error'] : 'Unknown'}";
          }
        } catch (e) {
          result = "Calendar error: $e";
        }
      } else if (fnName == "list_calendar_events") {
        final daysAhead = int.tryParse(args["days_ahead"]?.toString() ?? "7") ?? 7;
        final query = args["query"]?.toString();
        try {
          final dynamic res = await _automationChannel.invokeMethod("queryCalendarEvents", {
            "daysAhead": daysAhead,
            "query": query,
          });
          if (res is Map && res["success"] == true) {
            final evs = res["events"] as List? ?? [];
            if (evs.isEmpty) {
              result = "No scheduled calendar events found in the next $daysAhead days.";
            } else {
              final formatted = evs.take(5).map((e) {
                final t = e["title"] ?? "Event";
                final d = e["description"] ?? "";
                return "$t${d.isNotEmpty ? ' ($d)' : ''}";
              }).join(" | ");
              result = "Found ${evs.length} event(s): $formatted";
            }
          } else {
            result = "Calendar read error: ${res is Map ? res['error'] : 'Unknown'}";
          }
        } catch (e) {
          result = "Calendar read error: $e";
        }
      } else if (fnName == "set_alarm_or_timer") {
        final type = (args["type"] ?? "alarm").toString().toLowerCase();
        final hour = int.tryParse(args["hour"]?.toString() ?? "7") ?? 7;
        final minute = int.tryParse(args["minute"]?.toString() ?? "0") ?? 0;
        final seconds = int.tryParse(args["seconds"]?.toString() ?? "60") ?? 60;
        final message = (args["message"] ?? (type == "alarm" ? "AVIS Alarm" : "AVIS Timer")).toString();

        try {
          if (type == "alarm") {
            await _automationChannel.invokeMethod("setAlarm", {
              "hour": hour,
              "minutes": minute,
              "message": message,
            });
            result = "Alarm set for ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} with message '$message'.";
          } else {
            await _automationChannel.invokeMethod("setTimer", {
              "seconds": seconds,
              "message": message,
            });
            result = "Timer set for $seconds seconds ($message).";
          }
        } catch (e) {
          result = "Alarm/Timer error: $e";
        }
      } else if (fnName == "manage_contacts") {
        final action = (args["action"] ?? "search").toString().toLowerCase();
        final name = (args["name"] ?? "").toString();
        final phone = (args["phone"] ?? "").toString();
        final email = (args["email"] ?? "").toString();

        try {
          if (action == "add") {
            final dynamic res = await _automationChannel.invokeMethod("addContact", {
              "name": name,
              "phone": phone,
              "email": email,
            });
            if (res is Map && res["success"] == true) {
              result = "Contact '$name' (Phone: $phone) successfully added to phone contacts.";
            } else {
              result = "Add contact error: ${res is Map ? res['error'] : 'Unknown'}";
            }
          } else {
            final dynamic res = await _automationChannel.invokeMethod("queryContacts", {
              "query": name,
              "limit": 5,
            });
            if (res is Map && res["success"] == true) {
              final contacts = res["contacts"] as List? ?? [];
              if (contacts.isEmpty) {
                result = "No contacts found matching '$name'.";
              } else {
                final formatted = contacts.take(3).map((c) => "${c['name']}: ${c['phone']}").join(" | ");
                result = "Found ${contacts.length} matching contact(s): $formatted";
              }
            } else {
              result = "Contact search error: ${res is Map ? res['error'] : 'Unknown'}";
            }
          }
        } catch (e) {
          result = "Contact management error: $e";
        }
      } else if (fnName == "control_media") {
        final action = (args["action"] ?? "TOGGLE").toString().toUpperCase();
        final volume = int.tryParse(args["volume"]?.toString() ?? "50");

        try {
          await _automationChannel.invokeMethod("controlMedia", {
            "action": action,
            "volume": volume,
          });
          result = "Media action '$action' executed successfully.";
        } catch (e) {
          result = "Media control error: $e";
        }
      } else if (fnName == "close_app") {
        final appName = (args["app_name"] ?? "").toString();
        final packageName = (args["package_name"] ?? "").toString();

        try {
          await _automationChannel.invokeMethod("closeApp", {
            "appName": appName,
            "packageName": packageName,
          });
          result = "Application '${appName.isNotEmpty ? appName : packageName}' closed / returned home.";
        } catch (e) {
          result = "Close app error: $e";
        }
      } else if (fnName == "consult_user_manual") {
        final query = (args["query"] ?? "").toString();
        final topic = args["topic"]?.toString();
        result = manualManager.searchManual(query, topic);
      } else if (fnName == "run_live_preview") {
        final code = (args["code"] ?? "").toString();
        final language = (args["language"] ?? "html").toString();
        final title = (args["title"] ?? "Live Code Playground").toString();

        LiveRunnerController().loadCode(code: code, language: language, title: title);
        onRequestRunLivePreview?.call(code, language, title);
        result = "SUCCESS_SILENT";
      } else if (fnName == "web_search") {
        final query = (args["query"] ?? "").toString();
        result = await ToolsService.searchWeb(query);
      } else if (fnName == "get_weather") {
        final location = (args["location"] ?? "").toString();
        result = await ToolsService.fetchWeather(location);
      } else if (fnName == "manage_clipboard") {
        final action = (args["action"] ?? "READ").toString().toUpperCase();
        try {
          if (action == "WRITE") {
            final text = (args["text"] ?? "").toString();
            await Clipboard.setData(ClipboardData(text: text));
            result = "Successfully copied to clipboard: \"$text\"";
          } else {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            final text = data?.text ?? "";
            result = text.isNotEmpty ? "Current Clipboard Content: \"$text\"" : "Clipboard is currently empty.";
          }
        } catch (e) {
          result = "Clipboard error: $e";
        }
      } else if (fnName == "send_whatsapp_message") {
        final phone = (args["phone"] ?? "").toString();
        final message = (args["message"] ?? "").toString();
        try {
          final dynamic res = await _automationChannel.invokeMethod("sendWhatsAppMessage", {
            "phone": phone,
            "message": message,
          });
          if (res is Map && res["success"] == true) {
            result = res["message"]?.toString() ?? "WhatsApp message pre-filled.";
          } else {
            result = "WhatsApp error: ${res is Map ? res['error'] : 'Unknown'}";
          }
        } catch (e) {
          result = "WhatsApp launch error: $e";
        }
      } else if (fnName == "get_youtube_channel_stats") {
        final apiKey = await YouTubeConfigStore.loadApiKey();
        final oauthToken = await YouTubeService.getValidOAuthToken();
        final ch = await YouTubeService.fetchChannelDetails(channelIdOrHandle: 'mine', apiKey: apiKey, accessToken: oauthToken);
        if (ch['success'] == true) {
          final channelId = ch['channelId'] ?? '';
          final analytics = await YouTubeService.fetchChannelAnalytics(channelId: channelId, apiKey: apiKey, accessToken: oauthToken);
          result = "YouTube Creator Channel '${ch['title']}': ${ch['subscriberCount']} Subscribers, ${ch['viewCount']} Views, ${ch['videoCount']} Videos | Watch Time: ${analytics['watchTimeHours']}h | CTR: ${analytics['ctrPercent']} (${analytics['ctrStatus']}) | Impressions: ${analytics['impressions']} | Peak Audience Active Window: ${analytics['peakAudienceTiming']}.";
        } else {
          result = "YouTube API Error: ${ch['error']}";
        }
      } else if (fnName == "get_youtube_recent_videos") {
        final apiKey = await YouTubeConfigStore.loadApiKey();
        final oauthToken = await YouTubeService.getValidOAuthToken();
        final ch = await YouTubeService.fetchChannelDetails(channelIdOrHandle: 'mine', apiKey: apiKey, accessToken: oauthToken);
        if (ch['success'] == true && (ch['uploadsPlaylistId'] as String).isNotEmpty) {
          final vids = await YouTubeService.fetchRecentVideos(uploadsPlaylistId: ch['uploadsPlaylistId'], apiKey: apiKey, accessToken: oauthToken, limit: 5);
          if (vids.isEmpty) {
            result = "No recent videos found.";
          } else {
            final formatted = vids.map((v) => "'${v['title']}' (${v['views']} views, ${v['likes']} likes)").join(" | ");
            result = "Recent videos on '${ch['title']}': $formatted";
          }
        } else {
          result = "Could not fetch recent videos: ${ch['error']}";
        }
      } else if (fnName == "get_youtube_recent_comments") {
        final apiKey = await YouTubeConfigStore.loadApiKey();
        final oauthToken = await YouTubeService.getValidOAuthToken();
        final ch = await YouTubeService.fetchChannelDetails(channelIdOrHandle: 'mine', apiKey: apiKey, accessToken: oauthToken);
        if (ch['success'] == true && (ch['channelId'] as String).isNotEmpty) {
          final comments = await YouTubeService.fetchRecentComments(channelId: ch['channelId'], apiKey: apiKey, accessToken: oauthToken, limit: 5);
          if (comments.isEmpty) {
            result = "No recent comments found.";
          } else {
            final formatted = comments.map((c) => "${c['author']}: '${c['text']}'").join(" | ");
            result = "Recent user comments on '${ch['title']}': $formatted";
          }
        } else {
          result = "Could not fetch comments: ${ch['error']}";
        }
      } else if (fnName == "get_youtube_video_comments") {
        final videoId = (args["video_id"] ?? "").toString();
        final apiKey = await YouTubeConfigStore.loadApiKey();
        final oauthToken = await YouTubeService.getValidOAuthToken();
        if (videoId.isEmpty) {
          result = "Missing video_id to fetch video comments.";
        } else {
          final comments = await YouTubeService.fetchVideoComments(
            videoId: videoId,
            apiKey: apiKey,
            accessToken: oauthToken,
            limit: 5,
          );
          if (comments.isEmpty) {
            result = "No comments found for video '$videoId'.";
          } else {
            final formatted = comments.map((c) => "${c['author']}: '${c['text']}'").join(" | ");
            result = "Comments on video '$videoId': $formatted";
          }
        }
      } else if (fnName == "reply_to_youtube_comment") {
        final commentId = (args["comment_id"] ?? "").toString();
        final replyText = (args["reply_text"] ?? "").toString();
        final apiKey = await YouTubeConfigStore.loadApiKey();
        final oauthToken = await YouTubeService.getValidOAuthToken();
        if (commentId.isEmpty || replyText.isEmpty) {
          result = "Missing comment_id or reply_text for YouTube comment reply.";
        } else {
          final res = await YouTubeService.postCommentReply(
            commentId: commentId,
            replyText: replyText,
            apiKey: apiKey,
            accessToken: oauthToken,
          );
          if (res["success"] == true) {
            result = "Reply successfully posted to YouTube comment '$commentId'.";
          } else {
            result = "Error posting YouTube comment reply: ${res['error']}";
          }
        }
      } else if (fnName == "show_youtube_studio_overlay" || fnName == "show_youtube_hud_overlay") {
        onRequestShowYouTubeStudio?.call();
        result = "Sci-Fi Holographic YouTube Creator Studio Overlay displayed on screen.";
      } else {
        result = "Tool '$fnName' not recognized on mobile client.";
      }

      _aiTranscriptController.add("🛠️ [$fnName]: $result");

      functionResponses.add({
        "id": callId,
        "name": fnName,
        "response": {
          "result": result,
        }
      });
    }

    // Send Tool Responses back to Gemini Live WebSocket
    final toolResponseMsg = {
      "toolResponse": {
        "functionResponses": functionResponses,
      }
    };

    _sendSafeJson(toolResponseMsg);
    _isToolExecuting = false;
    _updateState(GeminiSessionState.speaking, "🤖 Speaking...");
  }

  /// Switch persona between A.V.I.S and B.I.B.A (reconnects with target voice and system prompt)
  Future<void> switchPersona(String newProfile) async {
    final target = newProfile.trim().toUpperCase();
    if (target == currentProfile) return;
    currentProfile = target;
    final voice = PersonaPrompts.voiceMap[target] ?? "Puck";
    addLog("🔄 Switching Persona to $target (Voice: $voice)...");
    _statusController.add("🔄 Switching to $target...");

    final wasActive = (_state == GeminiSessionState.connected ||
        _state == GeminiSessionState.listening ||
        _state == GeminiSessionState.speaking ||
        _state == GeminiSessionState.toolExecuting);

    if (wasActive) {
      await disconnect();
      await Future.delayed(const Duration(milliseconds: 350));
      await connect();
    }
  }

  void _onError(dynamic error) {
    final errStr = error.toString();
    _cleanupResources();
    addLog("Session Error: $errStr");
    if (!_isUserIntentionalDisconnect) {
      if (_isQuotaOrAuthError(errStr) && onRequestNextApiKey != null) {
        addLog("⚠️ Quota/Key limit session error ($errStr). Triggering Auto API Key failover...");
        _updateState(GeminiSessionState.error, "⚠️ Key Quota Exceeded");
        onRequestNextApiKey?.call();
        return;
      }
      _scheduleAutoReconnect();
    } else {
      _updateState(GeminiSessionState.error, "🔴 Error: $error");
    }
  }

  void _onDisconnected() {
    final code = _channel?.closeCode;
    final reason = _channel?.closeReason ?? "";
    addLog("WebSocket Disconnected (Code: $code, Reason: $reason)");
    _cleanupResources();
    if (!_isUserIntentionalDisconnect) {
      if ((code == 4003 || code == 4000 || _isQuotaOrAuthError(reason)) && onRequestNextApiKey != null) {
        addLog("⚠️ WebSocket Closed due to Quota/Auth ($code: $reason). Triggering Auto API Key failover...");
        _updateState(GeminiSessionState.error, "⚠️ Key Quota Exceeded");
        onRequestNextApiKey?.call();
        return;
      }
      _scheduleAutoReconnect();
    } else if (_state != GeminiSessionState.error) {
      final msg = (code != null) ? "⚪ Disconnected (Code $code)" : "⚪ Disconnected";
      _updateState(GeminiSessionState.disconnected, msg);
    }
  }

  Future<void> _cleanupResources() async {
    _isSpeaking = false;
    _isToolExecuting = false;
    _isPassiveSilent = false;
    _speakingDebounceTimer?.cancel();
    _speakingDebounceTimer = null;
    await audioManager.stopRealMic();
    await audioManager.stopSpeakerPlayback();
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  /// Disconnect session and release network resources
  Future<void> disconnect() async {
    _isUserIntentionalDisconnect = true;
    _cancelReconnectTimer();
    _reconnectAttempts = 0;
    await _cleanupResources();
    _updateState(GeminiSessionState.disconnected, "⚪ Disconnected");
  }

  void dispose() {
    _isUserIntentionalDisconnect = true;
    _cancelReconnectTimer();
    disconnect();
    _stateController.close();
    _statusController.close();
    _userTranscriptController.close();
    _aiTranscriptController.close();
  }
}
