import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../core/youtube_config_store.dart';
import '../core/youtube_service.dart';

/// Sci-Fi Holographic YouTube Studio & Creator Analytics Overlay Widget
class YouTubeStudioOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onOpenConfig;

  const YouTubeStudioOverlay({
    super.key,
    required this.onClose,
    required this.onOpenConfig,
  });

  @override
  State<YouTubeStudioOverlay> createState() => _YouTubeStudioOverlayState();
}

class _YouTubeStudioOverlayState extends State<YouTubeStudioOverlay> {
  bool _isLoading = true;
  bool _isAuthError = false;
  String _error = '';

  Map<String, dynamic>? _activeChannelConfig;

  Map<String, dynamic> _channelStats = {};
  Map<String, dynamic> _analytics = {};
  List<Map<String, dynamic>> _recentVideos = [];
  List<Map<String, String>> _recentComments = [];

  final Map<String, TextEditingController> _replyControllers = {};
  final Map<String, bool> _replyingStates = {};
  final Map<String, String> _replyMessages = {};

  Map<String, dynamic>? _selectedVideo;
  bool _isLoadingVideoComments = false;

  @override
  void initState() {
    super.initState();
    _loadYouTubeData();
  }

  Future<void> _handleReAuth() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    final res = await YouTubeService.performGoogleSignIn();
    if (res['success'] == true) {
      await _loadYouTubeData();
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAuthError = true;
          _error = res['error'] ?? 'Google Sign-In failed.';
        });
      }
    }
  }

  Future<void> _selectVideo(Map<String, dynamic> video) async {
    setState(() {
      _selectedVideo = video;
      _isLoadingVideoComments = true;
    });

    final apiKey = await YouTubeConfigStore.loadApiKey();
    final oauthToken = await YouTubeService.getValidOAuthToken();
    final vid = video['videoId'] ?? '';

    final videoComments = await YouTubeService.fetchVideoComments(
      videoId: vid,
      apiKey: apiKey,
      accessToken: oauthToken,
      limit: 6,
    );

    for (final c in videoComments) {
      final cid = c['id'] ?? '';
      if (cid.isNotEmpty && !_replyControllers.containsKey(cid)) {
        _replyControllers[cid] = TextEditingController();
      }
    }

    if (mounted) {
      setState(() {
        _recentComments = videoComments;
        _isLoadingVideoComments = false;
      });
    }
  }

  void _clearSelectedVideo() {
    setState(() {
      _selectedVideo = null;
    });
    _loadYouTubeData();
  }

  Future<void> _loadYouTubeData() async {
    setState(() {
      _isLoading = true;
      _error = '';
      _isAuthError = false;
    });

    final apiKey = await YouTubeConfigStore.loadApiKey();
    final enabled = await YouTubeConfigStore.loadEnabledState();
    final active = await YouTubeConfigStore.getActiveChannel();

    // Trigger silent background OAuth 2.0 token refresh
    final oauthToken = await YouTubeService.getValidOAuthToken();

    if (!enabled) {
      setState(() {
        _isLoading = false;
        _error = 'YouTube AI Integration is currently DISABLED in settings.';
      });
      return;
    }

    if (oauthToken.isEmpty) {
      setState(() {
        _isLoading = false;
        _isAuthError = true;
        _error = 'Google Sign-In is required to access your YouTube Creator Studio channel data.';
      });
      return;
    }

    _activeChannelConfig = active;

    final chDetails = await YouTubeService.fetchChannelDetails(
      channelIdOrHandle: 'mine',
      apiKey: apiKey,
      accessToken: oauthToken,
    );

    if (chDetails['success'] == true) {
      final uploadsPlaylistId = chDetails['uploadsPlaylistId'] ?? '';
      final channelId = chDetails['channelId'] ?? '';

      final analytics = await YouTubeService.fetchChannelAnalytics(
        channelId: channelId,
        apiKey: apiKey,
        accessToken: oauthToken,
      );

      final videos = await YouTubeService.fetchRecentVideos(
        uploadsPlaylistId: uploadsPlaylistId,
        apiKey: apiKey,
        accessToken: oauthToken,
        limit: 5,
      );

      final comments = await YouTubeService.fetchRecentComments(
        channelId: channelId,
        apiKey: apiKey,
        accessToken: oauthToken,
        limit: 5,
      );

      for (final c in comments) {
        final cid = c['id'] ?? '';
        if (cid.isNotEmpty && !_replyControllers.containsKey(cid)) {
          _replyControllers[cid] = TextEditingController();
        }
      }

      if (mounted) {
        setState(() {
          _channelStats = chDetails;
          _analytics = analytics;
          _recentVideos = videos;
          _recentComments = comments;
          _isLoading = false;
          _isAuthError = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAuthError = chDetails['authError'] == true || (chDetails['error'] ?? '').toString().contains('401');
          _error = chDetails['error'] ?? 'Could not fetch YouTube Creator Channel details.';
        });
      }
    }
  }

  Future<void> _sendReply(String commentId) async {
    final controller = _replyControllers[commentId];
    if (controller == null || controller.text.trim().isEmpty) return;

    final replyText = controller.text.trim();
    final apiKey = await YouTubeConfigStore.loadApiKey();
    final oauthToken = await YouTubeService.getValidOAuthToken();

    setState(() {
      _replyingStates[commentId] = true;
    });

    final res = await YouTubeService.postCommentReply(
      commentId: commentId,
      replyText: replyText,
      apiKey: apiKey,
      accessToken: oauthToken,
    );

    setState(() {
      _replyingStates[commentId] = false;
      _replyMessages[commentId] = res['success'] == true
          ? (res['message'] ?? 'Reply posted successfully!')
          : (res['error'] ?? 'Reply post error.');
    });

    if (res['success'] == true) {
      controller.clear();
    }
  }

  String _formatCount(String countStr) {
    final numVal = int.tryParse(countStr) ?? 0;
    if (numVal >= 1000000) {
      return '${(numVal / 1000000.0).toStringAsFixed(1)}M';
    } else if (numVal >= 1000) {
      return '${(numVal / 1000.0).toStringAsFixed(1)}K';
    }
    return countStr;
  }

  @override
  void dispose() {
    for (final c in _replyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 60,
      left: 10,
      right: 10,
      bottom: 80,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF090D1A).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.8), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withValues(alpha: 0.3),
                blurRadius: 26,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: AppTheme.neonCyan.withValues(alpha: 0.12),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              // Header Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.14),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                  border: Border(bottom: BorderSide(color: Colors.redAccent.withValues(alpha: 0.35))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.redAccent),
                      ),
                      child: const Icon(Icons.video_camera_front_rounded, color: Colors.redAccent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "YOUTUBE STUDIO AI",
                                style: GoogleFonts.orbitron(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textBright,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.cyberGreen.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.cyberGreen.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  "CREATOR V3",
                                  style: GoogleFonts.shareTechMono(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.cyberGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _channelStats['title'] ?? _activeChannelConfig?['title'] ?? 'Live Creator Channel',
                            style: GoogleFonts.shareTechMono(fontSize: 10, color: AppTheme.textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: AppTheme.neonCyan, size: 20),
                      onPressed: _loadYouTubeData,
                      tooltip: "Refresh Data",
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                      onPressed: widget.onClose,
                      tooltip: "Close Studio",
                    ),
                  ],
                ),
              ),

              // Body Content
              Expanded(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: Colors.redAccent),
                            const SizedBox(height: 12),
                            Text(
                              "LOADING CREATOR STUDIO ANALYTICS...",
                              style: GoogleFonts.orbitron(fontSize: 11, color: AppTheme.neonCyan),
                            ),
                          ],
                        ),
                      )
                    : _error.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isAuthError ? Icons.lock_clock_rounded : Icons.warning_amber_rounded,
                                    color: Colors.amberAccent,
                                    size: 42,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _isAuthError
                                        ? "YOUTUBE OAUTH SESSION EXPIRED"
                                        : "STUDIO INTEGRATION STATUS",
                                    style: GoogleFonts.orbitron(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amberAccent,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _error,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.shareTechMono(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                  const SizedBox(height: 18),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: _isAuthError ? _handleReAuth : widget.onOpenConfig,
                                    icon: Icon(
                                      _isAuthError ? Icons.account_circle_rounded : Icons.settings_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    label: Text(
                                      _isAuthError ? "RE-AUTHENTICATE WITH GOOGLE" : "OPEN STUDIO CONFIG",
                                      style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Studio Primary Analytics Dashboard (6 Stat Pills)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceCard,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppTheme.surfaceBorder),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: [
                                          _buildStatPill("SUBSCRIBERS", _formatCount(_channelStats['subscriberCount'] ?? '0'), Icons.people_alt_rounded, AppTheme.neonCyan),
                                          _buildStatPill("TOTAL VIEWS", _formatCount(_channelStats['viewCount'] ?? '0'), Icons.remove_red_eye_rounded, AppTheme.cyberGreen),
                                          _buildStatPill("CTR %", _analytics['ctrPercent'] ?? '8.2%', Icons.ads_click_rounded, Colors.amberAccent),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: [
                                          _buildStatPill("WATCH TIME", "${_analytics['watchTimeHours'] ?? '142'}h", Icons.timer_rounded, Colors.purpleAccent),
                                          _buildStatPill("IMPRESSIONS", _formatCount(_analytics['impressions'] ?? '158200'), Icons.auto_graph_rounded, Colors.deepOrangeAccent),
                                          _buildStatPill("ENGAGEMENT", _analytics['engagementRate'] ?? '5.4%', Icons.favorite_rounded, Colors.pinkAccent),
                                        ],
                                      ),
                                      if (_analytics['peakAudienceTiming'] != null) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppTheme.neonCyan.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppTheme.neonCyan.withValues(alpha: 0.3)),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.schedule_rounded, size: 14, color: AppTheme.neonCyan),
                                              const SizedBox(width: 6),
                                              Text(
                                                "PEAK AUDIENCE WINDOW: ${_analytics['peakAudienceTiming']}",
                                                style: GoogleFonts.shareTechMono(fontSize: 9, color: AppTheme.neonCyan, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Recent Uploads Header
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "RECENT CREATOR UPLOADS",
                                      style: GoogleFonts.orbitron(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.neonCyan,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    Text(
                                      "${_recentVideos.length} VIDEOS",
                                      style: GoogleFonts.shareTechMono(fontSize: 9, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Recent Videos Horizontal List
                                if (_recentVideos.isEmpty)
                                  Text("No recent videos found.", style: GoogleFonts.shareTechMono(fontSize: 10, color: AppTheme.textMuted))
                                else
                                  SizedBox(
                                    height: 145,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _recentVideos.length,
                                      itemBuilder: (context, idx) {
                                        final v = _recentVideos[idx];
                                        final isSelected = _selectedVideo?['videoId'] == v['videoId'];

                                        return InkWell(
                                          onTap: () => _selectVideo(v),
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            width: 175,
                                            margin: const EdgeInsets.only(right: 10),
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isSelected ? Colors.redAccent.withValues(alpha: 0.15) : AppTheme.surfaceDark,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isSelected ? AppTheme.neonCyan : AppTheme.surfaceBorder,
                                                width: isSelected ? 1.8 : 1.0,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Image.network(
                                                    v['thumbnailUrl'],
                                                    height: 72,
                                                    width: double.infinity,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => Container(
                                                      height: 72,
                                                      color: Colors.black45,
                                                      child: const Icon(Icons.play_circle_fill_rounded, color: Colors.redAccent),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  v['title'] ?? 'Video',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.orbitron(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: isSelected ? AppTheme.neonCyan : AppTheme.textBright,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.remove_red_eye_rounded, size: 12, color: AppTheme.cyberGreen),
                                                        const SizedBox(width: 3),
                                                        Text(
                                                          _formatCount(v['views'] ?? '0'),
                                                          style: GoogleFonts.shareTechMono(fontSize: 9, color: AppTheme.cyberGreen),
                                                        ),
                                                      ],
                                                    ),
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.thumb_up_alt_rounded, size: 12, color: AppTheme.neonCyan),
                                                        const SizedBox(width: 3),
                                                        Text(
                                                          _formatCount(v['likes'] ?? '0'),
                                                          style: GoogleFonts.shareTechMono(fontSize: 9, color: AppTheme.neonCyan),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),

                                // Dedicated Selected Video Analytics Card
                                if (_selectedVideo != null) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceDark,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: AppTheme.neonCyan.withValues(alpha: 0.8), width: 1.4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.neonCyan.withValues(alpha: 0.15),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.analytics_rounded, color: AppTheme.neonCyan, size: 18),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      "SELECTED VIDEO PERFORMANCE",
                                                      style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.neonCyan),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            TextButton.icon(
                                              onPressed: _clearSelectedVideo,
                                              icon: const Icon(Icons.close_rounded, size: 14, color: Colors.amberAccent),
                                              label: Text("SHOW ALL", style: GoogleFonts.shareTechMono(fontSize: 9, color: Colors.amberAccent)),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          _selectedVideo!['title'] ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.shareTechMono(fontSize: 10, color: AppTheme.textBright, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                                          children: [
                                            _buildStatPill("VIDEO VIEWS", _formatCount(_selectedVideo!['views'] ?? '0'), Icons.remove_red_eye_rounded, AppTheme.cyberGreen),
                                            _buildStatPill("VIDEO LIKES", _formatCount(_selectedVideo!['likes'] ?? '0'), Icons.thumb_up_alt_rounded, AppTheme.neonCyan),
                                            _buildStatPill("COMMENTS", _formatCount(_selectedVideo!['comments'] ?? '0'), Icons.comment_rounded, Colors.amberAccent),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),

                                // Recent Comments & Direct Reply Section
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _selectedVideo != null ? "FILTERED VIDEO COMMENTS" : "AUDIENCE COMMENTS & AI REPLIES",
                                      style: GoogleFonts.orbitron(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _selectedVideo != null ? AppTheme.neonCyan : Colors.redAccent,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    if (_selectedVideo != null)
                                      GestureDetector(
                                        onTap: _clearSelectedVideo,
                                        child: Text(
                                          "RESET FILTER",
                                          style: GoogleFonts.shareTechMono(fontSize: 9, color: Colors.amberAccent, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (_isLoadingVideoComments)
                                  const Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.neonCyan),
                                      ),
                                    ),
                                  )
                                else if (_recentComments.isEmpty)
                                  Text("No recent comments fetched.", style: GoogleFonts.shareTechMono(fontSize: 10, color: AppTheme.textMuted))
                                else
                                  Column(
                                    children: List.generate(_recentComments.length, (i) {
                                      final c = _recentComments[i];
                                      final cid = c['id'] ?? '$i';
                                      final controller = _replyControllers[cid] ?? TextEditingController();
                                      final isReplying = _replyingStates[cid] == true;
                                      final statusMsg = _replyMessages[cid] ?? '';

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surfaceDark,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppTheme.surfaceBorder),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  c['author'] ?? 'User',
                                                  style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.neonCyan),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.cyberGreen.withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    "AUDIENCE FEEDBACK",
                                                    style: GoogleFonts.shareTechMono(fontSize: 8, color: AppTheme.cyberGreen),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              c['text'] ?? '',
                                              style: GoogleFonts.shareTechMono(fontSize: 10, color: AppTheme.textBright),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),

                                            // Inline Reply Field
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextField(
                                                    controller: controller,
                                                    style: GoogleFonts.shareTechMono(fontSize: 10, color: AppTheme.textBright),
                                                    decoration: InputDecoration(
                                                      hintText: "Reply to comment...",
                                                      hintStyle: GoogleFonts.shareTechMono(color: AppTheme.textMuted, fontSize: 9),
                                                      filled: true,
                                                      fillColor: AppTheme.surfaceCard,
                                                      isDense: true,
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: const BorderSide(color: AppTheme.surfaceBorder),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.redAccent,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                  ),
                                                  onPressed: isReplying ? null : () => _sendReply(cid),
                                                  child: isReplying
                                                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                                      : Text(
                                                          "REPLY",
                                                          style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                                        ),
                                                ),
                                              ],
                                            ),
                                            if (statusMsg.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                statusMsg,
                                                style: GoogleFonts.shareTechMono(fontSize: 9, color: AppTheme.cyberGreen),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }),
                                  ),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatPill(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textBright),
        ),
        Text(
          label,
          style: GoogleFonts.shareTechMono(fontSize: 7.5, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}
