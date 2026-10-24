import 'dart:io';
import 'package:flutter/services.dart';

/// AVIS Mobile Sandbox Manager
/// Dedicated, safe storage workspace on device storage where AVIS can:
/// - Create, save, and update code, scripts, HTML, JSON, and text notes.
/// - Read and inspect generated files.
/// - List and manage sandbox files.
class MobileSandboxManager {
  static final MobileSandboxManager _instance = MobileSandboxManager._internal();
  factory MobileSandboxManager() => _instance;

  static const MethodChannel _automationChannel = MethodChannel('com.example.avis_mobile/automation');

  String? _sandboxDirPath;
  bool _isInitialized = false;

  MobileSandboxManager._internal() {
    init();
  }

  /// Initialize and resolve sandbox folder path
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final dynamic res = await _automationChannel.invokeMethod('getAppStoragePaths');
      if (res is Map && res['sandboxDir'] != null) {
        _sandboxDirPath = res['sandboxDir'].toString();
      }
    } catch (_) {
      _sandboxDirPath = null;
    }

    _ensureSandboxDir();
    _isInitialized = true;
  }

  Directory? _ensureSandboxDir() {
    if (_sandboxDirPath == null || _sandboxDirPath!.isEmpty) return null;
    final dir = Directory(_sandboxDirPath!);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _cleanEmptyDefaultSubfolders(dir);
    return dir;
  }

  void _cleanEmptyDefaultSubfolders(Directory rootDir) {
    try {
      for (final sub in ['html', 'scripts', 'notes', 'logs']) {
        final subDir = Directory('${rootDir.path}/$sub');
        if (subDir.existsSync() && subDir.listSync().isEmpty) {
          subDir.deleteSync(recursive: true);
        }
      }
    } catch (_) {}
  }

  String _cleanRelativePath(String relPath) {
    var clean = relPath.replaceAll('\\', '/').replaceAll('..', '').trim();
    if (clean.startsWith('/')) clean = clean.substring(1);
    return clean.isEmpty ? "untitled.txt" : clean;
  }

  File? _resolvePath(String filename) {
    final dir = _ensureSandboxDir();
    if (dir == null) return null;
    final cleanRel = _cleanRelativePath(filename);
    final file = File('${dir.path}/$cleanRel');
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    return file;
  }

  /// Create a subfolder inside the sandbox workspace
  Future<String> createSandboxFolder(String folderName) async {
    await init();
    try {
      final dir = _ensureSandboxDir();
      if (dir == null) return "Error: Sandbox folder unavailable.";
      final cleanRel = _cleanRelativePath(folderName);
      final subDir = Directory('${dir.path}/$cleanRel');
      if (!subDir.existsSync()) {
        subDir.createSync(recursive: true);
      }
      return "Successfully created sandbox folder '$cleanRel'.";
    } catch (e) {
      return "Error creating folder '$folderName': $e";
    }
  }

  /// Write or update a file inside the sandbox directory
  Future<String> writeSandboxFile(String filename, String content) async {
    await init();
    try {
      final file = _resolvePath(filename);
      if (file == null) {
        return "Error: Could not access sandbox storage directory on device.";
      }
      await file.writeAsString(content, flush: true);
      final cleanName = _cleanRelativePath(filename);
      return "Successfully created/updated file '$cleanName' in mobile sandbox (${content.length} characters, ${file.lengthSync()} bytes).";
    } catch (e) {
      return "Error writing sandbox file '$filename': $e";
    }
  }

  /// Append content to a file inside the sandbox directory
  Future<String> appendSandboxFile(String filename, String content) async {
    await init();
    try {
      final file = _resolvePath(filename);
      if (file == null) {
        return "Error: Could not access sandbox storage directory on device.";
      }
      await file.writeAsString(content, mode: FileMode.append, flush: true);
      final cleanName = _cleanRelativePath(filename);
      return "Successfully appended to file '$cleanName' in mobile sandbox (${file.lengthSync()} bytes).";
    } catch (e) {
      return "Error appending sandbox file '$filename': $e";
    }
  }

  /// Read file contents from the sandbox directory
  Future<String> readSandboxFile(String filename) async {
    await init();
    try {
      final file = _resolvePath(filename);
      if (file == null || !await file.exists()) {
        return "Error: File '$filename' does not exist in mobile sandbox.";
      }
      return await file.readAsString();
    } catch (e) {
      return "Error reading sandbox file '$filename': $e";
    }
  }

  /// List all files and subfolders stored in the sandbox directory (Sorted latest first)
  Future<String> listSandboxFiles() async {
    await init();
    try {
      final dir = _ensureSandboxDir();
      if (dir == null || !dir.existsSync()) {
        return "Mobile Sandbox is currently empty.";
      }

      final entities = dir.listSync(recursive: true);
      if (entities.isEmpty) {
        return "Mobile Sandbox is currently empty.";
      }

      // Sort latest modified items first
      entities.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      final lines = ["📦 Mobile Sandbox Workspace (${entities.length} items, latest first):"];
      final rootPath = dir.path.replaceAll('\\', '/');
      for (final e in entities) {
        var rel = e.path.replaceAll('\\', '/');
        if (rel.startsWith(rootPath)) {
          rel = rel.substring(rootPath.length);
        }
        if (rel.startsWith('/')) rel = rel.substring(1);

        final isDir = e is Directory;
        final typeIcon = isDir ? "📁" : "📄";
        final stat = e.statSync();
        final sizeStr = isDir ? "FOLDER" : "${stat.size} bytes";
        final modified = stat.modified.toLocal().toString().split('.')[0];
        lines.add(" $typeIcon $rel ($sizeStr, updated: $modified)");
      }
      return lines.join('\n');
    } catch (e) {
      return "Error listing sandbox files: $e";
    }
  }

  /// Delete a file from the sandbox directory
  Future<String> deleteSandboxFile(String filename) async {
    await init();
    try {
      final file = _resolvePath(filename);
      if (file == null || !await file.exists()) {
        return "Error: File '$filename' does not exist in sandbox.";
      }
      await file.delete();
      final cleanName = _cleanRelativePath(filename);
      return "Successfully deleted file '$cleanName' from mobile sandbox.";
    } catch (e) {
      return "Error deleting sandbox file '$filename': $e";
    }
  }

  String? get sandboxPath => _sandboxDirPath;
}
