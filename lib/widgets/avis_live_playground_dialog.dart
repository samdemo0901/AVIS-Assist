import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';
import '../core/live_runner_controller.dart';

/// Futuristic Glassmorphic Multi-Language Live Playground & Execution Runner
class AvisLivePlaygroundDialog extends StatefulWidget {
  final String initialCode;
  final String language;
  final String title;

  const AvisLivePlaygroundDialog({
    super.key,
    required this.initialCode,
    this.language = 'html',
    this.title = 'Avis Live Playground',
  });

  static bool isShowing = false;

  static void show(
    BuildContext context, {
    required String code,
    String language = 'html',
    String title = 'Avis Live Playground',
  }) {
    if (isShowing) {
      // Dialog is already open and LiveRunnerController will auto-update it
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AvisLivePlaygroundDialog(
        initialCode: code,
        language: language,
        title: title,
      ),
    );
  }

  @override
  State<AvisLivePlaygroundDialog> createState() => _AvisLivePlaygroundDialogState();
}

class _AvisLivePlaygroundDialogState extends State<AvisLivePlaygroundDialog>
    with SingleTickerProviderStateMixin {
  late final LiveRunnerController _controller;
  late final WebViewController _webViewController;
  late final TabController _tabController;

  StreamSubscription? _codeUpdateSub;
  StreamSubscription? _consoleLogSub;

  int _currentTabIndex = 0;
  bool _isHotReloadBadgeVisible = false;
  Timer? _badgeTimer;
  String _currentCode = "";
  final ScrollController _consoleScrollController = ScrollController();

  double? _customWidth;
  double? _customHeight;
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    AvisLivePlaygroundDialog.isShowing = true;
    _controller = LiveRunnerController();
    _currentCode = widget.initialCode;
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() => _currentTabIndex = _tabController.index);
      }
    });

    // Initialize WebViewController
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF080C18))
      ..addJavaScriptChannel(
        'AvisBridge',
        onMessageReceived: (JavaScriptMessage message) {
          _controller.ingestBridgeMessage(message.message);
        },
      );

    // Initial code load
    _controller.loadCode(
      code: widget.initialCode,
      language: widget.language,
      title: widget.title,
    );

    _loadActiveHtml();

    // Listen for real-time hot-reloads
    _codeUpdateSub = _controller.codeUpdateStream.listen((payload) {
      if (mounted) {
        setState(() {
          _currentCode = payload.code;
          _isHotReloadBadgeVisible = true;
        });
        _loadActiveHtml();
        _badgeTimer?.cancel();
        _badgeTimer = Timer(const Duration(milliseconds: 1800), () {
          if (mounted) setState(() => _isHotReloadBadgeVisible = false);
        });
      }
    });

    // Listen for console logs and scroll
    _consoleLogSub = _controller.consoleStream.listen((_) {
      if (mounted && _currentTabIndex == 2) {
        _scrollConsoleToBottom();
      }
    });
  }

  void _loadActiveHtml() {
    if (_controller.currentPayload != null) {
      final html = _controller.buildExecutableHtml(_controller.currentPayload!);
      _webViewController.loadHtmlString(html);
    }
  }

  void _scrollConsoleToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_consoleScrollController.hasClients) {
        _consoleScrollController.animateTo(
          _consoleScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    AvisLivePlaygroundDialog.isShowing = false;
    _codeUpdateSub?.cancel();
    _consoleLogSub?.cancel();
    _badgeTimer?.cancel();
    _tabController.dispose();
    _consoleScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    double dialogWidth;
    double dialogHeight;

    if (_isMaximized) {
      dialogWidth = screenSize.width * 0.98;
      dialogHeight = screenSize.height * 0.94;
    } else {
      final defaultInitialH = _currentCode.length < 350
          ? screenSize.height * 0.50
          : screenSize.height * 0.78;
      dialogWidth = _customWidth ?? (screenSize.width * 0.94);
      dialogHeight = _customHeight ?? defaultInitialH;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Stack(
        children: [
          Container(
            width: dialogWidth,
            height: dialogHeight,
            decoration: BoxDecoration(
              color: const Color(0xF2080C18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isHotReloadBadgeVisible ? AppTheme.cyberGreen : AppTheme.neonCyan,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isHotReloadBadgeVisible ? AppTheme.cyberGreen : AppTheme.neonCyan)
                      .withValues(alpha: 0.18),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  // 1. COMPACT TOP HEADER BAR
                  _buildHeaderBar(),

                  // 2. ULTRA-COMPACT TABS NAVIGATOR
                  _buildTabBar(),

                  // 3. TAB VIEWS
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        // Tab 0: Live Execution View
                        _buildLivePreviewTab(),

                        // Tab 1: Source Code View
                        _buildSourceCodeTab(),

                        // Tab 2: Console Logs View
                        _buildConsoleTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Resizable Bottom-Right Corner Handle
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _isMaximized = false;
                  final defaultInitialH = _currentCode.length < 350
                      ? screenSize.height * 0.50
                      : screenSize.height * 0.78;
                  final curW = _customWidth ?? (screenSize.width * 0.94);
                  final curH = _customHeight ?? defaultInitialH;

                  _customWidth = (curW + details.delta.dx).clamp(240.0, screenSize.width * 0.98);
                  _customHeight = (curH + details.delta.dy).clamp(200.0, screenSize.height * 0.94);
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.neonCyan.withValues(alpha: 0.8),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: const Icon(
                  Icons.south_east_rounded,
                  size: 14,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF030712),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.neonCyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.neonCyan, width: 0.8),
            ),
            child: const Icon(Icons.rocket_launch_rounded, color: AppTheme.neonCyan, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    widget.title.toUpperCase(),
                    style: GoogleFonts.orbitron(
                      color: AppTheme.neonCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.language.toUpperCase(),
                    style: GoogleFonts.shareTechMono(color: AppTheme.textMuted, fontSize: 9),
                  ),
                ),
              ],
            ),
          ),
          if (_isHotReloadBadgeVisible)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: AppTheme.cyberGreen.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.cyberGreen, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt, color: AppTheme.cyberGreen, size: 10),
                  const SizedBox(width: 2),
                  Text(
                    "HOT",
                    style: GoogleFonts.orbitron(
                      color: AppTheme.cyberGreen,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 16),
            tooltip: "Reload Preview",
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
            onPressed: () => _loadActiveHtml(),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              _isMaximized ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded,
              color: Colors.white70,
              size: 14,
            ),
            tooltip: _isMaximized ? "Restore Window" : "Maximize Window",
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
            onPressed: () {
              setState(() {
                _isMaximized = !_isMaximized;
              });
            },
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
            tooltip: "Close",
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF0D1322),
      height: 32,
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppTheme.neonCyan,
        indicatorWeight: 2,
        labelColor: AppTheme.neonCyan,
        unselectedLabelColor: Colors.white54,
        labelPadding: EdgeInsets.zero,
        labelStyle: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.orbitron(fontSize: 10),
        tabs: [
          const Tab(
            icon: Icon(Icons.play_circle_outline_rounded, size: 13),
            text: "PREVIEW",
            iconMargin: EdgeInsets.only(bottom: 1),
          ),
          const Tab(
            icon: Icon(Icons.code_rounded, size: 13),
            text: "CODE",
            iconMargin: EdgeInsets.only(bottom: 1),
          ),
          Tab(
            icon: const Icon(Icons.terminal_rounded, size: 13),
            text: "LOGS (${_controller.logs.length})",
            iconMargin: const EdgeInsets.only(bottom: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreviewTab() {
    return Container(
      color: const Color(0xFF080C18),
      child: WebViewWidget(controller: _webViewController),
    );
  }

  Widget _buildSourceCodeTab() {
    return Container(
      color: const Color(0xFF030712),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "SOURCE CODE (${_currentCode.length} chars)",
                style: GoogleFonts.shareTechMono(color: AppTheme.textMuted, fontSize: 11),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neonCyan.withValues(alpha: 0.15),
                  foregroundColor: AppTheme.neonCyan,
                  side: const BorderSide(color: AppTheme.neonCyan, width: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: Text("COPY", style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _currentCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Code copied to clipboard!"),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF080C18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _currentCode,
                  style: GoogleFonts.firaCode(
                    color: const Color(0xFF94A3B8),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsoleTab() {
    final logs = _controller.logs;

    return Container(
      color: const Color(0xFF030712),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "INTERACTIVE JS CONSOLE & RUNTIME",
                style: GoogleFonts.shareTechMono(color: AppTheme.textMuted, fontSize: 11),
              ),
              TextButton.icon(
                icon: const Icon(Icons.clear_all_rounded, size: 14, color: Colors.white54),
                label: Text("CLEAR", style: GoogleFonts.orbitron(fontSize: 10, color: Colors.white54)),
                onPressed: () {
                  setState(() => _controller.clearLogs());
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF080C18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: logs.isEmpty
                  ? Center(
                      child: Text(
                        "No console logs generated yet.\nAny console.log() or runtime errors will appear here.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.shareTechMono(color: Colors.white30, fontSize: 11),
                      ),
                    )
                  : ListView.builder(
                      controller: _consoleScrollController,
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final entry = logs[index];
                        final isError = entry.level == 'error';
                        final isWarn = entry.level == 'warn';

                        final badgeColor = isError
                            ? Colors.redAccent
                            : (isWarn ? AppTheme.alertAmber : AppTheme.cyberGreen);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: badgeColor, width: 0.8),
                                ),
                                child: Text(
                                  entry.level.toUpperCase(),
                                  style: GoogleFonts.orbitron(
                                    color: badgeColor,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SelectableText(
                                  entry.message,
                                  style: GoogleFonts.firaCode(
                                    color: isError
                                        ? Colors.redAccent
                                        : (isWarn ? Colors.amberAccent : Colors.white70),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
