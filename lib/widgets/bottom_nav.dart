import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Futuristic Sci-Fi Floating Glassmorphic HUD Bottom Navigation Bar
class AvisBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback? onToggleTyping;
  final VoidCallback? onDoubleTapTyping;
  final bool isTypingActive;
  final TextEditingController? textController;
  final VoidCallback? onSendText;
  final FocusNode? focusNode;
  final String activePersona;
  final bool isCyberKeyboardActive;
  final VoidCallback? onToggleCyberKeyboard;

  const AvisBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    this.onToggleTyping,
    this.onDoubleTapTyping,
    this.isTypingActive = false,
    this.textController,
    this.onSendText,
    this.focusNode,
    this.activePersona = "AVIS",
    this.isCyberKeyboardActive = false,
    this.onToggleCyberKeyboard,
  });

  @override
  Widget build(BuildContext context) {
    final isAvis = activePersona.toUpperCase() == "AVIS";
    final themeColor = isAvis ? AppTheme.neonCyan : AppTheme.neonMagenta;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark.withValues(alpha: 0.60),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: (isTypingActive ? AppTheme.cyberGreen : themeColor).withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: (isTypingActive ? AppTheme.cyberGreen : themeColor).withValues(alpha: 0.15),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: SizedBox(
              height: 62,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axis: Axis.horizontal,
                      child: child,
                    ),
                  );
                },
                child: isTypingActive
                    ? _buildTypingBarView(context, themeColor)
                    : _buildStandardNavView(context, themeColor),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Standard 4-Tab Navigation Bar View
  Widget _buildStandardNavView(BuildContext context, Color themeColor) {
    return KeyedSubtree(
      key: const ValueKey('nav_icons_view'),
      child: Row(
        children: [
          Expanded(
            child: _buildNavBtn(
              icon: Icons.tune_rounded,
              activeIcon: Icons.settings_suggest_rounded,
              label: 'Settings',
              isSelected: currentIndex == 0,
              activeColor: themeColor,
              onTap: () {
                HapticFeedback.selectionClick();
                onTabSelected(0);
              },
            ),
          ),
          Expanded(
            child: _buildNavBtn(
              icon: Icons.blur_circular_rounded,
              activeIcon: Icons.lens_blur_rounded,
              label: 'Home',
              isSelected: currentIndex == 1,
              activeColor: themeColor,
              onTap: () {
                HapticFeedback.selectionClick();
                onTabSelected(1);
              },
            ),
          ),
          // Typing Bar Toggle Button (Supports Double-Tap for Sci-Fi Cyber Terminal Keyboard)
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onToggleTyping?.call();
              },
              onDoubleTap: () {
                HapticFeedback.mediumImpact();
                onDoubleTapTyping?.call();
              },
              behavior: HitTestBehavior.opaque,
              child: _buildNavBtn(
                icon: Icons.keyboard_alt_outlined,
                activeIcon: Icons.keyboard_alt_rounded,
                label: 'Type',
                isSelected: isTypingActive,
                activeColor: AppTheme.cyberGreen,
                onTap: () {}, // Handled by GestureDetector parent
              ),
            ),
          ),
          Expanded(
            child: _buildNavBtn(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.fingerprint_rounded,
              label: 'Profile',
              isSelected: currentIndex == 2,
              activeColor: themeColor,
              onTap: () {
                HapticFeedback.selectionClick();
                onTabSelected(2);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Full-Width Expanded Sci-Fi Typing Bar View (Minimal Clean Layout)
  Widget _buildTypingBarView(BuildContext context, Color themeColor) {
    return KeyedSubtree(
      key: const ValueKey('typing_bar_view'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
        child: Row(
          children: [
            const Icon(Icons.terminal_rounded, color: AppTheme.neonCyan, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: textController,
                focusNode: focusNode,
                readOnly: isCyberKeyboardActive,
                textInputAction: TextInputAction.newline,
                style: GoogleFonts.shareTechMono(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: "⚡ TYPE PROMPT TO ${activePersona.toUpperCase()}...",
                  hintStyle: GoogleFonts.shareTechMono(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                isCyberKeyboardActive ? Icons.keyboard_rounded : Icons.developer_board_rounded,
                color: isCyberKeyboardActive ? AppTheme.cyberGreen : Colors.white70,
                size: 20,
              ),
              tooltip: isCyberKeyboardActive ? "Native Soft Keyboard" : "Sci-Fi Cyber Keyboard",
              onPressed: onToggleCyberKeyboard,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBtn({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? activeColor,
  }) {
    final themeColor = activeColor ?? AppTheme.neonCyan;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      splashColor: themeColor.withValues(alpha: 0.15),
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Sci-Fi Icon with Animated Scaling and Glow
            Icon(
              isSelected ? activeIcon : icon,
              size: isSelected ? 22 : 20,
              color: isSelected ? themeColor : AppTheme.textMuted,
              shadows: isSelected
                  ? [
                      Shadow(
                        color: themeColor.withValues(alpha: 0.8),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.shareTechMono(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? themeColor : AppTheme.textMuted,
                letterSpacing: 1.1,
              ),
            ),
            // Sleek Futuristic Neon Indicator Pill Dot at bottom
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: isSelected ? 12 : 0,
              height: 2.5,
              decoration: BoxDecoration(
                color: isSelected ? themeColor : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: themeColor.withValues(alpha: 0.9),
                          blurRadius: 6,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
