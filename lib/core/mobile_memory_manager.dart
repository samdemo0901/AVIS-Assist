import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'app_constants.dart';

/// Conversation turn for short-term rolling context cache
class ConversationTurn {
  final String user;
  final String ai;
  final String profile;
  final DateTime timestamp;

  ConversationTurn({
    required this.user,
    required this.ai,
    required this.profile,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'user': user,
    'ai': ai,
    'profile': profile,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ConversationTurn.fromJson(Map<String, dynamic> json) => ConversationTurn(
    user: json['user'] ?? '',
    ai: json['ai'] ?? '',
    profile: json['profile'] ?? 'AVIS',
    timestamp: json['timestamp'] != null
        ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
        : DateTime.now(),
  );
}

/// Two-Tier Persistent Cognitive Memory System for AVIS Mobile
/// 1. Long-Term Memory (long_term.json): Permanent profile facts, preferences, and custom learned notes.
/// 2. Short-Term Memory (short_term.json): Rolling cache of the last 5 conversation turns.
/// 
/// Persists directly to device storage so memory survives app closing, phone reboots, and reconnects.
class MobileMemoryManager {
  static final MobileMemoryManager _instance = MobileMemoryManager._internal();
  factory MobileMemoryManager() => _instance;

  static const MethodChannel _automationChannel = AppChannels.automation;

  // Long-Term Memory Store (in-memory mirrored with disk)
  final Map<String, dynamic> _longTermData = {};

  // Short-Term Rolling Memory Ring Buffer (Max 5 turns)
  static const int maxTurns = 5;
  final List<ConversationTurn> _shortTermTurns = [];

  String? _memoryDirPath;
  bool _isInitialized = false;

  MobileMemoryManager._internal() {
    _initializeDefaultProfile();
    init();
  }

  void _initializeDefaultProfile() {
    _longTermData['user_profile'] = {
      'name': 'Azhar',
      'title': 'Tech Content Creator & Software Developer',
      'channel': 'Technology YouTube channel with 60,000+ subscribers',
      'ecosystem': 'Samsung Galaxy & Mobile Tech Specialist',
      'communication_preference': 'Respectful, energetic, friendly Hinglish/Hindi tone',
      'preferred_male_persona': 'AVIS (Tech Architect & Co-Strategist)',
      'preferred_female_persona': 'BIBA (Caring Girlfriend Companion)',
    };
    _longTermData['facts'] = {
      'core_architecture': 'AVIS Mobile Multimodal AI Brain with Gemini Live WebSocket',
      'preferred_color': 'Neon Cyan & Obsidian Dark',
    };
  }

  /// Initialize and load persistent JSON files from disk
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final dynamic res = await _automationChannel.invokeMethod('getAppStoragePaths');
      if (res is Map && res['memoryDir'] != null) {
        _memoryDirPath = res['memoryDir'].toString();
      }
    } catch (_) {
      // Fallback local directory path
      _memoryDirPath = null;
    }

    await _loadFromDisk();
    _isInitialized = true;
  }

  File? _getFile(String filename) {
    if (_memoryDirPath == null || _memoryDirPath!.isEmpty) return null;
    final dir = Directory(_memoryDirPath!);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return File('${dir.path}/$filename');
  }

  Future<void> _loadFromDisk() async {
    try {
      // 1. Load Long-Term Memory
      final longTermFile = _getFile('long_term.json');
      if (longTermFile != null && await longTermFile.exists()) {
        final content = await longTermFile.readAsString();
        final dynamic parsed = jsonDecode(content);
        if (parsed is Map<String, dynamic>) {
          _longTermData.clear();
          _longTermData.addAll(parsed);
        }
      } else {
        // Save initial default
        await _saveLongTermToDisk();
      }

      // 2. Load Short-Term Memory
      final shortTermFile = _getFile('short_term.json');
      if (shortTermFile != null && await shortTermFile.exists()) {
        final content = await shortTermFile.readAsString();
        final dynamic parsed = jsonDecode(content);
        if (parsed is List) {
          _shortTermTurns.clear();
          for (final item in parsed) {
            if (item is Map<String, dynamic>) {
              _shortTermTurns.add(ConversationTurn.fromJson(item));
            }
          }
        }
      }
    } catch (e) {
      // If error loading, preserve in-memory defaults
    }
  }

  Future<void> _saveLongTermToDisk() async {
    try {
      final file = _getFile('long_term.json');
      if (file != null) {
        final jsonStr = const JsonEncoder.withIndent('  ').convert(_longTermData);
        await file.writeAsString(jsonStr);
      }
    } catch (_) {}
  }

  Future<void> _saveShortTermToDisk() async {
    try {
      final file = _getFile('short_term.json');
      if (file != null) {
        final list = _shortTermTurns.map((t) => t.toJson()).toList();
        final jsonStr = const JsonEncoder.withIndent('  ').convert(list);
        await file.writeAsString(jsonStr);
      }
    } catch (_) {}
  }

