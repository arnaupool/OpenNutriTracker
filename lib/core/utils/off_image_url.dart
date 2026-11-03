import 'package:flutter/foundation.dart' show kIsWeb;

/// Open Food Facts serves product photos from images.openfoodfacts.org, which
/// takes 13 to 25 s to first byte per thumbnail, and the web build has no
/// persistent disk cache. The Docker image therefore proxies and caches them
/// same-origin (`/off-images/` and `/off-static/`, see nginx.app.conf).
///
/// Every widget that shows a product photo passes the URL through
/// [displayImageUrl]. Native builds keep calling OFF directly.
String displayImageUrl(String url, {bool? isWeb, Uri? base}) {
  if (!(isWeb ?? kIsWeb)) return url;
  final rewritten = rewriteOffImageUrl(url);
  if (rewritten == null) return url;
  // Resolved against the document base so a sub-path deployment still works.
  return (base ?? Uri.base).resolve(rewritten).toString();
}

/// Maps an OFF image URL to its same-origin proxy path (relative, no leading
/// slash), or null when [url] is not an OFF image URL.
String? rewriteOffImageUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) return null;
  final String prefix;
  switch (uri.host) {
    case 'images.openfoodfacts.org':
      prefix = 'off-images';
    case 'static.openfoodfacts.org':
      prefix = 'off-static';
    default:
      return null;
  }
  final query = uri.hasQuery ? '?${uri.query}' : '';
  return '$prefix${uri.path}$query';
}
