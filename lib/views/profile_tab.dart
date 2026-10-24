import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../core/app_constants.dart';

/// Profile Tab: Operator Information, Companion Ecosystem Specs, and Tools Matrix.
class ProfileTab extends StatelessWidget {
  final VoidCallback onShowSandboxOverlay;
  final VoidCallback? onOpenYouTubeConfig;

  const ProfileTab({
    super.key,
    required this.onShowSandboxOverlay,
    this.onOpenYouTubeConfig,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "OPERATOR PROFILE",
            style: GoogleFonts.orbitron(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.neonCyan,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          _buildConfigTile(
            title: "OPERATOR",
            subtitle: "Azhar (Master Administrator)",
            trailingText: "ROOT",
            trailingColor: AppTheme.neonMagenta,
          ),
          _buildConfigTile(
            title: "COMPANION ECOSYSTEM",
            subtitle: AppVersion.fullEcosystem,
            trailingText: AppVersion.current,
            trailingColor: AppTheme.cyberGreen,
          ),
          _buildConfigTile(
            title: "ZERO-REGRESSION ISOLATION",
            subtitle: "Mobile client contained strictly within mobile/",
            trailingText: "VERIFIED",
            trailingColor: AppTheme.neonCyan,
          ),
          const SizedBox(height: 20),
          Text(
            "WORKSPACE & TOOLS MATRIX",
            style: GoogleFonts.orbitron(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.neonCyan,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              // Slot 1: Active Sandbox Workspace
              InkWell(
                onTap: onShowSandboxOverlay,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.neonCyan.withValues(alpha: 0.6), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.neonCyan.withValues(alpha: 0.12),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.inventory_2_rounded, color: AppTheme.neonCyan, size: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.cyberGreen.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "ACTIVE",
                              style: GoogleFonts.shareTechMono(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.cyberGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "SANDBOX WORKSPACE",
                            style: GoogleFonts.orbitron(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textBright,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "File Manager & Previews",
                            style: GoogleFonts.shareTechMono(
                              fontSize: 9,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Slot 2: YouTube Channel Studio & AI
              InkWell(
                onTap: onOpenYouTubeConfig,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.7), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.video_library_rounded, color: Colors.redAccent, size: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "STUDIO",
                              style: GoogleFonts.shareTechMono(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "YOUTUBE STUDIO",
                            style: GoogleFonts.orbitron(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textBright,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Channel AI Intelligence",
                            style: GoogleFonts.shareTechMono(
                              fontSize: 9,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              _buildReservedToolSlot("TOOL SLOT 3"),
              _buildReservedToolSlot("TOOL SLOT 4"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReservedToolSlot(String label) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.add_box_rounded, color: Colors.white24, size: 24),
              Text(
                "SLOT",
                style: GoogleFonts.shareTechMono(
                  fontSize: 9,
                  color: Colors.white24,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white30,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Reserved for Future Tool",
                style: GoogleFonts.shareTechMono(
                  fontSize: 9,
                  color: Colors.white24,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfigTile({
    required String title,
    required String subtitle,
    required String trailingText,
    required Color trailingColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textBright,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.shareTechMono(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: trailingColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: trailingColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              trailingText,
              style: GoogleFonts.shareTechMono(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: trailingColor,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
