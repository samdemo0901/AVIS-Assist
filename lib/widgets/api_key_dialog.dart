import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../core/avis_session_controller.dart';

/// Modal dialog for entering and adding Google Gemini API key.
void showApiKeyDialog(BuildContext context, AvisSessionController controller) {
  final TextEditingController apiKeyController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.neonCyan, width: 1.2),
      ),
      title: Text(
        "GEMINI LIVE API KEY",
        style: GoogleFonts.orbitron(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppTheme.neonCyan,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Enter your Google Gemini API Key to enable continuous multimodal speech-to-speech interaction:",
            style: GoogleFonts.shareTechMono(
              fontSize: 12,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: apiKeyController,
            obscureText: true,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: "AIzaSy...",
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: AppTheme.surfaceCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.surfaceBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.neonCyan),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("CANCEL", style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.neonCyan.withValues(alpha: 0.2),
            foregroundColor: AppTheme.neonCyan,
            side: const BorderSide(color: AppTheme.neonCyan),
          ),
          onPressed: () {
            final newKey = apiKeyController.text.trim();
            if (newKey.isNotEmpty) {
              controller.addApiKey(newKey);
            }
            Navigator.pop(ctx);
          },
          child: const Text("ADD KEY"),
        ),
      ],
    ),
  );
}
