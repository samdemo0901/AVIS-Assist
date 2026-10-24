import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'app_constants.dart';

/// Manages Audio Streaming, PCM Format conversions, and Real-time RMS extraction
/// for Gemini Live multimodal direct speech-to-speech interaction.
class AudioStreamManager {
  static const int micSampleRate = 16000;  // Gemini standard input rate (16kHz PCM 16-bit Mono)
  static const int spkSampleRate = 24000;  // Gemini standard output rate (24kHz PCM 16-bit Mono)
  static const int chunkSize = 1024;       // ~64ms buffer chunk

  static const MethodChannel _methodChannel = AppChannels.audio;
  static const EventChannel _eventChannel = AppChannels.audioStream;

  // Broadcast stream for real-time RMS volume (0.0 to 1.0) driving the 3D Neural Orb
  final StreamController<double> _audioLevelController = StreamController<double>.broadcast();
  Stream<double> get audioLevelStream => _audioLevelController.stream;

  // Stream for outgoing 16kHz PCM audio chunks to Gemini Live WebSocket
  final StreamController<Uint8List> _outgoingPcmController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get outgoingPcmStream => _outgoingPcmController.stream;

  void Function(bool isCallActive)? onPhoneCallStateChanged;
  VoidCallback? onAssistLaunch;
  VoidCallback? onNotificationMuteToggled;
  VoidCallback? onNotificationEndSession;

  AudioStreamManager() {
    _methodChannel.setMethodCallHandler((call) async {
      if (call.method == "onSpeakerAudioLevel") {
        final args = call.arguments;
        if (args is Map && args.containsKey("level")) {
          final double lvl = (args["level"] as num).toDouble();
          _audioLevelController.add(lvl);
        }
      } else if (call.method == "onPhoneCallState") {
        final args = call.arguments;
        if (args is Map && args.containsKey("active")) {
          final bool active = args["active"] == true;
          onPhoneCallStateChanged?.call(active);
        }
      } else if (call.method == "onAssistLaunch") {
        onAssistLaunch?.call();
      } else if (call.method == "onNotificationMuteToggled") {
        final args = call.arguments;
        if (args is Map && args.containsKey("isMuted")) {
          _isMuted = args["isMuted"] == true;
        } else {
          _isMuted = !_isMuted;
        }
        if (_isMuted) {
          _audioLevelController.add(0.0);
        }
        onNotificationMuteToggled?.call();
      } else if (call.method == "onNotificationEndSession") {
        onNotificationEndSession?.call();
      }
    });
  }

  Timer? _micCadenceTimer;
  StreamSubscription? _nativeMicSub;
  bool _isMicActive = false;
  bool _isMuted = false;

  bool get isMuted => _isMuted;
  bool get isMicActive => _isMicActive;

  String _activeAudioRoute = "AUTO"; // "AUTO", "SPEAKER", "BLUETOOTH"
  String get activeAudioRoute => _activeAudioRoute;

