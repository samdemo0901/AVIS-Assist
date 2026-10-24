import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../core/avis_session_controller.dart';

/// Holographic Terminal Overlay Widget for full real-time telemetry log inspection.
class TerminalOverlay extends StatelessWidget {
  final AvisSessionController controller;
  final bool isOpen;
  final VoidCallback onClose;
  final ScrollController scrollController;

  const TerminalOverlay({
    super.key,
    required this.controller,
    required this.isOpen,
    required this.onClose,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOpen) return const SizedBox.shrink();
    final logs = controller.logs;
    final transcriptHistory = controller.transcriptHistory;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onClose,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.65),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF070B12).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.neonCyan, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.neonCyan.withValues(alpha: 0.3),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.terminal, color: AppTheme.neonCyan, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "HOLOGRAPHIC TERMINAL LOGS",
                            style: GoogleFonts.orbitron(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.neonCyan,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                        onPressed: onClose,
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: transcriptHistory.length + logs.length,
                      itemBuilder: (context, idx) {
                        if (idx < transcriptHistory.length) {
                          final item = transcriptHistory[idx];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: "${item['sender']}: ",
                                    style: GoogleFonts.shareTechMono(
                                      color: item['sender'] == 'Azhar' ? AppTheme.cyberGreen : AppTheme.neonCyan,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                  TextSpan(
                                    text: item['text'] ?? '',
                                    style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          );
                        } else {
                          final logLine = logs[idx - transcriptHistory.length];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              logLine,
                              style: GoogleFonts.shareTechMono(
                                color: logLine.contains("❌")
                                    ? Colors.redAccent
                                    : logLine.contains("✅")
                                        ? AppTheme.cyberGreen
                                        : AppTheme.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
