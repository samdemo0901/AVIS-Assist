import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../core/avis_session_controller.dart';

/// Settings Tab: Core AI Settings, Hardware Diagnostics, API Key Matrix, APCS Permissions.
class SettingsTab extends StatelessWidget {
  final AvisSessionController controller;
  final VoidCallback onShowSandboxOverlay;
  final VoidCallback onShowApiKeyDialog;
  final ScrollController logScrollController;

  const SettingsTab({
    super.key,
    required this.controller,
    required this.onShowSandboxOverlay,
    required this.onShowApiKeyDialog,
    required this.logScrollController,
  });

  @override
  Widget build(BuildContext context) {
    final logs = controller.logs;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "CORE AI & SYSTEM SETTINGS",
            style: GoogleFonts.orbitron(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.neonCyan,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          // CARD 1: Gemini Live API Keys & Hot-Switch Matrix
          _buildApiKeyMatrixCard(context),
          const SizedBox(height: 16),

          // CARD 2: Hardware Microphone & Speaker Diagnostics
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glassCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "AUDIO HARDWARE & VU METER",
                      style: GoogleFonts.orbitron(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textBright,
                      ),
                    ),
                    Text(
                      "${(controller.liveAudioLevel * 100).clamp(0, 100).toInt()}%",
                      style: GoogleFonts.shareTechMono(
                        fontSize: 12,
                        color: controller.liveAudioLevel > 0.05 ? AppTheme.cyberGreen : AppTheme.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: controller.liveAudioLevel.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      controller.liveAudioLevel > 0.6 ? AppTheme.neonMagenta : AppTheme.cyberGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.cyberGreen,
                          side: const BorderSide(color: AppTheme.cyberGreen),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.mic, size: 16),
                        label: const Text("TEST MIC", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: controller.testHardwareMic,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.neonCyan,
                          side: const BorderSide(color: AppTheme.neonCyan),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.volume_up, size: 16),
                        label: const Text("TEST SPEAKER", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: controller.testSpeakerChime,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          _buildConfigTile(
            title: "MODEL ARCHITECTURE",
            subtitle: "Gemini 3.1 Flash Live Preview (Bidi WebSocket)",
            trailingText: "LIVE v1beta",
            trailingColor: AppTheme.cyberGreen,
          ),
          _buildConfigTile(
            title: "AUDIO SPECS",
            subtitle: "16kHz Mono PCM In | 24kHz Loudspeaker Out",
            trailingText: "DIRECT S2S",
            trailingColor: AppTheme.cyberGreen,
          ),
          _buildConfigTile(
            title: "ACTIVE PERSONA",
            subtitle: controller.activePersona == "AVIS"
                ? "Avis (Male Tech Voice: Puck)"
                : "Biba (Female Companion: Laomedeia)",
            trailingText: controller.activePersona,
            trailingColor: controller.activePersona == "AVIS" ? AppTheme.neonCyan : AppTheme.neonMagenta,
          ),

          const SizedBox(height: 20),

          // Live Diagnostic Terminal Logs Viewer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "LIVE EVENT TELEMETRY (TERMINAL)",
                style: GoogleFonts.orbitron(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.neonCyan,
                  letterSpacing: 1.2,
                ),
              ),
              GestureDetector(
                onTap: controller.clearLogs,
                child: Text(
                  "CLEAR",
                  style: GoogleFonts.shareTechMono(
                    fontSize: 10,
                    color: AppTheme.alertAmber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Container(
            height: 160,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: ListView.builder(
              controller: logScrollController,
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final line = logs[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    line,
                    style: GoogleFonts.shareTechMono(
                      color: line.contains("❌")
                          ? Colors.redAccent
                          : line.contains("✅")
                              ? AppTheme.cyberGreen
                              : line.contains("🔑")
                                  ? AppTheme.neonCyan
                                  : AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          _buildSandboxWorkspaceCard(),
          const SizedBox(height: 20),

          // CARD 4: APCS Device Control & System Access Card
          _buildApcsCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSandboxWorkspaceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration(borderColor: AppTheme.neonCyan),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_special_rounded, color: AppTheme.neonCyan, size: 20),
              const SizedBox(width: 10),
              Text(
                "SANDBOX WORKSPACE EXPLORER",
                style: GoogleFonts.orbitron(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.neonCyan,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Access, inspect, and manage files created in your isolated mobile sandbox workspace:",
            style: GoogleFonts.shareTechMono(color: AppTheme.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.neonCyan.withValues(alpha: 0.2),
                foregroundColor: AppTheme.neonCyan,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppTheme.neonCyan),
                ),
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text("OPEN SANDBOX EXPLORER", style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: onShowSandboxOverlay,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeyMatrixCard(BuildContext context) {
    final apiKeys = controller.apiKeys;
    final activeIndex = controller.activeApiKeyIndex;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.key_rounded, color: AppTheme.neonCyan, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    "GEMINI API KEYS MATRIX",
                    style: GoogleFonts.orbitron(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textBright,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: controller.keyVerificationColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: controller.keyVerificationColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  controller.keyVerificationStatus,
                  style: GoogleFonts.shareTechMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: controller.keyVerificationColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Multi-key storage & instant hot-switching matrix:",
            style: GoogleFonts.shareTechMono(fontSize: 11, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 10),

          if (apiKeys.isEmpty)
            Text("No API Keys configured. Tap + Add Key below.", style: GoogleFonts.shareTechMono(color: Colors.white30, fontSize: 11))
          else
            Column(
              children: List.generate(apiKeys.length, (idx) {
                final keyStr = apiKeys[idx];
                final isActive = idx == activeIndex;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.neonCyan.withValues(alpha: 0.15) : AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isActive ? AppTheme.neonCyan : Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: isActive ? AppTheme.neonCyan : Colors.white30,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Key #${idx + 1}: ${keyStr.length > 10 ? keyStr.substring(0, 10) : keyStr}••••••••",
                          style: GoogleFonts.shareTechMono(
                            fontSize: 11,
                            color: isActive ? AppTheme.neonCyan : Colors.white70,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.neonCyan,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "ACTIVE",
                            style: GoogleFonts.orbitron(fontSize: 9, color: Colors.black, fontWeight: FontWeight.bold),
                          ),
                        )
                      else
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => controller.selectApiKey(idx),
                          child: Text("SWITCH", style: GoogleFonts.orbitron(fontSize: 10, color: AppTheme.neonCyan)),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.white30, size: 16),
                        onPressed: () => controller.removeApiKey(idx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              }),
            ),

          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.neonCyan.withValues(alpha: 0.15),
                    foregroundColor: AppTheme.neonCyan,
                    side: const BorderSide(color: AppTheme.neonCyan),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.bolt, size: 16),
                  label: const Text("VERIFY ACTIVE KEY", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: controller.testApiKey,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white10,
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.add, size: 14),
                label: const Text("ADD KEY", style: TextStyle(fontSize: 11)),
                onPressed: onShowApiKeyDialog,
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

  Widget _buildApcsCard() {
    final permissions = controller.systemPermissions;
    final hasAudio = permissions["audio"] == true;
    final hasCamera = permissions["camera"] == true;
    final hasSms = permissions["sms"] == true;
    final hasNotif = permissions["notificationListener"] == true;
    final hasAccess = permissions["accessibility"] == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.neonCyan.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.neonCyan.withValues(alpha: 0.08),
            blurRadius: 16,
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
                  const Icon(Icons.phonelink_setup, size: 18, color: AppTheme.neonCyan),
                  const SizedBox(width: 8),
                  Text(
                    "PHONE CONTROL & PERMISSIONS",
                    style: GoogleFonts.orbitron(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textBright,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: controller.refreshSystemPermissions,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.refresh, size: 12, color: AppTheme.neonCyan),
                      const SizedBox(width: 4),
                      Text(
                        "REFRESH",
                        style: GoogleFonts.shareTechMono(
                          fontSize: 10,
                          color: AppTheme.neonCyan,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Grant system permissions so AVIS can control device hardware & read messages via voice.",
            style: GoogleFonts.shareTechMono(
              fontSize: 10.5,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 14),

          _buildPermissionRow(
            icon: Icons.mic,
            title: "Microphone Stream",
            description: "Direct 16kHz speech input",
            isGranted: hasAudio,
            buttonText: "GRANT",
            onAction: () => controller.requestRuntimePermission("audio"),
          ),
          const Divider(color: Colors.white10, height: 16),
          _buildPermissionRow(
            icon: Icons.flash_on,
            title: "Flashlight / Camera",
            description: "0ms hardware torch control",
            isGranted: hasCamera,
            buttonText: "GRANT",
            onAction: () => controller.requestRuntimePermission("camera"),
          ),
          const Divider(color: Colors.white10, height: 16),
          _buildPermissionRow(
            icon: Icons.sms,
            title: "SMS Inbox Query",
            description: "Read bank OTPs & text messages",
            isGranted: hasSms,
            buttonText: "GRANT",
            onAction: () => controller.requestRuntimePermission("sms"),
          ),
          const Divider(color: Colors.white10, height: 16),
          _buildPermissionRow(
            icon: Icons.notifications_active,
            title: "Notification Listener",
            description: "Read WhatsApp, Gmail & app alerts",
            isGranted: hasNotif,
            buttonText: "ACCESS",
            onAction: () => controller.openSystemSetting("notification_listener"),
          ),
          const Divider(color: Colors.white10, height: 16),
          _buildPermissionRow(
            icon: Icons.touch_app,
            title: "Screen Assistant",
            description: "Hands-free taps, scrolls & home/back",
            isGranted: hasAccess,
            buttonText: "SETTINGS",
            onAction: () => controller.openSystemSetting("accessibility"),
          ),

          const SizedBox(height: 16),
          Text(
            "QUICK DEVICE HOOKS",
            style: GoogleFonts.orbitron(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.textBright,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.alertAmber,
                    side: const BorderSide(color: AppTheme.alertAmber),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.highlight, size: 14),
                  label: const Text("TOGGLE TORCH", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  onPressed: controller.toggleFlashlightDirect,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.neonBlue,
                    side: const BorderSide(color: AppTheme.neonBlue),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.wifi, size: 14),
                  label: const Text("WI-FI PANEL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  onPressed: controller.openWifiSettingsDirect,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.play_circle_fill, size: 14),
                  label: const Text("LAUNCH YOUTUBE", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                  onPressed: () => controller.launchAppDirect("youtube"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.neonCyan,
                    side: const BorderSide(color: AppTheme.neonCyan),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.keyboard, size: 14),
                  label: const Text("TEST TYPOGRAPHY", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                  onPressed: controller.testTypographyDirect,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRow({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required String buttonText,
    required VoidCallback onAction,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isGranted
                ? AppTheme.cyberGreen.withValues(alpha: 0.15)
                : AppTheme.alertAmber.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 16,
            color: isGranted ? AppTheme.cyberGreen : AppTheme.alertAmber,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.orbitron(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textBright,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isGranted
                          ? AppTheme.cyberGreen.withValues(alpha: 0.2)
                          : AppTheme.alertAmber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isGranted ? "ACTIVE" : "OFF",
                      style: GoogleFonts.shareTechMono(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: isGranted ? AppTheme.cyberGreen : AppTheme.alertAmber,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.shareTechMono(
                  fontSize: 9.5,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (!isGranted)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.neonCyan.withValues(alpha: 0.2),
              foregroundColor: AppTheme.neonCyan,
              side: const BorderSide(color: AppTheme.neonCyan, width: 0.8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(60, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: onAction,
            child: Text(
              buttonText,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
            ),
          )
        else
          const Icon(Icons.check_circle, size: 18, color: AppTheme.cyberGreen),
      ],
    );
  }
}
