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

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storageService = StorageService();
  List<ScanItem> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadScanHistory();
  }

  /// Load scan history from JSON file.
  Future<void> _loadScanHistory() async {
    setState(() {
      _isLoading = true;
    });
    final history = await _storageService.loadHistory();
    setState(() {
      _history = history;
      _isLoading = false;
    });
  }

  /// Trigger scanning process.
  Future<void> _startScanning() async {
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (context) => const ScannerScreen(),
      ),
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
      final newItem = ScanItem(
        url: scannedUrl,
        timestamp: DateTime.now(),
      );

      // 1. Append the new item to the top of the list
      setState(() {
        _history.insert(0, newItem);
      });

      // 2. Save updated list to local JSON file
      await _storageService.saveHistory(_history);

      // 3. Launch URL if requested
      if (shouldLaunch) {
        await _launchURL(scannedUrl);
      }
    }
  }

  /// Show Link Preview Bottom Sheet for an item in history
  Future<void> _showItemLinkPreview(String rawContent) async {
    final action = await LinkPreviewSheet.show(context, rawContent: rawContent);
    if (!mounted) return;

    if (action == LinkPreviewAction.open) {
      await _launchURL(rawContent);
    } else if (action == LinkPreviewAction.copy) {
      _showSnackBar('Link berhasil disalin!');
    }
  }

  /// Launch scanned URL in the external browser.
  Future<void> _launchURL(String urlString) async {
    String sanitizedUrl = urlString.trim();

    // Check if it is a valid scheme, otherwise prepend https://
    if (!sanitizedUrl.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      sanitizedUrl = 'https://$sanitizedUrl';
    }

    try {
      final Uri uri = Uri.parse(sanitizedUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('Could not launch browser for this QR code contents.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Invalid URL format: $urlString', isError: true);
    }
  }

  /// Delete a single scan item from history.
  Future<void> _deleteItem(int index) async {
    final removedItem = _history[index];
    setState(() {
      _history.removeAt(index);
    });

    final success = await _storageService.saveHistory(_history);
    if (success) {
      _showSnackBar('Scan deleted from history.');
    } else {
      // Revert if saving fails
      setState(() {
        _history.insert(index, removedItem);
      });
      _showSnackBar('Failed to update history file.', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  /// Helper to format DateTime to a nice string without external package
  String _formatDateTime(DateTime dt) {
    final year = dt.year;
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark Slate Background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const Text(
              'CLOUD SCANNER',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white70),
              tooltip: 'Clear All History',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF1E293B),
                    title: const Text('Clear History', style: TextStyle(color: Colors.white)),
                    content: const Text(
                      'Are you sure you want to permanently clear all scan history?',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('CANCEL', style: TextStyle(color: Colors.white38)),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          setState(() {
                            _history.clear();
                          });
                          await _storageService.saveHistory(_history);
                          _showSnackBar('All scan history cleared.');
                        },
                        child: const Text('CLEAR ALL', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // Top Section: Prominent "Scan QR Code" Button
              InkWell(
                onTap: _startScanning,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0EA5E9), // Ocean Blue Accent
                        Color(0xFF0284C7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0EA5E9).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Subtle background icon overlay
                      Positioned(
                        right: -10,
                        bottom: -10,
                        child: Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 140,
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.qr_code_scanner_rounded,
                              size: 40,
                              color: Colors.white,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'SCAN QR CODE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2.0,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Tap to open camera and scan link',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Title Section: Scan History
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Scan History',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (_history.isNotEmpty)
                    Text(
                      '${_history.length} items',
                      style: TextStyle(
                        color: const Color(0xFF94A3B8).withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Bottom Section: Scrollable History List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0EA5E9)),
                        ),
                      )
                    : _history.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: _history.length,
                            itemBuilder: (context, index) {
                              final item = _history[index];
                              return _buildHistoryCard(item, index);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Empty state design
  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.4),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.history_rounded,
            size: 48,
            color: const Color(0xFF94A3B8).withOpacity(0.3),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'No scans yet',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your scanned QR codes will be logged here.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF94A3B8).withOpacity(0.6),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  /// Individual Scan History Card
  Widget _buildHistoryCard(ScanItem item, int index) {
    return Card(
      color: const Color(0xFF1E293B), // Slate Card background
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Colors.white.withOpacity(0.04),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showItemLinkPreview(item.url),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            children: [
              // Left side: Icon indicator
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.link_rounded,
                  color: Color(0xFF0EA5E9),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),

              // Center: Content info
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
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTime(item.timestamp),
                      style: TextStyle(
                        color: const Color(0xFF94A3B8).withOpacity(0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // Right side: Delete button
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444),
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _deleteItem(index),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
