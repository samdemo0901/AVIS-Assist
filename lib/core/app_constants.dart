import 'package:flutter/services.dart';

/// ============================================================
/// AVIS Mobile — Centralized App Constants
/// Single source of truth for version info and channel strings.
/// ============================================================

/// App version constants — always in sync with pubspec.yaml
class AppVersion {
  static const String current = '3.32.0';
  static const String displayName = 'AVIS Mobile v$current';
  static const String companionVersion = 'Windows Companion v2.6.0';
  static const String fullEcosystem = 'AVIS Mobile v$current + $companionVersion';
}

/// Built-In Master Google Cloud Services Configuration
/// Powers YouTube Data API v3 and Google Custom Search API.
/// Secured: Provided via compile-time env or user configuration in settings.
class GoogleServicesConfig {
  GoogleServicesConfig._();

  static const String masterApiKey =
      String.fromEnvironment('GOOGLE_SERVICES_API_KEY', defaultValue: '');
  static const String defaultCustomSearchCx = '017543674320973680327:hh180ebv_i4'; // Default Web Search Engine CX
}

/// Centralized MethodChannel & EventChannel definitions.
/// Use these everywhere instead of raw string literals.
class AppChannels {
  AppChannels._(); // Prevent instantiation

  // ── MethodChannels ──────────────────────────────────────────
  static const MethodChannel audio =
      MethodChannel('com.example.avis_mobile/audio');

  static const MethodChannel automation =
      MethodChannel('com.example.avis_mobile/automation');

  static const MethodChannel permissions =
      MethodChannel('com.example.avis_mobile/permissions');

  // ── EventChannels ───────────────────────────────────────────
  static const EventChannel audioStream =
      EventChannel('com.example.avis_mobile/audio_stream');

  static const EventChannel screenStream =
      EventChannel('com.example.avis_mobile/screen_stream');
}
