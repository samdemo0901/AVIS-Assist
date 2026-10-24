import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// AVIS Sci-Fi Futuristic Mobile Design System Palette & Typography
class AppTheme {
  // Background & Surface
  static const Color background = Color(0xFF070B12);
  static const Color surfaceDark = Color(0xFF0D1626);
  static const Color surfaceCard = Color(0xCC0E182A);
  static const Color surfaceBorder = Color(0x4000E5FF);

  // Neon Accents
  static const Color neonCyan = Color(0xFF00E5FF);       // AVIS Primary Glow
  static const Color neonBlue = Color(0xFF1E88E5);       // Electric Secondary
  static const Color neonMagenta = Color(0xFFD946EF);    // Accent Pulse
  static const Color cyberGreen = Color(0xFF00FF9D);     // Active / Secure State
  static const Color alertAmber = Color(0xFFFF9100);     // Muted / Standby State
  static const Color textMuted = Color(0xFF718096);
  static const Color textBright = Color(0xFFF7FAFC);

  // Typography
  static TextStyle get titleLarge => GoogleFonts.orbitron(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: 4.0,
    color: neonCyan,
    shadows: [
      const Shadow(color: neonCyan, blurRadius: 18),
      const Shadow(color: Color(0x8000E5FF), blurRadius: 36),
    ],
  );

  static TextStyle get subtitle => GoogleFonts.shareTechMono(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.2,
    color: textMuted,
  );

  static TextStyle get telemetryText => GoogleFonts.shareTechMono(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: cyberGreen,
  );

  static TextStyle get badgeText => GoogleFonts.shareTechMono(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.5,
  );

  // Glassmorphic Card Decoration
  static BoxDecoration glassCardDecoration({
    Color borderColor = surfaceBorder,
    double borderRadius = 16.0,
  }) {
    return BoxDecoration(
      color: surfaceCard,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor, width: 1.2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}
