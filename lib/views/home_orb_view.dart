import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../core/avis_session_controller.dart';
import '../widgets/neural_orb.dart';

/// Center Viewport: 3D Neural Particle Orb with Real-time VU meter & Voice Controls.
class HomeOrbView extends StatelessWidget {
  final AvisSessionController controller;
  final VoidCallback onShowSandboxOverlay;
  final VoidCallback onConfirmPersonaSwitch;
  final VoidCallback onOpenTerminalOverlay;
  final VoidCallback? onOpenYouTubeStudio;

  const HomeOrbView({
    super.key,
    required this.controller,
    required this.onShowSandboxOverlay,
    required this.onConfirmPersonaSwitch,
    required this.onOpenTerminalOverlay,
    this.onOpenYouTubeStudio,
  });

  @override
  Widget build(BuildContext context) {
    final isAvis = controller.activePersona == "AVIS";
    final personaColor = isAvis ? AppTheme.neonCyan : AppTheme.neonMagenta;

    return Column(
      children: [
        if (controller.isPassiveSilent)
          Container(
            margin: const EdgeInsets.only(top: 6, bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF4A148C).withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE040FB), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE040FB).withValues(alpha: 0.35),
                  blurRadius: 8,
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.remove_red_eye_rounded, color: Color(0xFFE040FB), size: 14),
                const SizedBox(width: 6),
                Text(
                  "PASSIVE SILENT LISTENING (OVERHEARING ACTIVE)",
                  style: GoogleFonts.shareTechMono(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),

        // 1. 3D Neural Particle Orb Viewport
        Expanded(
          child: Center(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                if (controller.isSpeaking) {
                  controller.interruptAi();
                } else {
                  controller.toggleMute();
                }
              },
              child: NeuralOrbWidget(
                audioLevelStream: controller.audioManager.audioLevelStream,
                isMuted: controller.audioManager.isMuted,
                primaryColor: controller.audioManager.isMuted
                    ? AppTheme.alertAmber
                    : (controller.isPassiveSilent
                        ? AppTheme.cyberGreen
                        : personaColor),
                onDoubleTap: () {
                  HapticFeedback.mediumImpact();
                  controller.togglePassiveListeningMode();
                },
                onToggleMute: () {
                  HapticFeedback.lightImpact();
                  if (controller.isSpeaking) {
                    controller.interruptAi();
                  } else {
                    controller.toggleMute();
                  }
                },
              ),
            ),
          ),
        ),

