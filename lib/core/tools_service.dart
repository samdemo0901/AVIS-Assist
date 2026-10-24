import 'dart:convert';
import 'dart:io';

import 'app_constants.dart';
import 'youtube_config_store.dart';

/// Modular tools service providing real-time Web Search and Weather data
/// for AVIS & BIBA multimodal voice brain.
class ToolsService {
  static final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 7)
    ..idleTimeout = const Duration(seconds: 5);

  /// Performs real-time web search exclusively using official Google Custom Search API.
  static Future<String> searchWeb(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return "Error: Search query cannot be empty.";
    }

    try {
      final customApiKey = await YouTubeConfigStore.loadApiKey();
      final apiKey = customApiKey.isNotEmpty ? customApiKey : GoogleServicesConfig.masterApiKey;
      if (apiKey.isEmpty) {
        return "Web search requires a Google Cloud Search API key. Please configure it in Settings > YouTube & Cloud Services.";
      }
      const cx = GoogleServicesConfig.defaultCustomSearchCx;
      final gSearchUri = Uri.parse(
        "https://www.googleapis.com/customsearch/v1?q=${Uri.encodeComponent(cleanQuery)}&key=$apiKey&cx=$cx&num=3",
      );
      final request = await _httpClient.getUrl(gSearchUri);
      final response = await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final items = json['items'] as List? ?? [];
        if (items.isNotEmpty) {
          final buffer = StringBuffer();
          buffer.writeln("Google Search for '$cleanQuery':");
          int count = 0;
          for (var item in items) {
            if (item is Map<String, dynamic>) {
              final title = item['title']?.toString() ?? "";
              var snippet = item['snippet']?.toString() ?? "";
              // Clean HTML tags and newlines for crisp voice synthesis
              snippet = snippet.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('\n', ' ').trim();
              if (title.isNotEmpty && snippet.isNotEmpty) {
                buffer.writeln("• $title: $snippet");
                count++;
                if (count >= 3) break;
              }
            }
          }
          final res = buffer.toString().trim();
          return res.length > 350 ? "${res.substring(0, 350)}..." : res;
        }
      }
    } catch (e) {
      return "Google Search temporarily unavailable ($e).";
    }

    return "No direct Google Search results found for '$cleanQuery'.";
  }

  /// Fetches real-time weather, temperature, humidity, wind, and conditions for any city
  static Future<String> fetchWeather(String location) async {
    final cleanLoc = location.trim();
    if (cleanLoc.isEmpty) {
      return "Error: Location cannot be empty for weather lookup.";
    }

    try {
      final uri = Uri.parse("https://wttr.in/${Uri.encodeComponent(cleanLoc)}?format=j1");
      final request = await _httpClient.getUrl(uri);
      request.headers.set('User-Agent', 'AVIS-Mobile-AI/3.11.0');
      final response = await request.close().timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;

        final current = (json['current_condition'] as List?)?.firstOrNull as Map<String, dynamic>?;
        final nearest = (json['nearest_area'] as List?)?.firstOrNull as Map<String, dynamic>?;
        final forecast = (json['weather'] as List?)?.firstOrNull as Map<String, dynamic>?;

        final areaName = ((nearest?['areaName'] as List?)?.firstOrNull as Map<String, dynamic>?)?['value'] ?? cleanLoc;
        final region = ((nearest?['region'] as List?)?.firstOrNull as Map<String, dynamic>?)?['value'] ?? "";
        final country = ((nearest?['country'] as List?)?.firstOrNull as Map<String, dynamic>?)?['value'] ?? "";

        if (current != null) {
          final tempC = current['temp_C'] ?? "--";
          final feelsLikeC = current['FeelsLikeC'] ?? tempC;
          final humidity = current['humidity'] ?? "--";
          final windKmph = current['windspeedKmph'] ?? "--";
          final desc = ((current['weatherDesc'] as List?)?.firstOrNull as Map<String, dynamic>?)?['value'] ?? "Clear";
          final maxTemp = forecast?['maxtempC'] ?? "";
          final minTemp = forecast?['mintempC'] ?? "";

          final rangeStr = (maxTemp.isNotEmpty && minTemp.isNotEmpty)
              ? " Today's Range: High $maxTemp°C, Low $minTemp°C."
              : "";

          final locationLabel = region.isNotEmpty ? "$areaName, $region, $country" : "$areaName, $country";

          return "Real-time Weather in $locationLabel: $desc, $tempC°C (Feels like $feelsLikeC°C). Humidity: $humidity%, Wind: $windKmph km/h.$rangeStr";
        }
      }
    } catch (e) {
      // Error or timeout
    }

    // Quick plain text fallback from wttr.in
    try {
      final fallbackUri = Uri.parse("https://wttr.in/${Uri.encodeComponent(cleanLoc)}?format=%C+%t+(feels+like+%f),+Humidity:+%h,+Wind:+%w");
      final request = await _httpClient.getUrl(fallbackUri);
      final response = await request.close().timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final body = (await response.transform(utf8.decoder).join()).trim();
        if (body.isNotEmpty && !body.contains("Unknown location")) {
          return "Real-time Weather in $cleanLoc: $body";
        }
      }
    } catch (_) {}

    return "Could not retrieve live weather for '$cleanLoc'. Please verify the city name or internet connection.";
  }
}
