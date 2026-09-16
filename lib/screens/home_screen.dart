import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/scan_item.dart';
import '../models/scan_result.dart';
import '../services/storage_service.dart';
import '../widgets/link_preview_sheet.dart';
import 'scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final StorageService _storageService = StorageService();
  List<ScanItem> _history = [];
  bool _isLoading = true;

  // Subtle pulse animation for the scan button
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _loadScanHistory();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.015).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadScanHistory() async {
    setState(() => _isLoading = true);
    final history = await _storageService.loadHistory();
    setState(() {
      _history = history;
      _isLoading = false;
    });
  }

  Future<void> _startScanning() async {
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );

    String? scannedUrl;
    bool shouldLaunch = false;

    if (result is ScanResult) {
      scannedUrl = result.url;
      shouldLaunch = result.shouldLaunch;
    } else if (result is String) {
      scannedUrl = result;
      shouldLaunch = true;
    }

    if (scannedUrl != null && scannedUrl.isNotEmpty) {
      final newItem = ScanItem(url: scannedUrl, timestamp: DateTime.now());
      setState(() => _history.insert(0, newItem));
      await _storageService.saveHistory(_history);
      if (shouldLaunch) await _launchURL(scannedUrl);
    }
  }

  Future<void> _showItemLinkPreview(String rawContent) async {
    final action = await LinkPreviewSheet.show(context, rawContent: rawContent);
    if (!mounted) return;
    if (action == LinkPreviewAction.open) {
      await _launchURL(rawContent);
    } else if (action == LinkPreviewAction.copy) {
      _showSnackBar('Link berhasil disalin!');
    }
  }

  Future<void> _launchURL(String urlString) async {
    String sanitizedUrl = urlString.trim();

    final lower = sanitizedUrl.toLowerCase();
    const blockedSchemes = ['javascript:', 'vbscript:', 'data:', 'file:', 'blob:'];
    if (blockedSchemes.any((s) => lower.startsWith(s))) {
      _showSnackBar('URL ini diblokir karena mengandung skema berbahaya.', isError: true);
      return;
    }

    if (!sanitizedUrl.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      sanitizedUrl = 'https://$sanitizedUrl';
    }

    try {
      final Uri uri = Uri.parse(sanitizedUrl);
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        _showSnackBar('Hanya URL http/https yang diizinkan.', isError: true);
        return;
      }
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('Tidak dapat membuka browser untuk link ini.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Format URL tidak valid.', isError: true);
    }
  }

  Future<void> _deleteItem(int index) async {
    final removedItem = _history[index];
    setState(() => _history.removeAt(index));

    final success = await _storageService.saveHistory(_history);
    if (!success) {
      setState(() => _history.insert(index, removedItem));
      _showSnackBar('Gagal menghapus item.', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.warning_rounded : Icons.check_circle_rounded,
              size: 16,
              color: isError
                  ? const Color(0xFFEF4444)
                  : Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF242424),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}/$month/$day · $hour:$minute';
  }

  bool _isUrlContent(String content) {
    final trimmed = content.trim().toLowerCase();
    return trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        RegExp(r'^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(/.*)?$').hasMatch(content.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'SNAPQR',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 3.0,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.delete_sweep_rounded,
                color: Colors.white.withValues(alpha: 0.45),
                size: 22,
              ),
              tooltip: 'Hapus semua riwayat',
              onPressed: _showClearHistoryDialog,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),

            // Scan Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ScaleTransition(
                scale: _pulseAnimation,
                child: GestureDetector(
                  onTap: _startScanning,
                  child: Container(
                    height: 148,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1C),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.09),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Subtle background icon
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 120,
                            color: Colors.white.withValues(alpha: 0.03),
                          ),
                        ),
                        // Top-left subtle tag
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Text(
                              'TAP TO SCAN',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                        // Center content
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.10),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.qr_code_scanner_rounded,
                                  size: 32,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'SCAN QR CODE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Buka kamera untuk memindai',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  fontSize: 11,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // History header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'RIWAYAT SCAN',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  if (_history.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Text(
                      '${_history.length}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // History list
            Expanded(
              child: _isLoading
                  ? Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    )
                  : _history.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _history.length,
                          separatorBuilder: (_, _) => Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.04),
                          ),
                          itemBuilder: (context, index) {
                            return _buildHistoryItem(_history[index], index);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1C1C1C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hapus Semua Riwayat',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Seluruh riwayat scan akan dihapus permanen.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        'Batal',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        setState(() => _history.clear());
                        await _storageService.saveHistory(_history);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        foregroundColor: const Color(0xFFEF4444),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      child: const Text(
                        'Hapus',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 40,
            color: Colors.white.withValues(alpha: 0.10),
          ),
          const SizedBox(height: 14),
          Text(
            'Belum ada riwayat',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.30),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Scan QR code pertama kamu',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.18),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(ScanItem item, int index) {
    final isUrl = _isUrlContent(item.url);
    return InkWell(
      onTap: () => _showItemLinkPreview(item.url),
      borderRadius: BorderRadius.circular(0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.07),
                  width: 1,
                ),
              ),
              child: Icon(
                isUrl ? Icons.link_rounded : Icons.text_snippet_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatDateTime(item.timestamp),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.28),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Delete
            GestureDetector(
              onTap: () => _deleteItem(index),
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
