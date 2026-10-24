import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Top Section Widget featuring animated entry for "AVIS" / "BIBA",
/// holographic subtitle, dynamic system date, and auto-collapsing top-right status telemetry.
class TopHeader extends StatefulWidget {
  final bool isListening;
  final bool isMuted;
  final String personaName;
  final String? statusLabel;

  const TopHeader({
    super.key,
    required this.isListening,
    required this.isMuted,
    this.personaName = "AVIS",
    this.statusLabel,
  });

  @override
  State<TopHeader> createState() => _TopHeaderState();
}

class _TopHeaderState extends State<TopHeader> {
  bool _isExpanded = true;
  Timer? _collapseTimer;

  @override
  void initState() {
    super.initState();
    _triggerStatusExpand();
  }

  @override
  void didUpdateWidget(TopHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statusLabel != widget.statusLabel ||
        oldWidget.isListening != widget.isListening ||
        oldWidget.isMuted != widget.isMuted) {
      _triggerStatusExpand();
    }
  }

  void _triggerStatusExpand() {
    _collapseTimer?.cancel();
    setState(() {
      _isExpanded = true;
    });
    _collapseTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _isExpanded = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAvis = widget.personaName.toUpperCase() == "AVIS";
    final displayTitle = isAvis ? "A.V.I.S" : "B.I.B.A";
    final primaryColor = isAvis ? AppTheme.neonCyan : AppTheme.neonMagenta;

    // Format real dynamic system date: YYYY.MM.DD
    final now = DateTime.now();
    final dateStr = "SYS // ${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}";

    Color statusColor;
    if (widget.isMuted || (widget.statusLabel?.contains("PASSIVE") == true) || (widget.statusLabel?.contains("SILENT") == true)) {
      statusColor = AppTheme.alertAmber;
    } else if (widget.isListening) {
      statusColor = AppTheme.cyberGreen;
    } else {
      statusColor = primaryColor;
    }

    // Replace any mention of "Gemini" with "AVIS"
    String rawStatus = widget.statusLabel ??
        (widget.isMuted
            ? "MIC MUTED"
            : (widget.isListening ? "LISTENING..." : "STANDBY"));
    rawStatus = rawStatus.replaceAll("Gemini", "AVIS").replaceAll("GEMINI", "AVIS").replaceAll("●", "").trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Telemetry Top Row (Dynamic Real Date, Top-Right Integrated Status with 2.5s Auto-Collapse)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateStr,
                style: AppTheme.subtitle.copyWith(fontSize: 11),
              ),

              // Top-Right Integrated Status Badge (Auto-collapsing to dot after 2.5s)
              GestureDetector(
                onTap: _triggerStatusExpand,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  padding: EdgeInsets.symmetric(
                    horizontal: _isExpanded ? 10 : 6,
                    vertical: _isExpanded ? 3 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: _isExpanded ? 0.12 : 0.20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.6), width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withValues(alpha: 0.9),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        if (_isExpanded) ...[
                          const SizedBox(width: 6),
                          Text(
                            rawStatus,
                            style: GoogleFonts.shareTechMono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 2. Animated Entry for "A.V.I.S" / "B.I.B.A"
          SizedBox(
            height: 38,
            child: DefaultTextStyle(
              style: AppTheme.titleLarge.copyWith(
                color: primaryColor,
                letterSpacing: 4.0,
                shadows: [
                  Shadow(color: primaryColor, blurRadius: 18),
                  Shadow(color: primaryColor.withValues(alpha: 0.5), blurRadius: 36),
                ],
              ),
              child: AnimatedTextKit(
                key: ValueKey(displayTitle),
                animatedTexts: [
                  TypewriterAnimatedText(
                    displayTitle,
                    speed: const Duration(milliseconds: 150),
                    cursor: '_',
                    curve: Curves.easeOutExpo,
                  ),
                  WavyAnimatedText(
                    displayTitle,
                    speed: const Duration(milliseconds: 200),
                  ),
                ],
                repeatForever: true,
                isRepeatingAnimation: true,
              ),
            ),
          ),

          const SizedBox(height: 4),

          // 3. Subtitle
          Text(
            isAvis
                ? "AZHAR'S VIRTUAL INTELLIGENT SYSTEM"
                : "BEAUTIFUL, INTELLIGENT, AND BELOVED ASSISTANT",
            style: AppTheme.subtitle.copyWith(
              fontSize: 10,
              letterSpacing: 1.2,
              color: isAvis ? AppTheme.textMuted : AppTheme.neonMagenta.withValues(alpha: 0.85),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
