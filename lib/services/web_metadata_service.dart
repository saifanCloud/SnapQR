import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class WebMetadataService {
  static final Map<String, String> _titleCache = {};

  static const Map<String, String> _knownSites = {
    'google.com': 'Google',
    'google.co.id': 'Google',
    'youtube.com': 'YouTube',
    'youtu.be': 'YouTube',
    'github.com': 'GitHub',
    'instagram.com': 'Instagram',
    'twitter.com': 'X (Twitter)',
    'x.com': 'X (Twitter)',
    'facebook.com': 'Facebook',
    'fb.com': 'Facebook',
    'tiktok.com': 'TikTok',
    'wikipedia.org': 'Wikipedia',
    'linkedin.com': 'LinkedIn',
    'reddit.com': 'Reddit',
    'spotify.com': 'Spotify',
    'netflix.com': 'Netflix',
    'tokopedia.com': 'Tokopedia',
    'shopee.co.id': 'Shopee',
    'shopee.com': 'Shopee',
    'bukalapak.com': 'Bukalapak',
    'blibli.com': 'Blibli',
    'lazada.co.id': 'Lazada',
    'wa.me': 'WhatsApp Chat',
    'whatsapp.com': 'WhatsApp',
    't.me': 'Telegram',
    'telegram.org': 'Telegram',
    'discord.com': 'Discord',
    'discord.gg': 'Discord',
    'medium.com': 'Medium',
    'stackoverflow.com': 'Stack Overflow',
    'flutter.dev': 'Flutter Dev',
    'dart.dev': 'Dart Dev',
    'apple.com': 'Apple',
    'microsoft.com': 'Microsoft',
    'drive.google.com': 'Google Drive',
    'docs.google.com': 'Google Docs',
    'maps.google.com': 'Google Maps',
  };

  /// Check whether raw content looks like a web URL
  static bool isWebUrl(String content) {
    final trimmed = content.trim().toLowerCase();
    if (trimmed.startsWith('javascript:') ||
        trimmed.startsWith('data:') ||
        trimmed.startsWith('file:') ||
        trimmed.startsWith('vbscript:')) {
      return false;
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return true;
    }
    final domainRegExp = RegExp(r'^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(/.*)?$');
    return domainRegExp.hasMatch(trimmed);
  }

  /// Extracts a clean, human-readable Header from QR content.
  /// If [savedTitle] is available, it is returned immediately.
  static String extractHeader(String rawContent, [String? savedTitle]) {
    if (savedTitle != null && savedTitle.trim().isNotEmpty) {
      return savedTitle.trim();
    }

    final trimmed = rawContent.trim();

    // Check special QR schemes
    if (trimmed.startsWith('WIFI:')) {
      final ssidMatch = RegExp(r'S:([^;]+);').firstMatch(trimmed);
      final ssid = ssidMatch != null ? ssidMatch.group(1) : '';
      return ssid != null && ssid.isNotEmpty ? 'Wi-Fi: $ssid' : 'Wi-Fi Network';
    }

    if (trimmed.toLowerCase().startsWith('mailto:')) {
      final email = trimmed.substring(7).split('?').first;
      return email.isNotEmpty ? 'Email: $email' : 'Send Email';
    }

    if (trimmed.toLowerCase().startsWith('tel:')) {
      final number = trimmed.substring(4);
      return number.isNotEmpty ? 'Phone: $number' : 'Phone Call';
    }

    if (trimmed.toLowerCase().startsWith('sms:') ||
        trimmed.toLowerCase().startsWith('smsto:')) {
      return 'Send SMS Message';
    }

    if (trimmed.toLowerCase().startsWith('geo:')) {
      return 'Map Location';
    }

    if (trimmed.startsWith('BEGIN:VCARD')) {
      return 'Contact Card (vCard)';
    }

    if (!isWebUrl(trimmed)) {
      return 'Text / Note';
    }

    // Parse URL Host
    String formattedUrl = trimmed;
    if (!formattedUrl.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      formattedUrl = 'https://$formattedUrl';
    }

    try {
      final uri = Uri.parse(formattedUrl);
      String host = uri.host.toLowerCase();
      if (host.startsWith('www.')) {
        host = host.substring(4);
      }

      // Check known brand sites
      if (_knownSites.containsKey(host)) {
        return _knownSites[host]!;
      }

      // Check parent domain if sub-domain (e.g., support.apple.com)
      for (final entry in _knownSites.entries) {
        if (host.endsWith('.${entry.key}')) {
          final sub = host.replaceAll('.${entry.key}', '');
          return '${_capitalize(sub)} · ${entry.value}';
        }
      }

      // Fallback clean capitalization
      if (host.isNotEmpty) {
        final parts = host.split('.');
        if (parts.length >= 2) {
          final domainName = _capitalize(parts[parts.length - 2]);
          final tld = parts.last;
          return '$domainName.$tld';
        }
        return _capitalize(host);
      }
    } catch (_) {}

    return 'Web Page';
  }

  /// Capitalizes the first letter of each word
  static String _capitalize(String input) {
    if (input.isEmpty) return input;
    return input.split('-').map((segment) {
      if (segment.isEmpty) return segment;
      return segment[0].toUpperCase() + segment.substring(1);
    }).join(' ');
  }

  /// Asynchronously fetches the HTML <title> of the website.
  /// Lightweight: reads at most 32KB and cancels stream immediately once title is found.
  static Future<String?> fetchWebTitle(String url) async {
    if (!isWebUrl(url)) return null;

    String targetUrl = url.trim();
    if (!targetUrl.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      targetUrl = 'https://$targetUrl';
    }

    if (_titleCache.containsKey(targetUrl)) {
      return _titleCache[targetUrl];
    }

    HttpClient? client;
    try {
      final uri = Uri.parse(targetUrl);
      if (uri.scheme != 'http' && uri.scheme != 'https') return null;

      client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 4);

      final request = await client.getUrl(uri).timeout(const Duration(seconds: 4));
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      );
      request.headers.set(
        HttpHeaders.acceptHeader,
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      );
      request.followRedirects = true;
      request.maxRedirects = 3;

      final response = await request.close().timeout(const Duration(seconds: 4));
      if (response.statusCode != HttpStatus.ok) {
        client.close(force: true);
        return null;
      }

      // Read at most 32KB of data
      final List<int> bytes = [];
      const int maxBytes = 32768;

      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length >= maxBytes) break;
      }
      client.close(force: true);

      final html = utf8.decode(bytes, allowMalformed: true);
      String? title = _extractTitleFromHtml(html);

      if (title != null && title.isNotEmpty) {
        _titleCache[targetUrl] = title;
        return title;
      }
    } catch (e) {
      if (kDebugMode) {
        print('WebMetadataService: Could not fetch title for $url: $e');
      }
    } finally {
      client?.close(force: true);
    }

    return null;
  }

  /// Extracts and decodes HTML title or meta title tag
  static String? _extractTitleFromHtml(String html) {
    // 1. Try <title> tag
    final titleMatch = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false)
        .firstMatch(html);
    if (titleMatch != null) {
      final raw = titleMatch.group(1);
      final decoded = _cleanHtmlEntities(raw);
      if (_isValidTitle(decoded)) return decoded;
    }

    // 2. Try OpenGraph og:title
    final ogMatch = RegExp(
      r'''<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(html) ??
    RegExp(
      r'''<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:title["']''',
      caseSensitive: false,
    ).firstMatch(html);

    if (ogMatch != null) {
      final raw = ogMatch.group(1);
      final decoded = _cleanHtmlEntities(raw);
      if (_isValidTitle(decoded)) return decoded;
    }

    // 3. Try Twitter title
    final twitterMatch = RegExp(
      r'''<meta[^>]+name=["']twitter:title["'][^>]+content=["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(html);

    if (twitterMatch != null) {
      final raw = twitterMatch.group(1);
      final decoded = _cleanHtmlEntities(raw);
      if (_isValidTitle(decoded)) return decoded;
    }

    return null;
  }

  static bool _isValidTitle(String? title) {
    if (title == null) return false;
    final t = title.trim();
    if (t.isEmpty || t.length > 250) return false;
    final lower = t.toLowerCase();
    if (lower == '403 forbidden' ||
        lower == '404 not found' ||
        lower == 'access denied' ||
        lower.contains('attention required') ||
        lower.contains('just a moment...')) {
      return false;
    }
    return true;
  }

  static String _cleanHtmlEntities(String? input) {
    if (input == null) return '';
    var text = input.trim();
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&apos;', "'");
    text = text.replaceAll('&#39;', "'");
    text = text.replaceAll('&#x27;', "'");
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&mdash;', '—');
    text = text.replaceAll('&ndash;', '–');
    text = text.replaceAll('&#8211;', '–');
    text = text.replaceAll('&#8212;', '—');
    text = text.replaceAll('&#8216;', '‘');
    text = text.replaceAll('&#8217;', '’');
    text = text.replaceAll('&#8220;', '“');
    text = text.replaceAll('&#8221;', '”');
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    return text.trim();
  }
}
