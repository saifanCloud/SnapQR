import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/scan_item.dart';
import '../models/scan_result.dart';
import '../services/qr_image_decoder.dart';
import '../services/storage_service.dart';
import '../services/theme_service.dart';
import '../services/web_metadata_service.dart';
import '../widgets/link_preview_sheet.dart';
import 'scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();

  List<ScanItem> _history = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _fetchingUrls = {};

  // Pulse animation for scan card
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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadScanHistory() async {
    setState(() => _isLoading = true);
    final history = await _storageService.loadHistory();
    setState(() {
      _history = history;
      _isLoading = false;
    });

    // Background title fetch for existing web links that don't have titles yet
    _fetchMissingWebTitles();
  }

  void _fetchMissingWebTitles() {
    for (int i = 0; i < _history.length; i++) {
      final item = _history[i];
      if ((item.title == null || item.title!.isEmpty) &&
          WebMetadataService.isWebUrl(item.url)) {
        _fetchTitleForItem(item.url);
      }
    }
  }

  Future<void> _fetchTitleForItem(String url) async {
    if (_fetchingUrls.contains(url)) return;
    _fetchingUrls.add(url);

    try {
      final title = await WebMetadataService.fetchWebTitle(url);
      if (title != null && title.isNotEmpty && mounted) {
        bool updated = false;
        setState(() {
          _history = _history.map((item) {
            if (item.url == url && (item.title == null || item.title!.isEmpty || item.title == WebMetadataService.extractHeader(url))) {
              updated = true;
              return item.copyWith(title: title);
            }
            return item;
          }).toList();
        });

        if (updated) {
          await _storageService.saveHistory(_history);
        }
      }
    } catch (_) {
    } finally {
      _fetchingUrls.remove(url);
    }
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
      await _processScannedValue(scannedUrl, shouldLaunch: shouldLaunch);
    }
  }

  Future<void> _pickAndScanGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();
      final detected = QrImageDecoder.decodeBytes(bytes);

      if (!mounted) return;

      if (detected != null && detected.trim().isNotEmpty) {
        final val = detected.trim();
        final action = await LinkPreviewSheet.show(context, rawContent: val);
        if (!mounted) return;

        if (action == LinkPreviewAction.open) {
          await _processScannedValue(val, shouldLaunch: true);
        } else if (action == LinkPreviewAction.copy) {
          await Clipboard.setData(ClipboardData(text: val));
          _showSnackBar('Link copied to clipboard!');
          await _processScannedValue(val, shouldLaunch: false);
        } else if (action != null) {
          await _processScannedValue(val, shouldLaunch: false);
        }
      } else {
        _showSnackBar('No QR code found in this image.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Failed to process gallery image.', isError: true);
    }
  }

  Future<void> _processScannedValue(String scannedUrl, {required bool shouldLaunch}) async {
    final defaultHeader = WebMetadataService.extractHeader(scannedUrl);
    final newItem = ScanItem(
      url: scannedUrl,
      timestamp: DateTime.now(),
      title: defaultHeader,
    );

    setState(() => _history.insert(0, newItem));
    await _storageService.saveHistory(_history);

    // Fetch full webpage title asynchronously if web link
    if (WebMetadataService.isWebUrl(scannedUrl)) {
      _fetchTitleForItem(scannedUrl);
    }

    if (shouldLaunch) {
      await _launchURL(scannedUrl);
    }
  }

  Future<void> _showItemLinkPreview(ScanItem item) async {
    final action = await LinkPreviewSheet.show(
      context,
      rawContent: item.url,
      headerTitle: item.title,
    );
    if (!mounted) return;
    if (action == LinkPreviewAction.open) {
      await _launchURL(item.url);
    } else if (action == LinkPreviewAction.copy) {
      await Clipboard.setData(ClipboardData(text: item.url));
      _showSnackBar('Link copied to clipboard!');
    }
  }

  Future<void> _launchURL(String urlString) async {
    String sanitizedUrl = urlString.trim();

    final lower = sanitizedUrl.toLowerCase();
    const blockedSchemes = ['javascript:', 'vbscript:', 'data:', 'file:', 'blob:'];
    if (blockedSchemes.any((s) => lower.startsWith(s))) {
      _showSnackBar('This URL is blocked because it contains a dangerous scheme.', isError: true);
      return;
    }

    if (!sanitizedUrl.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      sanitizedUrl = 'https://$sanitizedUrl';
    }

    try {
      final Uri uri = Uri.parse(sanitizedUrl);
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        _showSnackBar('Only http/https URLs are allowed.', isError: true);
        return;
      }
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('Cannot open browser for this link.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Invalid URL format.', isError: true);
    }
  }

  Future<void> _deleteItem(int index) async {
    // Find item from filtered or original list
    final filtered = _filteredHistory;
    final itemToDelete = filtered[index];
    final originalIndex = _history.indexOf(itemToDelete);

    if (originalIndex == -1) return;

    setState(() => _history.removeAt(originalIndex));

    final success = await _storageService.saveHistory(_history);
    if (!success) {
      setState(() => _history.insert(originalIndex, itemToDelete));
      _showSnackBar('Failed to delete item.', isError: true);
    } else {
      _showSnackBar('History item deleted.');
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.warning_rounded : Icons.check_circle_rounded,
              size: 16,
              color: isError
                  ? const Color(0xFFEF4444)
                  : (isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF222222) : const Color(0xFFEDEDED),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFD4D4D4),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;

    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');

    if (isToday) {
      return 'Today · $hour:$minute';
    } else if (isYesterday) {
      return 'Yesterday · $hour:$minute';
    } else {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final monthName = months[dt.month - 1];
      return '${dt.day} $monthName ${dt.year} · $hour:$minute';
    }
  }

  List<ScanItem> get _filteredHistory {
    if (_searchQuery.trim().isEmpty) return _history;
    final q = _searchQuery.trim().toLowerCase();
    return _history.where((item) {
      final urlMatch = item.url.toLowerCase().contains(q);
      final titleMatch = (item.title ?? '').toLowerCase().contains(q);
      final derivedMatch = WebMetadataService.extractHeader(item.url).toLowerCase().contains(q);
      return urlMatch || titleMatch || derivedMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _filteredHistory;

    final bgColor = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardTheme.color ?? (isDark ? const Color(0xFF161616) : Colors.white);
    final borderColor = isDark ? const Color(0xFF262626) : const Color(0xFFE2E2E2);
    final textPrimary = isDark ? Colors.white : const Color(0xFF111111);
    final textSecondary = isDark ? const Color(0xFF888888) : const Color(0xFF666666);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white : Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.qr_code_2_rounded,
                size: 18,
                color: isDark ? Colors.black : Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'SNAPQR',
              style: TextStyle(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF222222) : const Color(0xFFEAEAEA),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: borderColor, width: 0.8),
              ),
              child: Text(
                isDark ? 'NOIR' : 'LIGHT',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: textSecondary,
                ),
              ),
            ),
          ],
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: borderColor,
          ),
        ),
        actions: [
          // Theme Toggle Button (Dark / Light)
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: textPrimary,
              size: 20,
            ),
            tooltip: isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
            onPressed: () => ThemeService.instance.toggleTheme(),
          ),

          // Delete all history button
          if (_history.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.delete_sweep_rounded,
                color: isDark ? Colors.white54 : Colors.black45,
                size: 22,
              ),
              tooltip: 'Clear all history',
              onPressed: _showClearHistoryDialog,
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),

            // Scan Action Card (Monochrome Hero)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Top Header inside card
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                                border: Border.all(color: borderColor, width: 1),
                              ),
                              child: Icon(
                                Icons.qr_code_scanner_rounded,
                                size: 28,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SCAN QR CODE',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Instantly scan web links or text',
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Action Buttons: Camera & Gallery
                        Row(
                          children: [
                            // Button 1: Camera (Primary)
                            Expanded(
                              flex: 3,
                              child: GestureDetector(
                                onTap: _startScanning,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white : Colors.black,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.camera_alt_rounded,
                                        size: 16,
                                        color: isDark ? Colors.black : Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Open Camera',
                                        style: TextStyle(
                                          color: isDark ? Colors.black : Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Button 2: Gallery (Secondary)
                            Expanded(
                              flex: 2,
                              child: GestureDetector(
                                onTap: _pickAndScanGallery,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderColor, width: 1.2),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.image_outlined,
                                        size: 16,
                                        color: textPrimary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Gallery',
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // History Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Text(
                    'SCAN HISTORY',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: borderColor,
                    ),
                  ),
                  if (_history.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF222222) : const Color(0xFFECECEC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor, width: 0.8),
                      ),
                      child: Text(
                        '${_history.length}',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Search Bar (if history has items)
            if (_history.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141414) : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search title or link...',
                      hintStyle: TextStyle(color: textSecondary, fontSize: 12),
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: textSecondary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close_rounded, size: 16, color: textSecondary),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 10),

            // History List
            Expanded(
              child: _isLoading
                  ? Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(textPrimary),
                        ),
                      ),
                    )
                  : filtered.isEmpty
                      ? _buildEmptyState(isDark: isDark, isSearching: _searchQuery.isNotEmpty)
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _buildHistoryCard(
                              item: filtered[index],
                              index: index,
                              isDark: isDark,
                              cardColor: cardColor,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /// History Card with Web Header on Top and Link below!
  Widget _buildHistoryCard({
    required ScanItem item,
    required int index,
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final isWebUrl = WebMetadataService.isWebUrl(item.url);
    final headerTitle = WebMetadataService.extractHeader(item.url, item.title);

    // Determine type tag
    String typeTag = 'TEXT';
    Color tagColor = textSecondary;
    if (item.url.trim().toLowerCase().startsWith('https://')) {
      typeTag = 'HTTPS';
      tagColor = const Color(0xFF10B981);
    } else if (item.url.trim().toLowerCase().startsWith('http://')) {
      typeTag = 'HTTP';
      tagColor = const Color(0xFFF59E0B);
    } else if (isWebUrl) {
      typeTag = 'WEB';
      tagColor = textSecondary;
    } else if (item.url.trim().toUpperCase().startsWith('WIFI:')) {
      typeTag = 'WI-FI';
      tagColor = textSecondary;
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showItemLinkPreview(item),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── 1. WEBSITE HEADER (TOP ROW) ──────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF222222) : const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor, width: 0.8),
                      ),
                      child: Icon(
                        isWebUrl ? Icons.language_rounded : Icons.notes_rounded,
                        size: 15,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Website / Page Header (TOP)
                    Expanded(
                      child: Text(
                        headerTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Tag Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: tagColor.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        typeTag,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: tagColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ─── 2. LINK BELOW (MIDDLE ROW) ───────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.link_rounded,
                        size: 13,
                        color: textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF333333),
                            fontSize: 11.5,
                            fontFamily: 'monospace',
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // ─── 3. BOTTOM ROW: TIME & QUICK ACTION BUTTONS ───────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Date & Time
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateTime(item.timestamp),
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),

                    // Quick Actions: Copy, Open, Delete
                    Row(
                      children: [
                        // Copy Button
                        _QuickIconButton(
                          icon: Icons.copy_rounded,
                          tooltip: 'Copy Link',
                          isDark: isDark,
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: item.url));
                            _showSnackBar('Link copied to clipboard');
                          },
                        ),
                        const SizedBox(width: 4),

                        // Open in Browser Button (if URL)
                        if (isWebUrl) ...[
                          _QuickIconButton(
                            icon: Icons.open_in_browser_rounded,
                            tooltip: 'Open Link',
                            isDark: isDark,
                            onTap: () => _launchURL(item.url),
                          ),
                          const SizedBox(width: 4),
                        ],

                        // Delete Button
                        _QuickIconButton(
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'Delete Item',
                          isDark: isDark,
                          color: isDark ? Colors.white38 : Colors.black38,
                          onTap: () => _deleteItem(index),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showClearHistoryDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? const Color(0xFF181818) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFE2E2E2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Clear All History',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'All scan history will be permanently deleted from this device.',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontWeight: FontWeight.w600,
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
                        final success = await _storageService.clearHistory();
                        if (success) {
                          _showSnackBar('All history cleared.');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Clear All',
                        style: TextStyle(fontWeight: FontWeight.w700),
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

  Widget _buildEmptyState({required bool isDark, required bool isSearching}) {
    final textSecondary = isDark ? const Color(0xFF888888) : const Color(0xFF666666);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF181818) : const Color(0xFFF2F2F2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE2E2E2),
                  width: 1,
                ),
              ),
              child: Icon(
                isSearching ? Icons.search_off_rounded : Icons.history_rounded,
                size: 36,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isSearching ? 'No History Found' : 'No History Yet',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isSearching
                  ? 'Try using a different search keyword.'
                  : 'Scan your first QR code using the camera or gallery button above.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textSecondary,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quick action icon button helper ──────────────────────────────────────────

class _QuickIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isDark;
  final Color? color;

  const _QuickIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final defaultColor = isDark ? Colors.white70 : Colors.black87;
    final borderColor = isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE2E2E2);
    final bgColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEFEFEF);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor, width: 0.8),
          ),
          child: Icon(
            icon,
            size: 13,
            color: color ?? defaultColor,
          ),
        ),
      ),
    );
  }
}
