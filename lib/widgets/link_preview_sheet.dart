import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum LinkPreviewAction {
  open,
  copy,
  rescan,
}

class LinkPreviewSheet extends StatelessWidget {
  final String rawContent;
  final VoidCallback? onOpen;
  final VoidCallback? onCopy;
  final VoidCallback? onRescan;

  const LinkPreviewSheet({
    super.key,
    required this.rawContent,
    this.onOpen,
    this.onCopy,
    this.onRescan,
  });

  /// Helper to show the bottom sheet modal
  static Future<LinkPreviewAction?> show(
    BuildContext context, {
    required String rawContent,
  }) {
    return showModalBottomSheet<LinkPreviewAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LinkPreviewSheet(
        rawContent: rawContent,
        onOpen: () => Navigator.of(context).pop(LinkPreviewAction.open),
        onCopy: () => Navigator.of(context).pop(LinkPreviewAction.copy),
        onRescan: () => Navigator.of(context).pop(LinkPreviewAction.rescan),
      ),
    );
  }

  /// Dangerous URL schemes that must never be opened
  static const _blockedSchemes = [
    'javascript:',
    'vbscript:',
    'data:',
    'file:',
    'blob:',
  ];

  /// Returns true if the content contains a blocked/dangerous scheme
  bool get _isDangerousUrl {
    final lower = rawContent.trim().toLowerCase();
    return _blockedSchemes.any((scheme) => lower.startsWith(scheme));
  }

  /// Check if the content is a safe web URL (http/https only)
  bool get _isUrl {
    if (_isDangerousUrl) return false;
    final trimmed = rawContent.trim();
    if (trimmed.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      return true;
    }
    // Check simple domain pattern like google.com, example.org/path
    final domainRegExp = RegExp(r'^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(/.*)?$');
    return domainRegExp.hasMatch(trimmed);
  }

  /// Get formatted URL with scheme (always https for bare domains)
  String get _formattedUrl {
    final trimmed = rawContent.trim();
    if (trimmed.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  /// Extract host domain name for title (e.g. google.com, github.com)
  String get _domainHost {
    if (!_isUrl) return 'Text Content';
    try {
      final uri = Uri.parse(_formattedUrl);
      if (uri.host.isNotEmpty) {
        return uri.host;
      }
    } catch (_) {}
    return 'Web Link';
  }

  /// Security status info (HTTPS vs HTTP vs Dangerous vs Text)
  _SecurityInfo get _securityInfo {
    final trimmed = rawContent.trim().toLowerCase();
    if (_isDangerousUrl) {
      return const _SecurityInfo(
        label: 'BERBAHAYA - Blokir',
        icon: Icons.dangerous_rounded,
        color: Color(0xFFEF4444), // Red
        backgroundColor: Color(0xFF7F1D1D),
      );
    } else if (trimmed.startsWith('https://')) {
      return const _SecurityInfo(
        label: 'HTTPS (Aman / Secure)',
        icon: Icons.lock_rounded,
        color: Color(0xFF10B981), // Emerald Green
        backgroundColor: Color(0xFF064E3B),
      );
    } else if (trimmed.startsWith('http://')) {
      return const _SecurityInfo(
        label: 'HTTP (Tidak Terenkripsi)',
        icon: Icons.gpp_maybe_rounded,
        color: Color(0xFFF59E0B), // Amber Warning
        backgroundColor: Color(0xFF78350F),
      );
    } else if (_isUrl) {
      return const _SecurityInfo(
        label: 'HTTPS (Default)',
        icon: Icons.shield_rounded,
        color: Color(0xFF0EA5E9), // Ocean Blue
        backgroundColor: Color(0xFF0C4A6E),
      );
    } else {
      return const _SecurityInfo(
        label: 'Teks Biasa',
        icon: Icons.notes_rounded,
        color: Color(0xFF8B5CF6), // Purple
        backgroundColor: Color(0xFF4C1D95),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final security = _securityInfo;
    final isWebUrl = _isUrl;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B), // Dark Slate
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 25,
            spreadRadius: 5,
            offset: Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: 24,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle Bar (Google Lens style)
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Section: Google Scan Style Header
            Row(
              children: [
                // Icon Badge
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: security.backgroundColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: security.color.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    isWebUrl ? Icons.language_rounded : Icons.text_snippet_rounded,
                    color: security.color,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                // Title and Security Tag
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _domainHost,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: security.backgroundColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: security.color.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              security.icon,
                              size: 12,
                              color: security.color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              security.label,
                              style: TextStyle(
                                color: security.color,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Link / Raw Content Box
            Container(
              constraints: const BoxConstraints(maxHeight: 120),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: SelectableText(
                  rawContent,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.4,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons Section
            Row(
              children: [
                // Secondary Button: Copy Link
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: rawContent));
                      if (onCopy != null) {
                        onCopy!();
                      } else {
                        Navigator.of(context).pop(LinkPreviewAction.copy);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Salin Link',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Primary Action Button: Open Web / Open Link
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF0EA5E9),
                          Color(0xFF0284C7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      // Block dangerous URLs from being opened
                      onPressed: _isDangerousUrl
                          ? null
                          : () {
                              if (onOpen != null) {
                                onOpen!();
                              } else {
                                Navigator.of(context).pop(LinkPreviewAction.open);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: Icon(
                        isWebUrl ? Icons.open_in_browser_rounded : Icons.check_circle_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: Text(
                        isWebUrl ? 'Buka Link' : 'Gunakan',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Rescan / Tutup Button
            Center(
              child: TextButton.icon(
                onPressed: () {
                  if (onRescan != null) {
                    onRescan!();
                  } else {
                    Navigator.of(context).pop(LinkPreviewAction.rescan);
                  }
                },
                icon: const Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 16,
                  color: Colors.white60,
                ),
                label: const Text(
                  'Scan Lagi',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityInfo {
  final String label;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const _SecurityInfo({
    required this.label,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });
}
