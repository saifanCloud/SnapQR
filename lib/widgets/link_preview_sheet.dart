import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/web_metadata_service.dart';

enum LinkPreviewAction {
  open,
  copy,
  rescan,
}

class LinkPreviewSheet extends StatelessWidget {
  final String rawContent;
  final String? headerTitle;
  final VoidCallback? onOpen;
  final VoidCallback? onCopy;
  final VoidCallback? onRescan;

  const LinkPreviewSheet({
    super.key,
    required this.rawContent,
    this.headerTitle,
    this.onOpen,
    this.onCopy,
    this.onRescan,
  });

  static Future<LinkPreviewAction?> show(
    BuildContext context, {
    required String rawContent,
    String? headerTitle,
  }) {
    return showModalBottomSheet<LinkPreviewAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (context) => LinkPreviewSheet(
        rawContent: rawContent,
        headerTitle: headerTitle,
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
    return WebMetadataService.isWebUrl(rawContent);
  }

  String get _displayHeader {
    return WebMetadataService.extractHeader(rawContent, headerTitle);
  }

  _SecurityInfo get _securityInfo {
    final trimmed = rawContent.trim().toLowerCase();
    if (_isDangerousUrl) {
      return const _SecurityInfo(
        label: 'DANGEROUS',
        icon: Icons.dangerous_rounded,
        color: Color(0xFFEF4444),
      );
    } else if (trimmed.startsWith('https://')) {
      return const _SecurityInfo(
        label: 'HTTPS',
        icon: Icons.lock_rounded,
        color: Color(0xFF10B981),
      );
    } else if (trimmed.startsWith('http://')) {
      return const _SecurityInfo(
        label: 'HTTP',
        icon: Icons.lock_open_rounded,
        color: Color(0xFFF59E0B),
      );
    } else if (_isUrl) {
      return const _SecurityInfo(
        label: 'WEB LINK',
        icon: Icons.link_rounded,
        color: Color(0xFF9E9E9E),
      );
    } else {
      return const _SecurityInfo(
        label: 'TEXT',
        icon: Icons.notes_rounded,
        color: Color(0xFF9E9E9E),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final security = _securityInfo;
    final isWebUrl = _isUrl;

    final bgColor = isDark ? const Color(0xFF141414) : Colors.white;
    final borderColor = isDark ? const Color(0xFF262626) : const Color(0xFFE2E2E2);
    final textPrimary = isDark ? Colors.white : const Color(0xFF111111);
    final textSecondary = isDark ? const Color(0xFF8E8E8E) : const Color(0xFF6E6E6E);
    final contentBg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: borderColor, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
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
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Top Header Box (Website Title / Header)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Icon(
                    isWebUrl ? Icons.language_rounded : Icons.qr_code_2_rounded,
                    size: 22,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(width: 14),

                // Web Header Title and security badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WEBSITE / SOURCE HEADER',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _displayHeader,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(security.icon, size: 12, color: security.color),
                          const SizedBox(width: 5),
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

            // Sub-header label for the Link / Content below
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                children: [
                  Icon(
                    Icons.link_rounded,
                    size: 14,
                    color: textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'SCANNED LINK / CONTENT',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Content box (Link URL below header)
            Container(
              constraints: const BoxConstraints(maxHeight: 110),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: contentBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: SelectableText(
                  rawContent,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 12.5,
                    height: 1.45,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Danger warning if suspicious
            if (_isDangerousUrl)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_rounded,
                        size: 16, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This QR code contains a dangerous URL format and is blocked for security.',
                        style: TextStyle(
                          color: const Color(0xFFEF4444),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Action buttons (Copy & Open)
            Row(
              children: [
                // Copy button
                Expanded(
                  child: _SheetButton(
                    label: 'Copy',
                    icon: Icons.copy_rounded,
                    isDark: isDark,
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
                    label: isWebUrl ? 'Open Link' : 'Use',
                    icon: isWebUrl
                        ? Icons.open_in_browser_rounded
                        : Icons.check_circle_rounded,
                    isDark: isDark,
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
                    'Scan Again',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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
  final bool isDark;

  const _SheetButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.style,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    final isPrimary = style == _SheetButtonStyle.primary;

    Color bg;
    Color fg;
    Color border;

    if (isPrimary) {
      if (isDark) {
        bg = isDisabled ? Colors.white10 : Colors.white;
        fg = isDisabled ? Colors.white30 : Colors.black;
        border = bg;
      } else {
        bg = isDisabled ? Colors.black12 : Colors.black;
        fg = isDisabled ? Colors.black26 : Colors.white;
        border = bg;
      }
    } else {
      bg = Colors.transparent;
      fg = isDark ? (isDisabled ? Colors.white24 : Colors.white) : (isDisabled ? Colors.black26 : Colors.black);
      border = isDark ? const Color(0xFF333333) : const Color(0xFFD6D6D6);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
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