  Future<void> switchAudioRoute(String route) async {
    _activeAudioRoute = route;
    try {
      await _methodChannel.invokeMethod("setAudioRoute", {"route": route});
    } catch (_) {}
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      _audioLevelController.add(0.0);
    }
    _syncMuteStateToNative();
  }

  void setMute(bool muted) {
    _isMuted = muted;
    if (_isMuted) {
      _audioLevelController.add(0.0);
    }
    _syncMuteStateToNative();
  }

  void _syncMuteStateToNative() {
    _methodChannel.invokeMethod("setMuteState", {"isMuted": _isMuted}).catchError((_) => null);
  }

  /// Cancel offline simulation timer without stopping hardware mic
  void cancelSimulation() {
    _micCadenceTimer?.cancel();
    _micCadenceTimer = null;
  }

  /// Start live hardware microphone recording via native Android AudioRecord
  Future<void> startRealMic() async {
    cancelSimulation();
    _isMicActive = true;
    try {
      await _nativeMicSub?.cancel();
      _nativeMicSub = _eventChannel.receiveBroadcastStream().listen(
        (event) {
          if (event is Uint8List) {
            feedMicPcm(event);
          } else if (event is List<dynamic>) {
            feedMicPcm(Uint8List.fromList(event.cast<int>()));
          }
        },
        onError: (err) {
          // Hardware stream transient error - keep channel open
        },
      );
      await _methodChannel.invokeMethod("startRecording");
    } catch (e) {
      // Hardware record error
    }
  }

  /// Stop native microphone recording
  Future<void> stopRealMic() async {
    await _nativeMicSub?.cancel();
    _nativeMicSub = null;
    try {
      await _methodChannel.invokeMethod("stopRecording");
    } catch (_) {}
  }

  /// Start simulated natural human voice cadence for demo/standby
  void startSimulatedMicStream() {
    _micCadenceTimer?.cancel();
    _isMicActive = true;
    int tick = 0;

    _micCadenceTimer = Timer.periodic(const Duration(milliseconds: 64), (timer) {
      if (!_isMicActive || _isMuted) return;

      tick++;
      final cycle = tick % 140; // ~8.9s conversational cycle

      double volume = 0.0;
      if (cycle < 55) {
        final wave = 0.5 + 0.35 * math.sin(tick * 0.4);
        final flutter = (math.Random().nextDouble() - 0.5) * 0.25;
        volume = (wave + flutter).clamp(0.05, 0.95);
      } else if (cycle < 80) {
        volume = 0.02 * math.Random().nextDouble();
      } else if (cycle < 120) {
        final wave = 0.65 + 0.30 * math.sin(tick * 0.5);
        final flutter = (math.Random().nextDouble() - 0.5) * 0.2;
        volume = (wave + flutter).clamp(0.1, 1.0);
      } else {
        volume = 0.0;
      }

      final pcmChunk = _generateSyntheticPcmChunk(volume);
      _outgoingPcmController.add(pcmChunk);
      _audioLevelController.add(volume);
    });
  }

  /// Feed live microphone raw PCM bytes into the pipeline
  void feedMicPcm(Uint8List pcmBytes) {
    if (_isMuted) return;
    final rms = computePcmRms(pcmBytes);
    _currentLevel = rms;
    _audioLevelController.add(rms);
    _outgoingPcmController.add(pcmBytes);
  }

  /// Feed incoming Gemini Live model turn PCM chunks (24kHz) for speaker playback & Orb pulsing
  void feedModelSpeakerPcm(Uint8List pcmBytes) {
    final rms = computePcmRms(pcmBytes);
    _currentLevel = rms;
    _audioLevelController.add(rms);
    try {
      _methodChannel.invokeMethod("playPcmChunk", pcmBytes);
    } catch (_) {}
  }

  /// Stop speaker playback
  Future<void> stopSpeakerPlayback() async {
    try {
      await _methodChannel.invokeMethod("stopPlayback");
    } catch (_) {}
  }

  double _currentLevel = 0.0;
  double get currentLevel => _currentLevel;

  /// Plays a clean test sound chime directly through the phone loudspeaker
  Future<void> testSpeakerChime() async {
    try {
      await _methodChannel.invokeMethod("testSpeakerChime");
    } catch (_) {}
  }

  /// Plays futuristic sci-fi activation chime when AVIS session starts
  Future<void> playSciFiStartChime() async {
    try {
      await _methodChannel.invokeMethod("playSciFiStartChime");
    } catch (_) {}
  }

  /// Plays futuristic sci-fi deactivation chime when AVIS call ends
  Future<void> playSciFiEndChime() async {
    try {
      await _methodChannel.invokeMethod("playSciFiEndChime");
    } catch (_) {}
  }

  /// Calculates Root Mean Square (RMS) volume normalized from 0.0 to 1.0
  static double computePcmRms(Uint8List pcmBytes) {
    if (pcmBytes.length < 2) return 0.0;
    final byteData = ByteData.sublistView(pcmBytes);
    final numSamples = pcmBytes.length ~/ 2;

    double sumSquares = 0.0;
    for (int i = 0; i < numSamples; i++) {
      final sample = byteData.getInt16(i * 2, Endian.little);
      sumSquares += sample * sample;
    }

    final meanSquare = sumSquares / numSamples;
    final rms = math.sqrt(meanSquare);

    // Dynamic threshold: sensitive noise floor ~50, peak ~2200 for responsive voice interaction
    if (rms < 50.0) return 0.0;
    return ((rms - 50.0) / 2200.0).clamp(0.0, 1.0);
  }

  /// Synthesizes a realistic 64ms 16kHz PCM buffer for audio stream emulation
  Uint8List _generateSyntheticPcmChunk(double amplitude) {
    const samplesPerChunk = 1024;
    final byteData = ByteData(samplesPerChunk * 2);

    for (int i = 0; i < samplesPerChunk; i++) {
      final sampleVal = (amplitude * 16000.0 * math.sin(2.0 * math.pi * 440.0 * (i / micSampleRate))).toInt();
      byteData.setInt16(i * 2, sampleVal.clamp(-32768, 32767), Endian.little);
    }
    return byteData.buffer.asUint8List();
  }

  void stopMicStream() {
    _micCadenceTimer?.cancel();
    _micCadenceTimer = null;
    stopRealMic();
    _isMicActive = false;
    _audioLevelController.add(0.0);
  }

  void dispose() {
    stopMicStream();
    stopSpeakerPlayback();
    _audioLevelController.close();
    _outgoingPcmController.close();
  }
}
