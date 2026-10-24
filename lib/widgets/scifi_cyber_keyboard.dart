import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

enum KeyboardMode { alpha, numeric, symbols }

/// Futuristic Sci-Fi Cyberpunk Virtual Hologram Keyboard Widget
class SciFiCyberKeyboard extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback onSend;
  final VoidCallback onClose;
  final VoidCallback? onRunCode;
  final VoidCallback? onClear;
  final VoidCallback? onToggleVoice;
  final VoidCallback? onSwitchToSoftKeyboard;
  final String activePersona;

  const SciFiCyberKeyboard({
    super.key,
    required this.controller,
    this.focusNode,
    required this.onSend,
    required this.onClose,
    this.onRunCode,
    this.onClear,
    this.onToggleVoice,
    this.onSwitchToSoftKeyboard,
    this.activePersona = "AVIS",
  });

  @override
  State<SciFiCyberKeyboard> createState() => _SciFiCyberKeyboardState();
}

class _SciFiCyberKeyboardState extends State<SciFiCyberKeyboard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  KeyboardMode _mode = KeyboardMode.alpha;
  bool _isShiftActive = false;
  Timer? _backspaceTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _backspaceTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _handleKeyPress(String char) {
    HapticFeedback.lightImpact();
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    final insertChar = _isShiftActive ? char.toUpperCase() : char.toLowerCase();

    int start = selection.start >= 0 ? selection.start : text.length;
    int end = selection.end >= 0 ? selection.end : text.length;

    final newText = text.replaceRange(start, end, insertChar);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + insertChar.length),
    );
  }

  Future<void> _handlePaste() async {
    HapticFeedback.mediumImpact();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      final pastedText = data.text!;
      final text = widget.controller.text;
      final selection = widget.controller.selection;

      int start = selection.start >= 0 ? selection.start : text.length;
      int end = selection.end >= 0 ? selection.end : text.length;

      final newText = text.replaceRange(start, end, pastedText);
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + pastedText.length),
      );
    }
  }

  void _handleBackspace() {
    HapticFeedback.lightImpact();
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    if (text.isEmpty) return;

    int start = selection.start >= 0 ? selection.start : text.length;
    int end = selection.end >= 0 ? selection.end : text.length;

    if (start != end) {
      final newText = text.replaceRange(start, end, '');
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start),
      );
    } else if (start > 0) {
      final newText = text.replaceRange(start - 1, start, '');
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start - 1),
      );
    }
  }

  void _startAutoBackspace() {
    _handleBackspace();
    _backspaceTimer?.cancel();
    _backspaceTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      _handleBackspace();
    });
  }

  void _stopAutoBackspace() {
    _backspaceTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final isAvis = widget.activePersona.toUpperCase() == "AVIS";
    final themeColor = isAvis ? AppTheme.neonCyan : AppTheme.neonMagenta;

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return FractionalTranslation(
          translation: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: themeColor.withValues(alpha: 0.45),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: themeColor.withValues(alpha: 0.20),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. EMBEDDED PROMPT INPUT BAR (Zero Gap)
                    _buildEmbeddedPromptInputBar(themeColor),

                    // 2. CYBER MACRO SHORTCUTS BAR (Zero Gap)
                    _buildMacroBar(themeColor),
                    const SizedBox(height: 6),

                    // 3. MAIN KEYBOARD MATRIX (Holographic Floating Keys)
                    if (_mode == KeyboardMode.alpha)
                      _buildAlphaKeyboard(themeColor)
                    else if (_mode == KeyboardMode.numeric)
                      _buildNumericKeyboard(themeColor)
                    else
                      _buildSymbolsKeyboard(themeColor),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Embedded Prompt Input Bar inside Single Unified Terminal Container
  Widget _buildEmbeddedPromptInputBar(Color themeColor) {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: themeColor.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.terminal_rounded, color: themeColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              readOnly: true, // Suppresses native Android soft keyboard!
              showCursor: true,
              textInputAction: TextInputAction.newline,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.shareTechMono(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: "⚡ TYPE PROMPT TO ${widget.activePersona.toUpperCase()}...",
                hintStyle: GoogleFonts.shareTechMono(
                  color: Colors.white38,
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          if (widget.controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                setState(() {
                  widget.controller.clear();
                  widget.onClear?.call();
                });
              },
            ),
        ],
      ),
    );
  }

  /// Top AI Cyber Macro Shortcuts Bar
  Widget _buildMacroBar(Color themeColor) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          // Persona Quick Insert
          _buildMacroButton(
            label: "⚡ ${widget.activePersona}",
            color: themeColor,
            onTap: () => _handleKeyPress("${widget.activePersona}: "),
          ),
          const SizedBox(width: 4),
          // Run Code Macro
          _buildMacroButton(
            label: "▶ RUN",
            color: AppTheme.neonBlue,
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onRunCode?.call();
            },
          ),
          const SizedBox(width: 4),
          // NEW 📋 PASTE Macro Button
          _buildMacroButton(
            label: "📋 PASTE",
            color: Colors.amberAccent,
            onTap: _handlePaste,
          ),
          const SizedBox(width: 4),
          // Clear Button
          _buildMacroButton(
            label: "🗑 CLEAR",
            color: Colors.redAccent,
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.controller.clear();
              widget.onClear?.call();
            },
          ),
          const SizedBox(width: 4),
          // Voice Toggle
          _buildMacroButton(
            label: "🎙 VOICE",
            color: AppTheme.cyberGreen,
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onToggleVoice?.call();
            },
          ),
          const Spacer(),
          // Close Keyboard
          IconButton(
            icon: const Icon(Icons.keyboard_hide_rounded, color: Colors.white70, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: "Close Sci-Fi Keyboard",
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildMacroButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
        ),
        child: Text(
          label,
          style: GoogleFonts.orbitron(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  /// QWERTY Alpha Keyboard Layout
  Widget _buildAlphaKeyboard(Color themeColor) {
    final row1 = ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"];
    final row2 = ["A", "S", "D", "F", "G", "H", "J", "K", "L"];
    final row3 = ["Z", "X", "C", "V", "B", "N", "M"];

    return Column(
      children: [
        _buildKeyRow(row1, themeColor),
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _buildKeyRow(row2, themeColor),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            // Shift Key
            _buildSpecialKey(
              flex: 3,
              child: Icon(
                _isShiftActive ? Icons.arrow_circle_up : Icons.arrow_circle_up_outlined,
                color: _isShiftActive ? themeColor : Colors.white60,
                size: 20,
              ),
              color: _isShiftActive ? themeColor.withValues(alpha: 0.3) : AppTheme.surfaceDark,
              onTap: () {
                setState(() => _isShiftActive = !_isShiftActive);
              },
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 14,
              child: _buildKeyRow(row3, themeColor),
            ),
            const SizedBox(width: 4),
            // Backspace Key
            _buildSpecialKey(
              flex: 3,
              child: const Icon(Icons.backspace_outlined, color: Colors.white70, size: 18),
              onTapDown: (_) => _startAutoBackspace(),
              onTapUp: (_) => _stopAutoBackspace(),
              onTapCancel: _stopAutoBackspace,
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 5),
        _buildBottomActionRow(themeColor),
      ],
    );
  }

  /// Numeric 123 Layout
  Widget _buildNumericKeyboard(Color themeColor) {
    final row1 = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"];
    final row2 = ["@", "#", "\$", "%", "&", "*", "-", "+", "(", ")"];
    final row3 = ["/", "\\", "=", "<", ">", "[", "]", "{", "}"];

    return Column(
      children: [
        _buildKeyRow(row1, themeColor),
        const SizedBox(height: 5),
        _buildKeyRow(row2, themeColor),
        const SizedBox(height: 5),
        Row(
          children: [
            _buildSpecialKey(
              flex: 3,
              child: Text("#+=", style: GoogleFonts.orbitron(fontSize: 10, color: themeColor, fontWeight: FontWeight.bold)),
              onTap: () => setState(() => _mode = KeyboardMode.symbols),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 14,
              child: _buildKeyRow(row3, themeColor),
            ),
            const SizedBox(width: 4),
            _buildSpecialKey(
              flex: 3,
              child: const Icon(Icons.backspace_outlined, color: Colors.white70, size: 18),
              onTapDown: (_) => _startAutoBackspace(),
              onTapUp: (_) => _stopAutoBackspace(),
              onTapCancel: _stopAutoBackspace,
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 5),
        _buildBottomActionRow(themeColor),
      ],
    );
  }

  /// Advanced Sci-Fi Symbols Layout
  Widget _buildSymbolsKeyboard(Color themeColor) {
    final row1 = ["~", "`", "|", "•", "√", "π", "÷", "×", "¶", "△"];
    final row2 = ["£", "¢", "€", "¥", "^", "°", "=", "{", "}", "\\"];
    final row3 = ["©", "®", "™", "℅", "[", "]", "<", ">", "!", "?"];

    return Column(
      children: [
        _buildKeyRow(row1, themeColor),
        const SizedBox(height: 5),
        _buildKeyRow(row2, themeColor),
        const SizedBox(height: 5),
        Row(
          children: [
            _buildSpecialKey(
              flex: 3,
              child: Text("123", style: GoogleFonts.orbitron(fontSize: 10, color: themeColor, fontWeight: FontWeight.bold)),
              onTap: () => setState(() => _mode = KeyboardMode.numeric),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 14,
              child: _buildKeyRow(row3, themeColor),
            ),
            const SizedBox(width: 4),
            _buildSpecialKey(
              flex: 3,
              child: const Icon(Icons.backspace_outlined, color: Colors.white70, size: 18),
              onTapDown: (_) => _startAutoBackspace(),
              onTapUp: (_) => _stopAutoBackspace(),
              onTapCancel: _stopAutoBackspace,
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 5),
        _buildBottomActionRow(themeColor),
      ],
    );
  }

  Widget _buildKeyRow(List<String> keys, Color themeColor) {
    return Row(
      children: keys.map((k) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _buildKeyItem(k, themeColor),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKeyItem(String char, Color themeColor) {
    final displayChar = _isShiftActive ? char.toUpperCase() : char.toLowerCase();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleKeyPress(char),
        borderRadius: BorderRadius.circular(8),
        splashColor: themeColor.withValues(alpha: 0.4),
        highlightColor: themeColor.withValues(alpha: 0.2),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: themeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: themeColor.withValues(alpha: 0.4), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: themeColor.withValues(alpha: 0.10),
                blurRadius: 6,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Center(
            child: Text(
              displayChar,
              style: GoogleFonts.shareTechMono(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _isShiftActive ? themeColor : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey({
    required int flex,
    required Widget child,
    required VoidCallback onTap,
    Color? color,
    GestureTapDownCallback? onTapDown,
    GestureTapUpCallback? onTapUp,
    VoidCallback? onTapCancel,
  }) {
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTapDown: onTapDown,
        onTapUp: onTapUp,
        onTapCancel: onTapCancel,
        onTap: onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: color ?? AppTheme.surfaceDark.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24, width: 0.8),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }

  /// Bottom Row: Mode Toggle (123/ABC), Spacebar, Send Action
  Widget _buildBottomActionRow(Color themeColor) {
    return Row(
      children: [
        // Mode Switch Key (ABC vs 123)
        _buildSpecialKey(
          flex: 4,
          child: Text(
            _mode == KeyboardMode.alpha ? "123" : "ABC",
            style: GoogleFonts.orbitron(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: themeColor,
            ),
          ),
          onTap: () {
            setState(() {
              _mode = _mode == KeyboardMode.alpha ? KeyboardMode.numeric : KeyboardMode.alpha;
            });
          },
        ),
        const SizedBox(width: 4),

        // Spacebar
        Expanded(
          flex: 12,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _handleKeyPress(" "),
              borderRadius: BorderRadius.circular(8),
              splashColor: themeColor.withValues(alpha: 0.3),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: themeColor.withValues(alpha: 0.4), width: 1),
                ),
                child: Center(
                  child: Text(
                    "SPACE // AVIS",
                    style: GoogleFonts.shareTechMono(
                      fontSize: 11,
                      color: Colors.white54,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),

        // Send Button
        _buildSpecialKey(
          flex: 4,
          child: Container(
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: themeColor, width: 1),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "SEND",
                    style: GoogleFonts.orbitron(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.send_rounded, size: 12, color: themeColor),
                ],
              ),
            ),
          ),
          onTap: () {
            HapticFeedback.mediumImpact();
            widget.onSend();
          },
        ),
      ],
    );
  }
}
