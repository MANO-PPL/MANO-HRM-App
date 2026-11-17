import 'dart:io';

/// Baked-in store fallback URLs and domain verification (R11).
class AppStoreLinks {
  static const String androidMarketUri = 'market://details?id=co.mano.attendance';
  static const String androidWebFallback = 'https://play.google.com/store/apps/details?id=co.mano.attendance';
  static const String iosAppStoreWeb = 'https://apps.apple.com/app/id6738914562';

  static final Set<String> _allowedHosts = {
    'play.google.com',
    'apps.apple.com',
  };

  /// Resolves a safe store URL, strictly validating any server-provided URL against
  /// approved app store domains before falling back to baked-in links.
  static String resolveStoreUrl(String? serverUrl) {
    if (serverUrl != null && serverUrl.trim().isNotEmpty) {
      try {
        final uri = Uri.parse(serverUrl.trim());
        if (uri.isScheme('https') && _allowedHosts.contains(uri.host.toLowerCase())) {
          return serverUrl.trim();
        }
      } catch (_) {
        // Fall through to baked-in link
      }
    }

    if (Platform.isAndroid) {
      return androidWebFallback;
    } else {
      return iosAppStoreWeb;
    }
  }
}
