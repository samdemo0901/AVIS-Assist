import 'dart:async';
import 'dart:convert';

/// Represents a console log message intercepted from the live executing code
class ConsoleLogEntry {
  final DateTime timestamp;
  final String level; // 'log', 'info', 'warn', 'error'
  final String message;

  ConsoleLogEntry({
    DateTime? timestamp,
    required this.level,
    required this.message,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level,
    'message': message,
  };
}

/// Represents the active live code session payload
class LiveCodePayload {
  final String code;
  final String language; // 'html', 'javascript', 'js', 'svg', 'markdown', 'md', 'json', 'css'
  final String title;
  final DateTime updatedAt;

  LiveCodePayload({
    required this.code,
    this.language = 'html',
    this.title = 'Live Code Session',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  LiveCodePayload copyWith({
    String? code,
    String? language,
    String? title,
  }) {
    return LiveCodePayload(
      code: code ?? this.code,
      language: language ?? this.language,
      title: title ?? this.title,
      updatedAt: DateTime.now(),
    );
  }
}

/// Universal Reactive Live Runner Controller
/// Manages live code execution, real-time hot-reloading (<50ms),
/// and bi-directional console logging.
class LiveRunnerController {
  static final LiveRunnerController _instance = LiveRunnerController._internal();
  factory LiveRunnerController() => _instance;
  LiveRunnerController._internal();

  LiveCodePayload? _currentPayload;
  LiveCodePayload? get currentPayload => _currentPayload;

  final List<ConsoleLogEntry> _logs = [];
  List<ConsoleLogEntry> get logs => List.unmodifiable(_logs);

  // Broadcast stream for code hot-reloading
  final StreamController<LiveCodePayload> _codeUpdateController =
      StreamController<LiveCodePayload>.broadcast();
  Stream<LiveCodePayload> get codeUpdateStream => _codeUpdateController.stream;

  // Broadcast stream for live console logs
  final StreamController<ConsoleLogEntry> _consoleLogController =
      StreamController<ConsoleLogEntry>.broadcast();
  Stream<ConsoleLogEntry> get consoleStream => _consoleLogController.stream;

  /// Load or update the active code session (Triggers reactive hot reload if already running)
  void loadCode({
    required String code,
    String language = 'html',
    String title = 'Live Code Playground',
  }) {
    final payload = LiveCodePayload(
      code: code,
      language: language.toLowerCase().trim(),
      title: title,
    );
    _currentPayload = payload;
    _codeUpdateController.add(payload);
  }

  /// Hot-reloads updated code into the active playground session
  void hotReload(String updatedCode) {
    if (_currentPayload == null) {
      loadCode(code: updatedCode);
      return;
    }
    final updated = _currentPayload!.copyWith(code: updatedCode);
    _currentPayload = updated;
    _codeUpdateController.add(updated);
  }

  /// Ingest raw console message string from JavaScript bridge channel
  void ingestBridgeMessage(String rawJson) {
    try {
      final dynamic decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        final level = decoded['level']?.toString() ?? 'log';
        final msg = decoded['message']?.toString() ?? '';
        addConsoleLog(level: level, message: msg);
      } else {
        addConsoleLog(level: 'log', message: rawJson);
      }
    } catch (_) {
      addConsoleLog(level: 'log', message: rawJson);
    }
  }

  /// Add a log entry to the console list
  void addConsoleLog({required String level, required String message}) {
    final entry = ConsoleLogEntry(level: level, message: message);
    _logs.add(entry);
    if (_logs.length > 200) {
      _logs.removeAt(0);
    }
    _consoleLogController.add(entry);
  }

  /// Clear all console logs
  void clearLogs() {
    _logs.clear();
    _consoleLogController.add(ConsoleLogEntry(level: 'info', message: 'Console cleared.'));
  }

  /// Builds a complete, self-contained HTML5 execution document
  /// with embedded console bridges, error traps, and cybernetic styles.
  String buildExecutableHtml(LiveCodePayload payload) {
    final lang = payload.language.toLowerCase().trim();
    final rawCode = payload.code;

    // JavaScript Console Bridge & Error Trap Script
    const consoleBridgeScript = """
<script>
(function() {
  function sendToAvis(level, args) {
    try {
      const msg = Array.from(args).map(function(a) {
        if (typeof a === 'object' && a !== null) {
          try { return JSON.stringify(a, null, 2); } catch(e) { return String(a); }
        }
        return String(a);
      }).join(' ');
      if (window.AvisBridge) {
        window.AvisBridge.postMessage(JSON.stringify({ level: level, message: msg }));
      }
    } catch(e) {}
  }
  const origLog = console.log;
  const origWarn = console.warn;
  const origError = console.error;
  const origInfo = console.info;

  console.log = function() { sendToAvis('log', arguments); origLog.apply(console, arguments); };
  console.warn = function() { sendToAvis('warn', arguments); origWarn.apply(console, arguments); };
  console.error = function() { sendToAvis('error', arguments); origError.apply(console, arguments); };
  console.info = function() { sendToAvis('info', arguments); origInfo.apply(console, arguments); };

  window.onerror = function(msg, url, line, col, error) {
    sendToAvis('error', ['[Runtime Error: line ' + line + ']: ' + msg]);
    return false;
  };

  window.addEventListener('unhandledrejection', function(event) {
    sendToAvis('error', ['[Unhandled Promise Rejection]: ' + (event.reason ? event.reason.message || event.reason : 'Unknown')]);
  });
})();
</script>
""";

    // 1. Pure HTML Document
    if (lang == 'html' || lang == 'htm') {
      if (rawCode.contains('<html') || rawCode.contains('<!DOCTYPE') || rawCode.contains('<body')) {
        // Inject bridge script into existing head or at beginning
        if (rawCode.contains('<head>')) {
          return rawCode.replaceFirst('<head>', '<head>$consoleBridgeScript<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">');
        } else if (rawCode.contains('<html>')) {
          return rawCode.replaceFirst('<html>', '<html><head>$consoleBridgeScript<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no"></head>');
        }
        return "$consoleBridgeScript$rawCode";
      }

      // HTML Fragment: Wrap in modern cybernetic boilerplate
      return """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>${payload.title}</title>
  $consoleBridgeScript
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: #080C18;
      color: #E0E6ED;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", sans-serif;
      padding: 16px;
      line-height: 1.5;
    }
  </style>
</head>
<body>
  $rawCode
</body>
</html>
""";
    }

    // 2. Pure JavaScript Execution
    if (lang == 'js' || lang == 'javascript') {
      return """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>${payload.title}</title>
  $consoleBridgeScript
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: #080C18;
      color: #00F5FF;
      font-family: "Courier New", Courier, monospace;
      padding: 16px;
    }
    #output-container {
      background: #030712;
      border: 1px solid #1E293B;
      border-radius: 8px;
      padding: 16px;
      min-height: 120px;
    }
    .badge {
      display: inline-block;
      padding: 2px 8px;
      border-radius: 4px;
      font-size: 11px;
      background: #00F5FF22;
      border: 1px solid #00F5FF;
      color: #00F5FF;
      margin-bottom: 12px;
    }
  </style>
</head>
<body>
  <div class="badge">⚡ JAVASCRIPT ACTIVE EXECUTION</div>
  <div id="output-container">
    <div id="avis-live-app"></div>
  </div>
  <script>
    try {
      console.log("🚀 Initializing JavaScript execution environment...");
      $rawCode
      console.log("✅ Script execution finished.");
    } catch(e) {
      console.error(e.message || e);
    }
  </script>
</body>
</html>
""";
    }

    // 3. SVG Vector Graphic
    if (lang == 'svg') {
      return """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>${payload.title}</title>
  $consoleBridgeScript
  <style>
    body {
      background: #080C18;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      margin: 0;
      padding: 16px;
    }
    svg {
      max-width: 100%;
      height: auto;
      filter: drop-shadow(0 0 16px rgba(0, 245, 255, 0.3));
    }
  </style>
</head>
<body>
  $rawCode
</body>
</html>
""";
    }

    // 4. Fallback formatted text/markdown
    return """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>${payload.title}</title>
  $consoleBridgeScript
  <style>
    body {
      background: #080C18;
      color: #E2E8F0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      padding: 20px;
      line-height: 1.6;
    }
    pre {
      background: #030712;
      border: 1px solid #1E293B;
      border-radius: 8px;
      padding: 14px;
      overflow-x: auto;
      color: #00F5FF;
      font-family: monospace;
    }
  </style>
</head>
<body>
  <pre>$rawCode</pre>
</body>
</html>
""";
  }
}
