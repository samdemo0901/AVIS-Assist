import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme/app_theme.dart';
import 'core/app_constants.dart';
import 'core/avis_session_controller.dart';
import 'widgets/top_header.dart';
import 'widgets/bottom_nav.dart';
import 'widgets/overlay_settings.dart';
import 'widgets/floating_overlay_manager.dart';
import 'widgets/avis_live_playground_dialog.dart';
import 'widgets/scifi_cyber_keyboard.dart';
import 'widgets/api_key_dialog.dart';
import 'widgets/persona_switch_dialog.dart';
import 'widgets/youtube_config_dialog.dart';
import 'widgets/youtube_studio_overlay.dart';

import 'views/home_orb_view.dart';
import 'views/settings_tab.dart';
import 'views/profile_tab.dart';
import 'views/terminal_overlay.dart';

/// AVIS Next-Gen Neural Assistant Mobile Entry Point
/// Powered by Gemini Live Multimodal Bidirectional WebSocket Engine
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Global Flutter Framework Error Handler (prevents red screen crash in production)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint("⚠️ Global Flutter Error Caught: ${details.exceptionAsString()}");
  };

  // Global Platform Unhandled Async Error Handler
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint("⚠️ Global Async Error Caught: $error");
    return true; // Error handled silently without app crash
  };

  // Edge-to-edge system UI styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const AvisMobileApp());
}

class AvisMobileApp extends StatelessWidget {
  const AvisMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AVIS Mobile HUD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppTheme.background,
        colorScheme: const ColorScheme.dark(
          primary: AppTheme.neonCyan,
          secondary: AppTheme.neonBlue,
          surface: AppTheme.surfaceDark,
        ),
        textTheme: GoogleFonts.shareTechMonoTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: const AvisHomeScreen(),
    );
  }
}

class AvisHomeScreen extends StatefulWidget {
  const AvisHomeScreen({super.key});

  @override
  State<AvisHomeScreen> createState() => _AvisHomeScreenState();
}

class _AvisHomeScreenState extends State<AvisHomeScreen> {
  // Navigation State
  int _currentTabIndex = 1; // Default to 'Home' (Orb viewport)

  // Controller
  late final AvisSessionController _controller;

  // UI Interactive State
  bool _isTypingBarVisible = false;
  bool _isCyberKeyboardActive = true;
  bool _isTerminalOverlayOpen = false;

  final FocusNode _typingFocusNode = FocusNode();
  final ScrollController _terminalScrollController = ScrollController();
  final ScrollController _logScrollController = ScrollController();
  final TextEditingController _textInputController = TextEditingController();

  // Floating Overlay System State ("My Display", "Sandbox", "YouTube Studio")
  final OverlaySettings _overlaySettings = OverlaySettings();
  OverlayPayload? _activeOverlayPayload;
  bool _isYouTubeStudioOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AvisSessionController();

