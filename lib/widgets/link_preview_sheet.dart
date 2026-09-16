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

  static Future<LinkPreviewAction?> show(
    BuildContext context, {
    required String rawContent,
  }) {
    return showModalBottomSheet<LinkPreviewAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
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

  bool get _isDangerousUrl {
    final lower = rawContent.trim().toLowerCase();
    return _blockedSchemes.any((scheme) => lower.startsWith(scheme));
  }

  bool get _isUrl {
    if (_isDangerousUrl) return false;
    final trimmed = rawContent.trim();
    if (trimmed.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      return true;
    }
    final domainRegExp = RegExp(r'^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(/.*)?$');
    return domainRegExp.hasMatch(trimmed);
  }

  String get _formattedUrl {
    final trimmed = rawContent.trim();
    if (trimmed.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  String get _domainHost {
    if (!_isUrl) return 'Teks';
    try {
      final uri = Uri.parse(_formattedUrl);
      if (uri.host.isNotEmpty) return uri.host;
    } catch (_) {}
    return 'Link';
  }

  _SecurityInfo get _securityInfo {
    final trimmed = rawContent.trim().toLowerCase();
    if (_isDangerousUrl) {
      return const _SecurityInfo(
        label: 'BERBAHAYA',
        icon: Icons.dangerous_rounded,
        color: Color(0xFFEF4444),
      );
    } else if (trimmed.startsWith('https://')) {
      return const _SecurityInfo(
        label: 'HTTPS',
        icon: Icons.lock_rounded,
        color: Color(0xFF6EE7B7),
      );
    } else if (trimmed.startsWith('http://')) {
      return const _SecurityInfo(
        label: 'HTTP',
        icon: Icons.lock_open_rounded,
        color: Color(0xFFFBBF24),
      );
    } else if (_isUrl) {
      return const _SecurityInfo(
        label: 'HTTPS',
        icon: Icons.shield_rounded,
        color: Color(0xFF9CA3AF),
      );
    } else {
      return const _SecurityInfo(
        label: 'TEKS',
        icon: Icons.notes_rounded,
        color: Color(0xFF9CA3AF),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final security = _securityInfo;
    final isWebUrl = _isUrl;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.07), width: 1),
        ),
      ),
      padding: EdgeInsets.only(
        top: 0,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 3,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.07),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    isWebUrl ? Icons.language_rounded : Icons.text_snippet_rounded,
                    size: 20,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(width: 12),

                // Title + tag
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            security.icon,
                            size: 11,
                            color: security.color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            security.label,
                            style: TextStyle(
                              color: security.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Content box
            Container(
              constraints: const BoxConstraints(maxHeight: 100),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.07),
                  width: 1,
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: SelectableText(
                  rawContent,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                    height: 1.5,
                    fontFamily: 'monospace',
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Danger warning
            if (_isDangerousUrl)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_rounded,
                        size: 14, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'QR code ini mengandung URL berbahaya dan diblokir.',
                        style: TextStyle(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.85),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Action buttons
            Row(
              children: [
                // Copy button
                Expanded(
                  child: _SheetButton(
                    label: 'Salin',
                    icon: Icons.copy_rounded,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: rawContent));
                      if (onCopy != null) {
                        onCopy!();
                      } else {
                        Navigator.of(context).pop(LinkPreviewAction.copy);
                      }
                    },
                    style: _SheetButtonStyle.outline,
                  ),
                ),
                const SizedBox(width: 10),
                // Open button
                Expanded(
                  flex: 2,
                  child: _SheetButton(
                    label: isWebUrl ? 'Buka Link' : 'Gunakan',
                    icon: isWebUrl
                        ? Icons.open_in_browser_rounded
                        : Icons.check_circle_rounded,
                    onTap: _isDangerousUrl
                        ? null
                        : () {
                            if (onOpen != null) {
                              onOpen!();
                            } else {
                              Navigator.of(context).pop(LinkPreviewAction.open);
                            }
                          },
                    style: _SheetButtonStyle.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Rescan button
            Center(
              child: GestureDetector(
                onTap: () {
                  if (onRescan != null) {
                    onRescan!();
                  } else {
                    Navigator.of(context).pop(LinkPreviewAction.rescan);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Scan Lagi',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.28),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
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

// ─── Button style helper ────────────────────────────────────────────────────────

enum _SheetButtonStyle { outline, primary }

class _SheetButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final _SheetButtonStyle style;

  const _SheetButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    final isPrimary = style == _SheetButtonStyle.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isPrimary
              ? Colors.white.withValues(alpha: isDisabled ? 0.03 : 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDisabled ? 0.06 : 0.12),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isDisabled
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: isPrimary ? 0.9 : 0.55),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: isDisabled
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: isPrimary ? 0.9 : 0.65),
                fontSize: 13,
                fontWeight:
                    isPrimary ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Security info model ────────────────────────────────────────────────────────

class _SecurityInfo {
  final String label;
  final IconData icon;
  final Color color;

  const _SecurityInfo({
    required this.label,
    required this.icon,
    required this.color,
  });
}
