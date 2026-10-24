import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../core/avis_session_controller.dart';

/// Modal dialog for confirming switching between AVIS and BIBA neural personas.
void showPersonaSwitchDialog(
  BuildContext context,
  AvisSessionController controller, [
  String? targetPersona,
]) {
  final nextPersona = targetPersona ?? (controller.activePersona == "AVIS" ? "BIBA" : "AVIS");
  final isBiba = nextPersona == "BIBA";
  final accentColor = isBiba ? AppTheme.neonMagenta : AppTheme.neonCyan;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: accentColor, width: 1.5),
      ),
      title: Row(
        children: [
          Icon(
            isBiba ? Icons.favorite_rounded : Icons.smart_toy_rounded,
            color: accentColor,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            "NEURAL PROFILE SWITCH",
            style: GoogleFonts.orbitron(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
        ],
      ),
      content: Text(
        "Do you want to switch AI neural persona profile to ${isBiba ? 'BIBA (Female Companion)' : 'AVIS (Male Tech Expert)'}?",
        style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 12),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text("CANCEL", style: GoogleFonts.orbitron(color: Colors.white54, fontSize: 11)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor.withValues(alpha: 0.25),
            foregroundColor: accentColor,
            side: BorderSide(color: accentColor),
          ),
          onPressed: () {
            Navigator.pop(ctx);
            controller.setPersona(nextPersona);
          },
          child: Text("CONFIRM SWITCH", style: GoogleFonts.orbitron(fontWeight: FontWeight.bold, fontSize: 11)),
        ),
      ],
    ),
  );
}