    // Attach callbacks before initialize
    _controller.onShowSandboxOverlay = _showSandboxOverlay;
    _controller.onShowYouTubeStudioOverlay = () {
      if (mounted) setState(() => _isYouTubeStudioOpen = true);
    };
    _controller.onRequestRunLivePreview = (code, language, title) {
      if (mounted) {
        AvisLivePlaygroundDialog.show(
          context,
          code: code,
          language: language,
          title: title,
        );
      }
    };
    _controller.onToastMessage = _showToast;
    _controller.onNoApiKeysAvailable = () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showApiKeyDialog(context, _controller);
      });
    };

    _controller.addListener(_onControllerChanged);
    _controller.initialize();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
      _scrollLogToBottom();
    }
  }

  void _showSandboxOverlay() {
    setState(() {
      _activeOverlayPayload = OverlayPayload(
        type: OverlayType.sandbox,
        title: "SANDBOX // FILE MANAGER",
        content: "",
      );
    });
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.shareTechMono(
            color: isError ? Colors.redAccent : AppTheme.cyberGreen,
            fontSize: 12,
          ),
        ),
        backgroundColor: AppTheme.surfaceDark.withValues(alpha: 0.9),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _scrollLogToBottom() {
    if (_logScrollController.hasClients) {
      _logScrollController.animateTo(
        _logScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
    if (_terminalScrollController.hasClients) {
      _terminalScrollController.animateTo(
        _terminalScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendTextInput([String? presetText]) {
    final text = (presetText ?? _textInputController.text).trim();
    if (text.isEmpty) return;

    _controller.sendTextMessage(text);
    if (presetText == null) {
      _textInputController.clear();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _textInputController.dispose();
    _logScrollController.dispose();
    _terminalScrollController.dispose();
    _typingFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Priority 1: Close active overlays / keyboard
        if (_isTerminalOverlayOpen) {
          setState(() => _isTerminalOverlayOpen = false);
          return;
        }
        if (_isYouTubeStudioOpen) {
          setState(() => _isYouTubeStudioOpen = false);
          return;
        }
        if (_activeOverlayPayload != null) {
          setState(() => _activeOverlayPayload = null);
          return;
        }
        if (_isTypingBarVisible) {
          setState(() {
            _isTypingBarVisible = false;
            _isCyberKeyboardActive = false;
          });
          return;
        }
        // Priority 2: Safely minimize app to background keeping voice session alive
        AppChannels.audio.invokeMethod('minimizeApp').catchError((_) => null);
      },
      child: Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                // 1. TOP SECTION: Animated "AVIS" / "BIBA" Entrance + Status Telemetry
                TopHeader(
                  isListening: !_controller.audioManager.isMuted && _controller.isLiveSession,
                  isMuted: _controller.audioManager.isMuted,
                  personaName: _controller.activePersona,
                  statusLabel: _controller.liveStatusMessage,
                ),

                // 2. CENTER SECTION: 3D Neural Particle Orb Viewport / Sub-Screens (Animated Page Transitions)
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.96, end: 1.0).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey<int>(_currentTabIndex),
                      child: _buildTabContent(_currentTabIndex),
                    ),
                  ),
                ),

                // 3. BOTTOM SECTION: Single Unified Sci-Fi Cyber Terminal Container OR Standard HUD Navigation Bar
                if (_isTypingBarVisible && _isCyberKeyboardActive)
                  SciFiCyberKeyboard(
                    controller: _textInputController,
                    focusNode: _typingFocusNode,
                    onSend: () => _sendTextInput(),
                    onClose: () {
                      setState(() {
                        _isTypingBarVisible = false;
                        _isCyberKeyboardActive = false;
                        _typingFocusNode.unfocus();
                      });
                    },
                    onSwitchToSoftKeyboard: () {
                      setState(() {
                        _isCyberKeyboardActive = false;
                        _typingFocusNode.requestFocus();
                      });
                    },
                    onRunCode: () {
                      if (_textInputController.text.trim().isNotEmpty) {
                        AvisLivePlaygroundDialog.show(
                          context,
                          code: _textInputController.text,
                          title: "Live Terminal Prompt",
                        );
                      }
                    },
                    onClear: () {
                      setState(() {
                        _textInputController.clear();
                      });
                    },
                    onToggleVoice: _controller.toggleLiveSession,
                    activePersona: _controller.activePersona,
                  )
                else
                  AvisBottomNav(
                    currentIndex: _currentTabIndex,
                    onTabSelected: (index) {
                      setState(() {
                        _currentTabIndex = index;
                        _isTypingBarVisible = false;
                        _isCyberKeyboardActive = false;
                      });
                      if (index == 0) {
                        _controller.refreshSystemPermissions();
                      }
                    },
                    isTypingActive: _isTypingBarVisible,
                    onToggleTyping: () {
                      setState(() {
                        _isTypingBarVisible = !_isTypingBarVisible;
                        if (_isTypingBarVisible) {
                          _isCyberKeyboardActive = false;
                          _typingFocusNode.requestFocus();
                        } else {
                          _typingFocusNode.unfocus();
                        }
                      });
                    },
                    onDoubleTapTyping: () {
                      setState(() {
                        _isTypingBarVisible = true;
                        _isCyberKeyboardActive = true;
                        _typingFocusNode.unfocus();
                      });
                    },
                    isCyberKeyboardActive: _isCyberKeyboardActive,
                    onToggleCyberKeyboard: () {
                      setState(() {
                        _isCyberKeyboardActive = !_isCyberKeyboardActive;
                        if (_isCyberKeyboardActive) {
                          _typingFocusNode.unfocus();
                        } else {
                          _typingFocusNode.requestFocus();
                        }
                      });
                    },
                    textController: _textInputController,
                    onSendText: () => _sendTextInput(),
                    focusNode: _typingFocusNode,
                    activePersona: _controller.activePersona,
                  ),
              ],
            ),
            TerminalOverlay(
              controller: _controller,
              isOpen: _isTerminalOverlayOpen,
              onClose: () => setState(() => _isTerminalOverlayOpen = false),
              scrollController: _terminalScrollController,
            ),
            if (_activeOverlayPayload != null)
              FloatingOverlayWidget(
                payload: _activeOverlayPayload!,
                settings: _overlaySettings,
                onClose: () {
                  setState(() {
                    _activeOverlayPayload = null;
                  });
                },
              ),
            if (_isYouTubeStudioOpen)
              YouTubeStudioOverlay(
                onClose: () => setState(() => _isYouTubeStudioOpen = false),
                onOpenConfig: _showYouTubeConfig,
              ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildTabContent(int index) {
    switch (index) {
      case 0:
        return SettingsTab(
          controller: _controller,
          onShowSandboxOverlay: _showSandboxOverlay,
          onShowApiKeyDialog: () => showApiKeyDialog(context, _controller),
          logScrollController: _logScrollController,
        );
      case 1:
        return HomeOrbView(
          controller: _controller,
          onShowSandboxOverlay: _showSandboxOverlay,
          onConfirmPersonaSwitch: () => showPersonaSwitchDialog(context, _controller),
          onOpenTerminalOverlay: () {
            setState(() {
              _isTerminalOverlayOpen = true;
            });
          },
          onOpenYouTubeStudio: () {
            setState(() {
              _isYouTubeStudioOpen = true;
            });
          },
        );
      case 2:
        return ProfileTab(
          onShowSandboxOverlay: _showSandboxOverlay,
          onOpenYouTubeConfig: _showYouTubeConfig,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _showYouTubeConfig() {
    showDialog(
      context: context,
      builder: (_) => YouTubeConfigDialog(
        onConfigUpdated: () {
          if (mounted) setState(() {});
        },
      ),
    );
  }
}
