import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../core/youtube_config_store.dart';
import '../core/youtube_service.dart';

/// Futuristic YouTube Creator Studio & AI Integration Dialog
class YouTubeConfigDialog extends StatefulWidget {
  final VoidCallback? onConfigUpdated;

  const YouTubeConfigDialog({super.key, this.onConfigUpdated});

  @override
  State<YouTubeConfigDialog> createState() => _YouTubeConfigDialogState();
}

class _YouTubeConfigDialogState extends State<YouTubeConfigDialog> {
  final TextEditingController _apiKeyController = TextEditingController();

  bool _isEnabled = true;
  bool _isLoading = false;
  String _statusMessage = '';
  Color _statusColor = AppTheme.neonCyan;

  String _oauthToken = '';
  String _oauthEmail = '';
  String _oauthChannelTitle = '';
  String _oauthAvatarUrl = '';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final apiKey = await YouTubeConfigStore.loadApiKey();
    final enabled = await YouTubeConfigStore.loadEnabledState();
    final token = await YouTubeService.getValidOAuthToken();
    final email = await YouTubeConfigStore.loadOAuthEmail();
    final title = await YouTubeConfigStore.loadOAuthChannelTitle();
    final avatar = await YouTubeConfigStore.loadOAuthAvatarUrl();

    setState(() {
      _apiKeyController.text = apiKey;
      _isEnabled = enabled;
      _oauthToken = token;
      _oauthEmail = email;
      _oauthChannelTitle = title;
      _oauthAvatarUrl = avatar;
    });
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Initiating Google Sign-In with YouTube OAuth 2.0 scopes...";
      _statusColor = AppTheme.neonCyan;
    });

    final res = await YouTubeService.performGoogleSignIn();

    setState(() {
      _isLoading = false;
    });

    if (res['success'] == true) {
      await _loadConfig();
      _showStatus("✅ Successfully signed in as '${res['channelTitle']}'!", AppTheme.cyberGreen);
      widget.onConfigUpdated?.call();
    } else {
      _showStatus("❌ ${res['error']}", Colors.redAccent);
    }
  }

  Future<void> _handleGoogleSignOut() async {
    await YouTubeService.performGoogleSignOut();
    await _loadConfig();
    _showStatus("Signed out of Google Account.", AppTheme.textMuted);
    widget.onConfigUpdated?.call();
  }

  Future<void> _saveConfig() async {
    await YouTubeConfigStore.saveApiKey(_apiKeyController.text);
    await YouTubeConfigStore.saveEnabledState(_isEnabled);
    widget.onConfigUpdated?.call();
  }

  void _showStatus(String msg, Color color) {
    setState(() {
      _statusMessage = msg;
      _statusColor = color;
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1424).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.redAccent.withValues(alpha: 0.25),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.video_library_rounded, color: Colors.redAccent, size: 26),
                      const SizedBox(width: 10),
                      Text(
                        "YOUTUBE STUDIO AI",
                        style: GoogleFonts.orbitron(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textBright,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Master Toggle Switch
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isEnabled ? Icons.power_rounded : Icons.power_off_rounded,
                          color: _isEnabled ? AppTheme.cyberGreen : AppTheme.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "YOUTUBE STUDIO AI BRAIN",
                              style: GoogleFonts.orbitron(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textBright,
                              ),
                            ),
                            Text(
                              _isEnabled ? "Status: ENABLED & ACTIVE" : "Status: DISABLED",
                              style: GoogleFonts.shareTechMono(
                                fontSize: 9,
                                color: _isEnabled ? AppTheme.cyberGreen : AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: _isEnabled,
                      activeTrackColor: Colors.redAccent,
                      onChanged: (val) {
                        setState(() => _isEnabled = val);
                        _saveConfig();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // OAuth 2.0 Google Sign-In Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _oauthToken.isNotEmpty
                        ? AppTheme.cyberGreen.withValues(alpha: 0.6)
                        : AppTheme.neonCyan.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "YOUTUBE CREATOR ACCOUNT",
                          style: GoogleFonts.orbitron(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.neonCyan,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (_oauthToken.isNotEmpty ? AppTheme.cyberGreen : AppTheme.alertAmber).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _oauthToken.isNotEmpty ? AppTheme.cyberGreen : AppTheme.alertAmber),
                          ),
                          child: Text(
                            _oauthToken.isNotEmpty ? "AUTHENTICATED (OAUTH 2.0)" : "NOT AUTHORIZED",
                            style: GoogleFonts.shareTechMono(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: _oauthToken.isNotEmpty ? AppTheme.cyberGreen : AppTheme.alertAmber,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_oauthToken.isNotEmpty)
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.redAccent,
                            backgroundImage: _oauthAvatarUrl.isNotEmpty ? NetworkImage(_oauthAvatarUrl) : null,
                            child: _oauthAvatarUrl.isEmpty ? const Icon(Icons.account_circle, color: Colors.white) : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _oauthChannelTitle.isNotEmpty ? _oauthChannelTitle : "YouTube Creator Channel",
                                  style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textBright),
                                ),
                                Text(
                                  _oauthEmail,
                                  style: GoogleFonts.shareTechMono(fontSize: 9, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            onPressed: _handleGoogleSignOut,
                            child: Text("SIGN OUT", style: GoogleFonts.orbitron(fontSize: 9, color: Colors.redAccent)),
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Connect your Google Account to authorize AVIS/BIBA to analyze your live YouTube Creator Studio analytics & audience comments.",
                            style: GoogleFonts.shareTechMono(fontSize: 10, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _isLoading ? null : _handleGoogleSignIn,
                              icon: const Icon(Icons.g_mobiledata_rounded, size: 24),
                              label: Text(
                                "LOGIN WITH GOOGLE (OAUTH 2.0)",
                                style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // API Key Field
              Text(
                "GOOGLE CLOUD CONSOLE API KEY (OPTIONAL)",
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.neonCyan,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _apiKeyController,
                      obscureText: true,
                      style: GoogleFonts.shareTechMono(fontSize: 12, color: AppTheme.textBright),
                      decoration: InputDecoration(
                        hintText: "AIzaSy...",
                        hintStyle: GoogleFonts.shareTechMono(color: AppTheme.textMuted),
                        filled: true,
                        fillColor: AppTheme.surfaceCard,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.surfaceBorder),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: () async {
                      await _saveConfig();
                      _showStatus("API Key Saved!", AppTheme.cyberGreen);
                    },
                    child: Text(
                      "SAVE",
                      style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Status Message
              if (_statusMessage.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _statusMessage,
                    style: GoogleFonts.shareTechMono(fontSize: 10, color: _statusColor),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
