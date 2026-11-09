import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class BrowserService {
  /// Opens the provided URL in Google Chrome / default external browser application
  static Future<bool> openInBrowser(String rawUrl) async {
    try {
      var trimmed = rawUrl.trim();
      if (trimmed.isEmpty) return false;

      // Ensure scheme is present
      if (!trimmed.startsWith(RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://'))) {
        trimmed = 'https://$trimmed';
      }

      final uri = Uri.parse(trimmed);

      // Attempt LaunchMode.externalApplication to open Chrome / default browser
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        // Fallback to platform default
        return await launchUrl(uri);
      }
      return launched;
    } catch (e) {
      debugPrint('BrowserService: Failed to open URL ($rawUrl): $e');
      return false;
    }
  }

  /// Search a query in Google Chrome
  static Future<bool> searchInBrowser(String query) async {
    final encoded = Uri.encodeComponent(query);
    return await openInBrowser('https://www.google.com/search?q=$encoded');
  }
}

