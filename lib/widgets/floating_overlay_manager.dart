import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../core/mobile_sandbox_manager.dart';
import 'overlay_settings.dart';
import 'avis_live_playground_dialog.dart';
enum OverlayType { myDisplay, sandbox }

class OverlayPayload {
  final OverlayType type;
  final String title;
  final String content;
  final String language;

  OverlayPayload({
    required this.type,
    required this.title,
    required this.content,
    this.language = 'text',
  });
}

class FloatingOverlayWidget extends StatefulWidget {
  final OverlayPayload payload;
  final OverlaySettings settings;
  final VoidCallback onClose;

  const FloatingOverlayWidget({
    super.key,
    required this.payload,
    required this.settings,
    required this.onClose,
  });

  @override
  State<FloatingOverlayWidget> createState() => _FloatingOverlayWidgetState();
}

class _FloatingOverlayWidgetState extends State<FloatingOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;
  Timer? _autoHideTimer;
  bool _isInteracting = false;
  List<FileSystemEntity> _sandboxFiles = [];
  bool _isLoadingSandbox = false;
  OverlayPayload? _secondaryDisplayPayload;

  // New Sandbox Explorer State
  String _sandboxSearchQuery = "";
  String _sandboxFilterCategory = "ALL"; // ALL, HTML, SCRIPTS, NOTES, LOGS
  String _currentSubfolder = ""; // Relative subfolder path inside sandbox
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _setupAnimation();
    _animController.forward();

    if (widget.payload.type == OverlayType.sandbox) {
      _loadSandboxFiles();
    }

    _resetTimer();
  }

  void _setupAnimation() {
    switch (widget.settings.animationStyle) {
      case OverlayAnimation.fade:
        _animation = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
        break;
      case OverlayAnimation.scale:
        _animation = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
        break;
      case OverlayAnimation.slide:
        _animation = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
        break;
    }
  }

  void _resetTimer() {
    _autoHideTimer?.cancel();
    if (widget.settings.autoHideSeconds <= 0 || _isInteracting) return;

    _autoHideTimer = Timer(Duration(seconds: widget.settings.autoHideSeconds), () {
      if (mounted && !_isInteracting) {
        _dismiss();
      }
    });
  }

  void _onPointerDown(PointerDownEvent details) {
    setState(() {
      _isInteracting = true;
    });
    _autoHideTimer?.cancel();
  }

  void _onPointerUp(PointerUpEvent details) {
    setState(() {
      _isInteracting = false;
    });
    _resetTimer();
  }

  void _onPointerCancel(PointerCancelEvent details) {
    setState(() {
      _isInteracting = false;
    });
    _resetTimer();
  }

  Future<void> _dismiss() async {
    _autoHideTimer?.cancel();
    await _animController.reverse();
    if (mounted) {
      widget.onClose();
    }
  }

  Future<void> _loadSandboxFiles() async {
    setState(() {
      _isLoadingSandbox = true;
    });
    final manager = MobileSandboxManager();
    await manager.init();
    final rootPath = manager.sandboxPath;
    if (rootPath != null) {
      final targetPath = _currentSubfolder.isEmpty
          ? rootPath
          : "$rootPath/$_currentSubfolder";
      final dir = Directory(targetPath);
      if (dir.existsSync()) {
        final entities = dir.listSync().toList();
        // Sort: Directories first, then newest modified items
        entities.sort((a, b) {
          final aIsDir = a is Directory;
          final bIsDir = b is Directory;
          if (aIsDir != bIsDir) return aIsDir ? -1 : 1;
          return b.statSync().modified.compareTo(a.statSync().modified);
        });
        if (mounted) {
          setState(() {
            _sandboxFiles = entities;
            _isLoadingSandbox = false;
          });
        }
        return;
      }
    }
    if (mounted) {
      setState(() {
        _sandboxFiles = [];
        _isLoadingSandbox = false;
      });
    }
  }

  Future<void> _openFileInMyDisplay(File file) async {
    final fileName = file.path.replaceAll('\\', '/').split('/').last;
    try {
      final content = await file.readAsString();
      final lang = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'html';

      if (mounted) {
        AvisLivePlaygroundDialog.show(
          context,
          code: content,
          language: lang,
          title: fileName,
        );
      }
    } catch (_) {}
  }



  void _confirmDeleteEntity(FileSystemEntity entity) {
    final name = entity.path.replaceAll('\\', '/').split('/').last;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
            const SizedBox(width: 8),
            Text("Confirm Deletion", style: GoogleFonts.orbitron(fontSize: 14, color: Colors.white)),
          ],
        ),
        content: Text(
          "Are you sure you want to permanently delete \"$name\" from your sandbox workspace?",
          style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: GoogleFonts.orbitron(color: Colors.white54, fontSize: 11)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteEntity(entity);
            },
            child: Text("Delete File", style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEntity(FileSystemEntity entity) async {
    try {
      if (entity is Directory) {
        await entity.delete(recursive: true);
      } else {
        await entity.delete();
      }
    } catch (_) {}
    _loadSandboxFiles();
  }

  Future<void> _shareFile(File file) async {
    final fileName = file.path.replaceAll('\\', '/').split('/').last;
    try {
      const channel = MethodChannel('com.example.avis_mobile/automation');
      await channel.invokeMethod('shareFile', {
        'filePath': file.path,
        'title': 'Share $fileName',
      });
    } catch (e) {
      Clipboard.setData(ClipboardData(text: file.path));
    }
  }

  void _showCreateFileDialog() {
    final nameCtrl = TextEditingController();
    final contentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.neonCyan, width: 1.2),
        ),
        title: Row(
          children: [
            const Icon(Icons.note_add_rounded, color: AppTheme.neonCyan, size: 20),
            const SizedBox(width: 8),
            Text("Create New Sandbox File", style: GoogleFonts.orbitron(fontSize: 14, color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: "Filename (e.g. index.html, test.py)",
                labelStyle: GoogleFonts.shareTechMono(color: AppTheme.textMuted, fontSize: 11),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.neonCyan)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentCtrl,
              maxLines: 4,
              style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                labelText: "Initial Code / Content (Optional)",
                labelStyle: GoogleFonts.shareTechMono(color: AppTheme.textMuted, fontSize: 11),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.neonCyan)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: GoogleFonts.orbitron(color: Colors.white54, fontSize: 11)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.neonCyan.withValues(alpha: 0.2),
              foregroundColor: AppTheme.neonCyan,
              side: const BorderSide(color: AppTheme.neonCyan),
            ),
            onPressed: () async {
              final rawName = nameCtrl.text.trim();
              if (rawName.isNotEmpty) {
                final manager = MobileSandboxManager();
                final relPath = _currentSubfolder.isEmpty ? rawName : "$_currentSubfolder/$rawName";
                await manager.writeSandboxFile(relPath, contentCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadSandboxFiles();
              }
            },
            child: Text("Create File", style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCreateFolderDialog() {
    final folderCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.neonCyan, width: 1.2),
        ),
        title: Row(
          children: [
            const Icon(Icons.create_new_folder_rounded, color: AppTheme.neonCyan, size: 20),
            const SizedBox(width: 8),
            Text("Create New Sandbox Folder", style: GoogleFonts.orbitron(fontSize: 14, color: Colors.white)),
          ],
        ),
        content: TextField(
          controller: folderCtrl,
          style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            labelText: "Folder Name (e.g. my_project)",
            labelStyle: GoogleFonts.shareTechMono(color: AppTheme.textMuted, fontSize: 11),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.neonCyan)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: GoogleFonts.orbitron(color: Colors.white54, fontSize: 11)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.neonCyan.withValues(alpha: 0.2),
              foregroundColor: AppTheme.neonCyan,
              side: const BorderSide(color: AppTheme.neonCyan),
            ),
            onPressed: () async {
              final rawFolder = folderCtrl.text.trim();
              if (rawFolder.isNotEmpty) {
                final manager = MobileSandboxManager();
                final relFolder = _currentSubfolder.isEmpty ? rawFolder : "$_currentSubfolder/$rawFolder";
                await manager.createSandboxFolder(relFolder);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadSandboxFiles();
              }
            },
            child: Text("Create Folder", style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_secondaryDisplayPayload != null) {
      return FloatingOverlayWidget(
        payload: _secondaryDisplayPayload!,
        settings: widget.settings,
        onClose: () {
          setState(() {
            _secondaryDisplayPayload = null;
          });
        },
      );
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final overlayHeight = screenHeight * widget.settings.heightFactor;

    Widget childWidget = AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        if (widget.settings.animationStyle == OverlayAnimation.fade) {
          return Opacity(opacity: _animation.value, child: child);
        } else if (widget.settings.animationStyle == OverlayAnimation.scale) {
          return Transform.scale(scale: _animation.value, child: child);
        } else {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(_animation),
            child: child,
          );
        }
      },
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: Container(
          height: overlayHeight,
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.neonCyan,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.neonCyan.withValues(alpha: 0.25),
                blurRadius: 18,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _buildSandboxView(),
              ),
            ],
          ),
        ),
      ),
    );

    Alignment alignment;
    switch (widget.settings.position) {
      case OverlayPosition.top:
        alignment = Alignment.topCenter;
        break;
      case OverlayPosition.center:
        alignment = Alignment.center;
        break;
      case OverlayPosition.bottom:
        alignment = Alignment.bottomCenter;
        break;
    }

    return Align(
      alignment: alignment,
      child: childWidget,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.neonCyan.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.neonCyan.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.folder_special_rounded,
            color: AppTheme.neonCyan,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "SANDBOX // FILE MANAGER",
              style: GoogleFonts.orbitron(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.neonCyan,
                letterSpacing: 1.1,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_isInteracting)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.amber, width: 0.8),
              ),
              child: Text(
                "HOLD (PAUSED)",
                style: GoogleFonts.shareTechMono(
                  fontSize: 10,
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
            onPressed: _dismiss,
            tooltip: 'Close Popup',
          ),
        ],
      ),
    );
  }

  Widget _buildSandboxView() {
    if (_isLoadingSandbox) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.neonCyan),
      );
    }

    // Filter Files by Search Query & Category Tab
    final filtered = _sandboxFiles.where((entity) {
      final name = entity.path.replaceAll('\\', '/').split('/').last.toLowerCase();
      if (_sandboxSearchQuery.isNotEmpty && !name.contains(_sandboxSearchQuery.toLowerCase())) {
        return false;
      }

      if (_sandboxFilterCategory == "ALL") return true;
      if (entity is Directory) return true; // Always show folders

      final ext = name.contains('.') ? name.split('.').last : '';
      if (_sandboxFilterCategory == "HTML") {
        return ext == 'html' || ext == 'htm';
      } else if (_sandboxFilterCategory == "SCRIPTS") {
        return ['py', 'js', 'dart', 'sh', 'kt', 'java', 'cpp', 'c', 'ts'].contains(ext);
      } else if (_sandboxFilterCategory == "NOTES") {
        return ['md', 'txt', 'json', 'csv', 'yaml', 'yml'].contains(ext);
      } else if (_sandboxFilterCategory == "LOGS") {
        return ext == 'log';
      }
      return true;
    }).toList();

    // Calculate Storage Stats
    int totalFiles = 0;
    int totalFolders = 0;
    int totalBytes = 0;
    for (final e in _sandboxFiles) {
      if (e is Directory) {
        totalFolders++;
      } else if (e is File) {
        totalFiles++;
        totalBytes += e.lengthSync();
      }
    }
    final sizeKb = (totalBytes / 1024).toStringAsFixed(1);

    return Column(
      children: [
        // 1. Futuristic Header Bar (Breadcrumbs & Storage Summary Bar)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard.withValues(alpha: 0.8),
            border: const Border(bottom: BorderSide(color: AppTheme.surfaceBorder)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Breadcrumb / Path Display
                  if (_currentSubfolder.isNotEmpty)
                    InkWell(
                      onTap: () {
                        final parts = _currentSubfolder.split('/');
                        parts.removeLast();
                        setState(() {
                          _currentSubfolder = parts.join('/');
                        });
                        _loadSandboxFiles();
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.neonCyan.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.neonCyan),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_back_rounded, size: 14, color: AppTheme.neonCyan),
                            const SizedBox(width: 4),
                            Text("UP", style: GoogleFonts.orbitron(fontSize: 10, color: AppTheme.neonCyan, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  if (_currentSubfolder.isNotEmpty) const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Icon(Icons.folder_special_rounded, color: AppTheme.neonCyan, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            "root${_currentSubfolder.isEmpty ? '' : ' / $_currentSubfolder'}",
                            style: GoogleFonts.shareTechMono(
                              color: AppTheme.neonCyan,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Quick Action Buttons
                  InkWell(
                    onTap: _showCreateFileDialog,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.neonCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.neonCyan.withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.note_add_rounded, color: AppTheme.neonCyan, size: 16),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: _showCreateFolderDialog,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.neonCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.neonCyan.withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.create_new_folder_rounded, color: AppTheme.neonCyan, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Storage Stats Bar
              Row(
                children: [
                  Text(
                    "📁 $totalFolders Folders  |  📄 $totalFiles Files  |  💾 $sizeKb KB Used",
                    style: GoogleFonts.shareTechMono(color: AppTheme.textMuted, fontSize: 10),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: _loadSandboxFiles,
                    child: const Icon(Icons.refresh_rounded, color: AppTheme.textMuted, size: 14),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 2. Real-Time Search & Category Filter Pills Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Colors.black.withValues(alpha: 0.4),
          child: Column(
            children: [
              // Search Input
              SizedBox(
                height: 34,
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _sandboxSearchQuery = val;
                    });
                  },
                  style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: "Search sandbox files & folders...",
                    hintStyle: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 11),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.neonCyan, size: 16),
                    suffixIcon: _sandboxSearchQuery.isNotEmpty
                        ? InkWell(
                            onTap: () {
                              _searchController.clear();
                              setState(() {
                                _sandboxSearchQuery = "";
                              });
                            },
                            child: const Icon(Icons.clear_rounded, color: Colors.white54, size: 16),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                    filled: true,
                    fillColor: AppTheme.surfaceCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.neonCyan),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Category Filter Pills Horizontal ScrollView
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryPill("ALL", Icons.space_dashboard_rounded),
                    const SizedBox(width: 6),
                    _buildCategoryPill("HTML", Icons.language_rounded),
                    const SizedBox(width: 6),
                    _buildCategoryPill("SCRIPTS", Icons.code_rounded),
                    const SizedBox(width: 6),
                    _buildCategoryPill("NOTES", Icons.description_rounded),
                    const SizedBox(width: 6),
                    _buildCategoryPill("LOGS", Icons.terminal_rounded),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 3. File & Folder Items List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.folder_open_rounded, size: 42, color: Colors.white24),
                      const SizedBox(height: 8),
                      Text(
                        _sandboxFiles.isEmpty
                            ? "This sandbox directory is empty."
                            : "No items match search filter.",
                        style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(10),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entity = filtered[index];
                    final isDir = entity is Directory;
                    final name = entity.path.replaceAll('\\', '/').split('/').last;

                    if (isDir) {
                      // Directory Card
                      return Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.neonCyan.withValues(alpha: 0.4)),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.neonCyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.folder_rounded, color: AppTheme.neonCyan, size: 20),
                          ),
                          title: Text(
                            name,
                            style: GoogleFonts.orbitron(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            "SUBFOLDER",
                            style: GoogleFonts.shareTechMono(fontSize: 10, color: AppTheme.textMuted),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.chevron_right_rounded, color: AppTheme.neonCyan, size: 20),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                                onPressed: () => _deleteEntity(entity),
                                tooltip: "Delete Folder",
                              ),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              _currentSubfolder = _currentSubfolder.isEmpty
                                  ? name
                                  : "$_currentSubfolder/$name";
                            });
                            _loadSandboxFiles();
                          },
                        ),
                      );
                    }

                    // File Card
                    final file = entity as File;
                    final size = file.lengthSync();
                    final sizeStr = size > 1024 ? "${(size / 1024).toStringAsFixed(1)} KB" : "$size B";
                    final stat = file.statSync();
                    final modTime = stat.modified.toString().split('.')[0];
                    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';

                    IconData fileIcon = Icons.insert_drive_file_outlined;
                    Color iconColor = AppTheme.neonCyan;
                    if (ext == 'html' || ext == 'htm') {
                      fileIcon = Icons.language_rounded;
                      iconColor = AppTheme.cyberGreen;
                    } else if (['py', 'js', 'dart', 'sh', 'kt', 'java', 'cpp', 'c', 'ts'].contains(ext)) {
                      fileIcon = Icons.code_rounded;
                      iconColor = AppTheme.neonCyan;
                    } else if (['md', 'txt', 'json', 'csv'].contains(ext)) {
                      fileIcon = Icons.description_rounded;
                      iconColor = AppTheme.neonCyan;
                    } else if (ext == 'log') {
                      fileIcon = Icons.terminal_rounded;
                      iconColor = AppTheme.alertAmber;
                    }

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: iconColor.withValues(alpha: 0.05),
                            blurRadius: 6,
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => _openFileInMyDisplay(file),
                            borderRadius: BorderRadius.circular(8),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: iconColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(fileIcon, color: iconColor, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.orbitron(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "$sizeStr  |  Updated: $modTime",
                                        style: GoogleFonts.shareTechMono(
                                          fontSize: 9,
                                          color: AppTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Compact Icon-Only Action Bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.code_rounded, color: AppTheme.neonCyan, size: 18),
                                onPressed: () => _openFileInMyDisplay(file),
                                tooltip: 'View Code (Top Overlay)',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(6),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.share_rounded, color: AppTheme.neonCyan, size: 18),
                                onPressed: () => _shareFile(file),
                                tooltip: 'Share File',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(6),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                onPressed: () => _confirmDeleteEntity(file),
                                tooltip: 'Delete File',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(6),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryPill(String category, IconData icon) {
    final isSelected = _sandboxFilterCategory == category;
    return InkWell(
      onTap: () {
        setState(() {
          _sandboxFilterCategory = category;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.neonCyan.withValues(alpha: 0.25)
              : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppTheme.neonCyan : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isSelected ? AppTheme.neonCyan : AppTheme.textMuted),
            const SizedBox(width: 4),
            Text(
              category,
              style: GoogleFonts.orbitron(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.neonCyan : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
