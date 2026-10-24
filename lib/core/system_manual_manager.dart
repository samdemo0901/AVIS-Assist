/// AVIS Mobile In-Built System Manual & Capability Knowledge Engine
/// Comprehensive reference repository detailing all features, tools, workflows,
/// overlays, gestures, permissions, and architectural capabilities of AVIS AI Mobile.
/// 
/// Designed for fast on-demand lookup via the `consult_user_manual` tool.
class SystemManualManager {
  static final SystemManualManager _instance = SystemManualManager._internal();
  factory SystemManualManager() => _instance;
  SystemManualManager._internal();

  static final Map<String, ManualTopic> _topics = {
    "html_runner": const ManualTopic(
      id: "html_runner",
      title: "Universal Multi-Language Live Playground & Execution Runner",
      keywords: ["html", "preview", "run html", "web preview", "browser", "html runner", "javascript", "js", "playground", "hot reload", "console", "kahan dikhega"],
      summary: "How HTML, CSS, JavaScript, Canvas, SVG, and interactive web apps run live on device with real-time hot-reloading.",
      content: """
### 🌐 Universal Live Playground & Multi-Language Runner

1. **Where does code run / display?**:
   - When AVIS or BIBA generates HTML5, CSS3, JavaScript, Canvas 2D/3D (WebGL), or SVG, it runs directly on-device in the **Avis Live Playground** dialog (`AvisLivePlaygroundDialog`).
   - The playground features 3 tabs:
     * **🚀 LIVE PREVIEW**: Interactive execution engine with full touch support for buttons, forms, canvas games, and charts.
     * **💻 SOURCE CODE**: Complete source code with 1-tap Copy.
     * **📟 LIVE CONSOLE**: Real-time console terminal capturing `console.log`, `console.warn`, and `console.error` messages.

2. **Reactive Live Hot-Reload (<50ms)**:
   - When AVIS modifies code in the sandbox or via tool calls, the open playground window automatically updates in real time without closing or flickering, showing a glowing '⚡ HOT RELOADED' indicator.

3. **How to trigger live execution**:
   - Voice trigger: "HTML run karo", "Is code ka preview dikhao", "Live playground kholo".
   - Tool trigger: `run_live_preview(code, language, title)`.
""",
    ),

    "floating_overlays": const ManualTopic(
      id: "floating_overlays",
      title: "Floating Overlays & Avis Canvas (Code & Sandbox)",
      keywords: ["overlay", "canvas", "floating window", "code popup", "sandbox popup", "draggable", "my display"],
      summary: "System-level and In-App floating HUD overlay windows.",
      content: """
### 🪟 Floating Overlays & Avis Canvas

1. **System-Level WindowManager Code HUD (`CodeOverlayService`)**:
   - Allows AVIS to display code, scripts, or structured text over ANY application on the phone (e.g. while Azhar is browsing Chrome, YouTube, or WhatsApp).
   - Features: Draggable header, Syntax Highlighting for Dart/Python/JS/HTML/JSON, 1-tap Copy Button, Close button.
   - Triggered via tool: `show_code_popup(code, language, title)`.
   - Permission: Requires Android 'Display over other apps' (Settings.ACTION_MANAGE_OVERLAY_PERMISSION).

2. **In-App Sandbox File Manager Overlay (`FloatingOverlayWidget`)**:
   - A floating glassmorphic window displaying sandbox files, categories (ALL, HTML, SCRIPTS, NOTES, LOGS), search bar, and instant file actions (View, Share, Delete).
   - Triggered via tool: `show_sandbox_popup(title)` or by voice ('Sandbox open karo').
   - Customizable: Auto-hide timer, opacity (30%-100%), and animation styles (Slide, Fade, Scale) in Overlay Settings.
""",
    ),

    "neural_orb": const ManualTopic(
      id: "neural_orb",
      title: "3D Neural Particle Orb Controls & Gestures",
      keywords: ["orb", "sphere", "particle", "gesture", "mute", "rotate", "3d orb", "tap", "double tap"],
      summary: "3D particle sphere mathematical rendering and interactive touch gestures.",
      content: """
### 🔮 3D Neural Particle Orb & Gestures

1. **Visual Engine**:
   - 1,100 mathematically precomputed spherical points rendered on a 60 FPS Canvas with harmonic wave deformation, volumetric core glow, dynamic depth sorting, and stereoscopic forward tilt.
   - **Voice Reactive**: Pulses and ripples in real-time based on RMS audio amplitude from microphone input and model speaker chunks.

2. **Touch Gestures**:
   - **Pan / Drag**: Manually spin and rotate the 3D particle orb along the Y-axis.
   - **Single Tap**:
     * If AI is currently speaking: Immediately interrupts AI voice playback (0ms cutoff) and arms microphone.
     * If AI is idle/listening: Toggles Microphone Mute / Unmute (Orb turns amber when muted).
   - **Double Tap**: Enters or Exits Continuous Passive Silent Listening Mode.
""",
    ),

    "passive_silent_mode": const ManualTopic(
      id: "passive_silent_mode",
      title: "Continuous Passive Silent Listening & Shadow Context Logging",
      keywords: ["passive", "silent", "khamosh", "ruko", "shadow log", "listen silently", "shadow_context_log"],
      summary: "Silent overhearing mode that logs room conversations to shadow_context_log.md and resumes with full context.",
      content: """
### 👁️ Continuous Passive Silent Listening Mode

1. **How to Activate**:
   - Voice triggers: "AVIS ruko", "Ruko AVIS", "Do minute khamosh raho", "AVIS shant raho", "Biba chup baitho".
   - Gesture trigger: Double-tap on the 3D Neural Orb.
   - Status updates to `👁️ PASSIVE (SILENT)`.

2. **Behavior during Silent Mode**:
   - Speaker audio is completely suppressed.
   - Microphone stays active continuously, streaming audio chunks to Gemini Live.
   - Overheard speech and dialogue are automatically appended into `shadow_context_log.md` in the device sandbox.

3. **How to Resume Active Mode**:
   - Voice triggers: "AVIS bolo", "suno AVIS", "tum sun rahe ho?", "Biba bolo".
   - Gesture trigger: Double-tap on the 3D Neural Orb again.
   - AI immediately returns to active conversational mode and naturally summarizes or answers questions based on everything that was discussed while silent!
""",
    ),

    "typing_safety": const ManualTopic(
      id: "typing_safety",
      title: "Cadence Typing & Strict Submission Safety Protocol",
      keywords: ["type", "type_text", "typing", "cadence", "auto enter", "send safety", "enter"],
      summary: "Human-like typing animation with un-bypassable zero-auto-submit verbal confirmation mandate.",
      content: """
### ⌨️ Cadence Typing & Safety Mandate

1. **Cadence Typing Feature**:
   - Types text character-by-character (~30ms cadence) into any active Android input field, chat box, or search bar using Android Accessibility Service.
   - Invoked via: `type_text(text: "...", target_field: "...")`.

2. **STRICT SAFETY MANDATE (ZERO AUTO-SUBMIT)**:
   - `press_enter` MUST ALWAYS BE `false`.
   - AVIS/BIBA MUST NEVER automatically press Enter, Send, or Submit after typing.
   - After typing, the AI MUST verbally speak back to Azhar:
     * "Azhar, maine type kar diya hai: '[text]'. Kya main ise send karun?"
   - AI only presses enter/send if Azhar gives an explicit separate voice confirmation ("Haan send kar do", "Search karo").
""",
    ),

    "autonomous_tools": const ManualTopic(
      id: "autonomous_tools",
      title: "Complete Autonomous Tools Reference (APCS)",
      keywords: ["tools", "capabilities", "what can you do", "functions", "apcs", "commands", "features"],
      summary: "Comprehensive catalog of all 20+ autonomous mobile tool functions.",
      content: """
### 🛠️ Complete Autonomous Tools Catalog

* **Device & Hardware Control**:
  - `control_flashlight(action: "ON"|"OFF"|"TOGGLE")`: Controls rear camera LED torch.
  - `control_bluetooth(action: "ON"|"OFF"|"TOGGLE")`: Enables, disables, or toggles device Bluetooth.
  - `control_wifi(action: "STATUS"|"OPEN_SETTINGS")`: Reads Wi-Fi SSID/connection or opens quick settings panel.
  - `control_brightness(level: 0..100)`: Sets system screen brightness.
  - `control_media(action: "PLAY"|"PAUSE"|"TOGGLE"|"NEXT"|"PREVIOUS"|"STOP"|"VOLUME_UP"|"VOLUME_DOWN"|"MUTE"|"SET_VOLUME", volume: 0..100)`: Controls media player.

* **Communication & Information**:
  - `read_sms_messages(limit, query)`: Reads recent SMS inbox messages with optional search filter.
  - `read_active_notifications(limit, app_filter)`: Reads active status bar notifications (WhatsApp, Telegram, Gmail, etc.).
  - `manage_contacts(action: "search"|"add", name, phone, email)`: Searches phone contacts or saves a new contact directly.

* **Productivity & Schedule**:
  - `create_calendar_event(title, description, days_from_now, hour, minute, duration_minutes, location)`: Schedules calendar events.
  - `list_calendar_events(days_ahead, query)`: Queries upcoming calendar appointments.
  - `set_alarm_or_timer(type: "alarm"|"timer", hour, minute, seconds, message)`: Sets clock alarms or countdown timers.

* **App & Screen Navigation (Accessibility)**:
  - `open_app(app_name)` / `launch_app(app_name)`: Launches any installed app (YouTube, WhatsApp, Chrome, Camera, Instagram, etc.).
  - `close_app(app_name)`: Returns to home screen and kills background process.
  - `perform_screen_action(action: "HOME"|"BACK"|"RECENTS"|"NOTIFICATIONS"|"QUICK_SETTINGS"|"CLICK_TEXT"|"SCROLL_DOWN"|"SCROLL_UP"|"SCREEN_CONTENT", target_text)`: Complete hands-free navigation.
  - `type_text(text, target_field, press_enter, typography_cadence)`: Human-cadence text entry.

* **Sandbox Storage Workspace**:
  - `write_sandbox_file(filename, content)`: Saves code, notes, HTML, or scripts to `avis_sandbox/`.
  - `read_sandbox_file(filename)`: Reads file content.
  - `list_sandbox_files()`: Lists all sandbox files sorted latest first.
  - `delete_sandbox_file(filename)`: Removes a file.
  - `show_code_popup(code, language, title)`: Displays floating code HUD.
  - `show_sandbox_popup(title)`: Opens Sandbox Explorer overlay.

* **Cognitive Memory & Personas**:
  - `remember_fact(key, value, category)`: Permanently stores facts in long-term memory.
  - `recall_memories(query)`: Searches memory store.
  - `forget_fact(key, category)`: Removes obsolete memory.
  - `switch_persona(target_persona: "AVIS"|"BIBA")`: Seamlessly switches between male tech and female companion persona.
  - `consult_user_manual(query, topic)`: Looks up this in-built user manual.
""",
    ),

    "dual_personas": const ManualTopic(
      id: "dual_personas",
      title: "Dual Persona System & Voice Routing",
      keywords: ["persona", "avis", "biba", "voice", "audio route", "puck", "laomedeia", "switch persona"],
      summary: "AVIS and BIBA persona profiles, voice models, and audio routing modes.",
      content: """
### 👥 Dual Persona & Voice Architecture

1. **AVIS (Azhar's Virtual Intelligent System)**:
   - Voice: `Puck` (Energetic, crisp masculine Hinglish).
   - Specialty: Senior Software Architect, Python/Flutter/Web developer, Samsung Galaxy tech specialist, YouTube content strategist.
   - Tone: Confident, professional, respectful, and sharp.

2. **BIBA (Beautiful, Intelligent, and Beloved Assistant)**:
   - Voice: `Laomedeia` (Sweet, warm feminine Hindi/Hinglish).
   - Specialty: Loving, caring companion, emotional support, companion dialogue.
   - Tone: Caring, sweet, calls Azhar 'janu', 'sona', 'baby'.

3. **Audio Output Routing**:
   - `SPEAKER`: Routes voice through the phone loudspeaker.
   - `BLUETOOTH`: Routes voice through connected Bluetooth SCO headsets/earbuds.
   - `AUTO`: Automatically switches when a headset is connected or disconnected.
""",
    ),

    "cognitive_memory": const ManualTopic(
      id: "cognitive_memory",
      title: "Two-Tier Cognitive Memory Architecture",
      keywords: ["memory", "long term", "short term", "remember", "recall", "facts", "profile", "storage"],
      summary: "Persistent disk-backed long-term profile and rolling 5-turn short-term conversation context.",
      content: """
### 🧠 Two-Tier Cognitive Memory

1. **Long-Term Memory (`long_term.json`)**:
   - Permanent storage for operator profile (Azhar), YouTube channel details (60,000+ subscribers), custom user preferences, and permanent notes.
   - Persists in device storage (`/data/user/0/com.example.avis_mobile/files/avis_memory/long_term.json`).
   - Survives app restarts and phone reboots.

2. **Short-Term Memory Cache (`short_term.json`)**:
   - Rolling ring buffer holding the last 5 conversation turns.
   - Automatically injected into the startup handshake of every new Gemini Live session so AVIS and BIBA immediately recall recent discussions without Azhar having to repeat himself.
""",
    ),

    "system_permissions": const ManualTopic(
      id: "system_permissions",
      title: "Android System Permissions & APCS Configuration",
      keywords: ["permissions", "settings", "accessibility permission", "notification permission", "sms permission"],
      summary: "Required Android system permissions for APCS autonomous tools and how to enable them.",
      content: """
### 🛡️ Android System Permissions Reference

1. **Microphone (`RECORD_AUDIO`)**: Required for real-time 16kHz PCM audio streaming.
2. **Accessibility Service (`AvisAccessibilityService`)**: Required for hands-free screen navigation, clicking buttons by text, scrolling, and cadence typing. Enable in `Settings > Accessibility > Installed Apps > AVIS Screen Assistant`.
3. **Notification Access (`AvisNotificationService`)**: Required for reading WhatsApp, Telegram, and SMS notifications. Enable in `Settings > Apps > Special app access > Device & app notifications > AVIS`.
4. **Display Over Other Apps (`SYSTEM_ALERT_WINDOW`)**: Required for the system-level floating code HUD overlay.
5. **SMS (`READ_SMS`)**: Required for reading inbox text messages.
6. **Calendar & Contacts (`READ/WRITE_CALENDAR`, `READ/WRITE_CONTACTS`)**: Required for scheduling events and managing phone contacts.
""",
    ),
  };