        // 2. Dual Action Bar (Left: Sandbox File Manager, Right: Screen Cast Vision Toggle)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // LEFT SIDE ACTION: Sandbox File Manager Quick Launch Button
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onShowSandboxOverlay();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: personaColor.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.inventory_2_rounded,
                        color: personaColor,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "SANDBOX",
                        style: GoogleFonts.shareTechMono(
                          fontSize: 10,
                          color: personaColor,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // CENTER ACTION: Sci-Fi Creator Studio Overlay Button
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onOpenYouTubeStudio?.call();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.video_camera_front_rounded,
                        color: Colors.redAccent,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "YT STUDIO",
                        style: GoogleFonts.shareTechMono(
                          fontSize: 10,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // RIGHT SIDE ACTION: AI Vision (Screen Share) Toggle Button
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  controller.toggleScreenCast();
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (controller.isScreenCastActive ? AppTheme.cyberGreen : AppTheme.surfaceDark).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: controller.isScreenCastActive ? AppTheme.cyberGreen : personaColor.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: controller.isScreenCastActive
                        ? [
                            BoxShadow(
                              color: AppTheme.cyberGreen.withValues(alpha: 0.4),
                              blurRadius: 10,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        controller.isScreenCastActive ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        color: controller.isScreenCastActive ? Colors.black : personaColor,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        controller.isScreenCastActive ? "VISION LIVE" : "AI VISION",
                        style: GoogleFonts.shareTechMono(
                          fontSize: 10,
                          color: controller.isScreenCastActive ? Colors.black : personaColor,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3. Live Subtitle Transcript Banner (Double-Tap to expand Holographic Terminal Overlay!)
        if (controller.latestAiTranscript.isNotEmpty || controller.latestUserTranscript.isNotEmpty)
          GestureDetector(
            onDoubleTap: () {
              HapticFeedback.mediumImpact();
              onOpenTerminalOverlay();
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: personaColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    controller.latestAiTranscript.isNotEmpty ? Icons.record_voice_over_rounded : Icons.mic_rounded,
                    color: personaColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      controller.latestAiTranscript.isNotEmpty
                          ? "${controller.activePersona}: ${controller.latestAiTranscript}"
                          : "Azhar: ${controller.latestUserTranscript}",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.shareTechMono(
                        fontSize: 11,
                        color: AppTheme.textBright,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.unfold_more_rounded, color: personaColor.withValues(alpha: 0.6), size: 14),
                ],
              ),
            ),
          ),

        // 4. Fixed-Slot Anti-Jitter Live Telemetry Bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: controller.isLiveSession
                  ? AppTheme.cyberGreen.withValues(alpha: 0.35)
                  : Colors.white12,
            ),
          ),
          child: Row(
            children: [
              // Slot 1: Mic Level %
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      child: Icon(
                        Icons.graphic_eq_rounded,
                        size: 14,
                        color: controller.isLiveSession && controller.liveAudioLevel > 0.02
                            ? AppTheme.cyberGreen
                            : AppTheme.alertAmber,
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 32,
                      child: Text(
                        "${(controller.liveAudioLevel * 100).clamp(0, 100).toInt()}%",
                        style: GoogleFonts.shareTechMono(
                          fontSize: 10,
                          color: AppTheme.textBright,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 12, color: Colors.white24),
              // Slot 2: AI PKTS Counter
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      child: Icon(
                        Icons.volume_up,
                        size: 14,
                        color: controller.speakerPacketsReceived > 0
                            ? AppTheme.neonCyan
                            : AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 66,
                      child: Text(
                        "AI: ${controller.speakerPacketsReceived} PKTS",
                        style: GoogleFonts.shareTechMono(
                          fontSize: 10,
                          color: AppTheme.textBright,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 12, color: Colors.white24),
              // Slot 3: STANDBY/LIVE Status
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 10,
                      child: Center(
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: controller.isLiveSession ? AppTheme.cyberGreen : AppTheme.alertAmber,
                            boxShadow: controller.isLiveSession
                                ? [
                                    BoxShadow(
                                      color: AppTheme.cyberGreen.withValues(alpha: 0.6),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    )
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 50,
                      child: Text(
                        controller.isLiveSession ? "LIVE" : "STANDBY",
                        style: GoogleFonts.shareTechMono(
                          fontSize: 10,
                          color: controller.isLiveSession ? AppTheme.cyberGreen : AppTheme.alertAmber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Core Multimodal AI Session Action Strip
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: controller.isLiveSession ? AppTheme.cyberGreen.withValues(alpha: 0.5) : personaColor.withValues(alpha: 0.3),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Mute / Unmute Button
              IconButton(
                icon: Icon(
                  controller.audioManager.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  color: controller.audioManager.isMuted ? AppTheme.alertAmber : AppTheme.cyberGreen,
                  size: 22,
                ),
                tooltip: controller.audioManager.isMuted ? "Unmute Mic" : "Mute Mic",
                onPressed: () {
                  HapticFeedback.selectionClick();
                  controller.toggleMute();
                },
              ),

              // 2. Primary AVIS Live Session Toggle / Interrupt Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: controller.isSpeaking
                      ? AppTheme.alertAmber.withValues(alpha: 0.25)
                      : controller.isLiveSession
                          ? Colors.redAccent.withValues(alpha: 0.2)
                          : personaColor.withValues(alpha: 0.18),
                  foregroundColor: controller.isSpeaking
                      ? AppTheme.alertAmber
                      : controller.isLiveSession
                          ? Colors.redAccent
                          : personaColor,
                  side: BorderSide(
                    color: controller.isSpeaking
                        ? AppTheme.alertAmber
                        : controller.isLiveSession
                            ? Colors.redAccent
                            : personaColor,
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: Icon(
                  controller.isSpeaking
                      ? Icons.front_hand_rounded
                      : controller.isLiveSession
                          ? Icons.call_end_rounded
                          : Icons.cell_tower_rounded,
                  size: 18,
                ),
                label: Text(
                  controller.isSpeaking
                      ? "✋ INTERRUPT AI"
                      : controller.isLiveSession
                          ? "END AVIS CALL"
                          : "START AVIS",
                  style: GoogleFonts.orbitron(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  if (controller.isSpeaking) {
                    controller.interruptAi();
                  } else {
                    controller.toggleLiveSession();
                  }
                },
              ),

              // 3. Sci-Fi Persona Switch Button with Confirmation
              IconButton(
                icon: Icon(
                  isAvis ? Icons.favorite_border_rounded : Icons.smart_toy_outlined,
                  color: isAvis ? AppTheme.neonMagenta : AppTheme.neonCyan,
                  size: 22,
                ),
                tooltip: isAvis ? "Switch to Biba" : "Switch to Avis",
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onConfirmPersonaSwitch();
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),
      ],
    );
  }
}