  /// Add a conversation turn to the short-term rolling ring buffer & persist to disk
  void addTurn(String userText, String aiText, String profile) {
    if (userText.trim().isEmpty && aiText.trim().isEmpty) return;

    _shortTermTurns.add(ConversationTurn(
      user: userText.trim(),
      ai: aiText.trim(),
      profile: profile,
    ));

    // Ring buffer eviction
    while (_shortTermTurns.length > maxTurns) {
      _shortTermTurns.removeAt(0);
    }

    _saveShortTermToDisk();
  }

  /// Clear short-term conversation cache
  String clearShortTerm() {
    _shortTermTurns.clear();
    _saveShortTermToDisk();
    return "Short-term conversation cache cleared.";
  }

  /// Remember a permanent fact into long-term memory & persist to disk
  String rememberFact(String key, String value, {String category = 'facts'}) {
    if (key.trim().isEmpty || value.trim().isEmpty) {
      return "Error: key and value cannot be empty.";
    }

    final cat = category.trim().toLowerCase();
    if (!_longTermData.containsKey(cat) || _longTermData[cat] is! Map) {
      _longTermData[cat] = <String, dynamic>{};
    }
    (_longTermData[cat] as Map)[key.trim()] = value.trim();

    _saveLongTermToDisk();
    return "[Long-Term Memory Saved]: Under '$cat', remembered '$key': '$value'";
  }

  /// Recall stored facts matching a query keyword
  String recallMemories(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) {
      return const JsonEncoder.withIndent('  ').convert(_longTermData);
    }

    final results = <String, dynamic>{};
    _longTermData.forEach((cat, data) {
      if (data is Map) {
        data.forEach((k, v) {
          if (k.toString().toLowerCase().contains(q) || v.toString().toLowerCase().contains(q) || cat.contains(q)) {
            if (!results.containsKey(cat)) {
              results[cat] = <String, dynamic>{};
            }
            results[cat][k.toString()] = v;
          }
        });
      }
    });

    if (results.isEmpty) {
      return "No memories found matching query '$query'.";
    }
    return const JsonEncoder.withIndent('  ').convert(results);
  }

  /// Forget or delete a stored fact from long-term memory & persist
  String forgetFact(String key, {String category = 'facts'}) {
    final cat = category.trim().toLowerCase();
    if (_longTermData.containsKey(cat) && _longTermData[cat] is Map) {
      final map = _longTermData[cat] as Map;
      if (map.containsKey(key.trim())) {
        map.remove(key.trim());
        _saveLongTermToDisk();
        return "[Long-Term Memory]: Successfully removed '$key' from '$cat'.";
      }
    }
    return "No fact named '$key' found under '$cat'.";
  }

  /// Formats combined long-term and short-term context for system prompt injection
  String getCombinedContextPrompt() {
    final sb = StringBuffer();

    sb.writeln("### 🧠 COGNITIVE MEMORY & CONTEXT (LONG-TERM & SHORT-TERM):");

    // 1. Long-Term Profile
    sb.writeln("\n[PERMANENT USER PROFILE & PREFERENCES (Long-Term Memory)]:");
    final profile = _longTermData['user_profile'] as Map? ?? {};
    profile.forEach((k, v) => sb.writeln("- $k: $v"));

    // Facts
    final facts = _longTermData['facts'] as Map? ?? {};
    if (facts.isNotEmpty) {
      sb.writeln("\n[CUSTOM LEARNED FACTS]:");
      facts.forEach((k, v) => sb.writeln("- $k: $v"));
    }

    // Other categories (e.g. projects, notes)
    _longTermData.forEach((k, v) {
      if (k != 'user_profile' && k != 'facts' && v is Map && v.isNotEmpty) {
        sb.writeln("\n[${k.toUpperCase()}]:");
        v.forEach((subK, subV) => sb.writeln("- $subK: $subV"));
      }
    });

    // 2. Short-Term Recent Conversation Turns
    sb.writeln("\n[RECENT CONVERSATION CONTEXT (Short-Term Memory Cache)]:");
    if (_shortTermTurns.isNotEmpty) {
      for (int i = 0; i < _shortTermTurns.length; i++) {
        final t = _shortTermTurns[i];
        sb.writeln("[Turn ${i + 1}]");
        if (t.user.isNotEmpty) sb.writeln("👤 Azhar: ${t.user}");
        if (t.ai.isNotEmpty) sb.writeln("🤖 ${t.profile}: ${t.ai}");
      }
    } else {
      sb.writeln("No prior conversation history recorded yet.");
    }

    sb.writeln("\n*CRITICAL MEMORY INSTRUCTION*:");
    sb.writeln("1. If Azhar reconnects or references earlier topics from the recent conversation context above, naturally continue from where you left off without asking him to repeat himself.");
    sb.writeln("2. If Azhar shares new personal facts or says 'isko hamesha ke liye yaad rakhna', autonomously invoke the `remember_fact` tool to permanently save it to Long-Term Memory.");

    return sb.toString();
  }

  List<ConversationTurn> get recentTurns => List.unmodifiable(_shortTermTurns);
  Map<String, dynamic> get allLongTermData => Map.unmodifiable(_longTermData);
}