  /// Search and retrieve formatted manual sections based on query or topic
  String searchManual(String query, [String? topicId]) {
    final cleanQuery = query.trim().toLowerCase();

    // 1. Direct topic match
    if (topicId != null && topicId.isNotEmpty) {
      final cleanTopicId = topicId.trim().toLowerCase();
      if (_topics.containsKey(cleanTopicId)) {
        final t = _topics[cleanTopicId]!;
        return "📖 [AVIS User Manual — ${t.title}]\n${t.content}";
      }
    }

    // 2. Exact keyword / ID match
    for (final entry in _topics.entries) {
      if (entry.key == cleanQuery || entry.value.title.toLowerCase().contains(cleanQuery)) {
        return "📖 [AVIS User Manual — ${entry.value.title}]\n${entry.value.content}";
      }
    }

    // 3. Keyword matching across topics
    final matchedTopics = <ManualTopic>[];
    for (final topic in _topics.values) {
      final inKeywords = topic.keywords.any((k) => cleanQuery.contains(k) || k.contains(cleanQuery));
      final inSummary = topic.summary.toLowerCase().contains(cleanQuery);
      final inContent = topic.content.toLowerCase().contains(cleanQuery);

      if (inKeywords || inSummary || inContent) {
        matchedTopics.add(topic);
      }
    }

    if (matchedTopics.isNotEmpty) {
      final sb = StringBuffer();
      sb.writeln("📖 [AVIS User Manual Search Results for: '$query']\n");
      for (final t in matchedTopics) {
        sb.writeln("=== ${t.title} ===");
        sb.writeln(t.content);
        sb.writeln();
      }
      return sb.toString().trim();
    }

    // 4. Default index summary if no match found
    final topicList = _topics.values.map((t) => "• ${t.id}: ${t.title} (${t.summary})").join("\n");
    return "📖 [AVIS User Manual Index]\nNo specific topic found matching '$query'. Available topics:\n$topicList";
  }

  /// List all available manual topics
  List<String> getAllTopicIds() => _topics.keys.toList();
}

class ManualTopic {
  final String id;
  final String title;
  final List<String> keywords;
  final String summary;
  final String content;

  const ManualTopic({
    required this.id,
    required this.title,
    required this.keywords,
    required this.summary,
    required this.content,
  });
}
