# AVIS Mobile HUD (Flutter with Gemini Live Multimodal Brain)

Futuristic 3D Neural Particle Orb AI Assistant interface for Android & iOS with direct, continuous speech-to-speech multimodal intelligence. Completely isolated from desktop Windows logic.

---

## 📁 Architecture & File Structure

```
.
├── lib/
│   ├── main.dart                       # App entry point, session lifecycle & responsive layout
│   ├── core/
│   │   ├── gemini_live_client.dart     # Direct bidirectional WebSocket Gemini Live speech-to-speech engine
│   │   ├── audio_stream_manager.dart   # 16kHz PCM streamer, 24kHz receiver & RMS audio extraction
│   │   ├── persona_prompts.dart        # AVIS (Puck) & BIBA (Laomedeia) system prompts
│   │   └── mobile_memory_manager.dart  # Two-Tier Cognitive Memory (Long-term profile + short-term turns)
│   ├── theme/
│   │   └── app_theme.dart              # Cybernetic palette (Neon Cyan, Obsidian, Cyber Green, Magenta)
│   ├── painters/
│   │   └── particle_orb_painter.dart   # 3D spherical particle CustomPainter (1,100 points, depth-sorted)
│   └── widgets/
│       ├── top_header.dart             # Animated typewriter/wave entrance & dual-persona badge
│       ├── neural_orb.dart             # 60 FPS ticker, pan-to-rotate gesture, and audio smoothing
│       └── bottom_nav.dart             # Functional BottomNavigationBar (Settings, Home, Profile)
├── android/                            # Native Android platform code (Overlays & MethodChannels)
├── pubspec.yaml                        # Flutter package manifest (web_socket_channel, animated_text_kit)
├── build_mobile.ps1                    # Isolated Android build script routing to build/mobile/
├── AGENTS.md                           # Master Project Guidelines & Agent Rules
├── GEMINI.md                           # AI Agent Rule Reference
└── README.md                           # Project Documentation
```

---

## 🧠 Core AI Brain Features (Parity with Windows Companion)

1. **Direct Speech-to-Speech Streaming (No STT-then-TTS delays)**:
   - Connects via native Dart `WebSocketChannel` to `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=...`.
   - Continuous 16kHz Linear PCM 16-bit mono audio streaming.
   - Real-time 24kHz Linear PCM response decoding directly to the audio manager and 3D Neural Orb.
2. **Dual Persona Intelligence**:
   - **AVIS**: Male tech assistant with an energetic, crisp Hinglish voice (`Puck`), master in coding and Samsung tech.
   - **BIBA**: Cute, loving companion character in sweet Hindi (`Laomedeia`).
   - Seamless cross-persona voice switching (e.g., *"Biba se connect karo"* or *"Avis ko bulao"*).
3. **Two-Tier Cognitive Memory**:
   - **Long-Term**: Permanent facts, Azhar's operator profile, YouTube channel details, preferences.
   - **Short-Term**: 5-turn rolling conversation cache primed automatically into Gemini Live sessions.
4. **Autonomous Mobile Tool Calling**:
   - `remember_fact`, `recall_memories`, `forget_fact`, `get_device_telemetry`, and `switch_persona`.
5. **Real-time 3D Particle Orb Reactivity**:
   - Computes normalized RMS amplitude (0.0 to 1.0) from microphone input and model voice chunks at 60 FPS.

---

## 🚀 Running & Building

### 1. Run on Device / Emulator
```bash
flutter pub get
flutter run
```

### 2. Compile Release APK to Isolated Output Directory
Run the automated build script to route the output directly into `build/mobile/`:
```powershell
.\build_mobile.ps1 -Release
```
Compiled artifact:
`build/mobile/avis-mobile-release.apk`
