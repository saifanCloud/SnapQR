import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/scan_result.dart';
import '../services/qr_image_decoder.dart';
import '../widgets/link_preview_sheet.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final MobileScannerController _controller;
  final ImagePicker _picker = ImagePicker();
  late AnimationController _animationController;
  late Animation<double> _scanLineAnimation;
  bool _isScanCompleted = false;
  bool _isProcessingGallery = false;
  bool _isAnalyzing = false;

  PermissionStatus? _cameraPermissionStatus;
  bool _isCheckingPermission = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.normal,
      autoStart: false,
    );

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _checkAndRequestPermission();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (_isProcessingGallery) return;
      Permission.camera.status.then((status) async {
        if (!mounted || _isProcessingGallery) return;
        setState(() => _cameraPermissionStatus = status);
        if (status.isGranted && !_isScanCompleted) {
          try {
            await _controller.start();
          } catch (_) {}
        }
      });
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      try {
        _controller.stop();
      } catch (_) {}
    }
  }

  Future<void> _checkAndRequestPermission() async {
    setState(() => _isCheckingPermission = true);
    var status = await Permission.camera.status;
    if (!status.isGranted && !status.isPermanentlyDenied) {
      status = await Permission.camera.request();
    }
    if (!mounted) return;
    setState(() {
      _cameraPermissionStatus = status;
      _isCheckingPermission = false;
    });
    if (status.isGranted) {
      try {
        await _controller.start();
      } catch (_) {}
    }
  }

  Future<void> _handleQrCodeDetected(String rawValue) async {
    if (_isScanCompleted) return;

    // Security: reject oversized payloads
    if (rawValue.length > 4096) {
      _showSnackBar('QR code terlalu panjang.', isError: true);
      return;
    }

    setState(() => _isScanCompleted = true);
    try {
      await _controller.stop();
    } catch (_) {}
    if (!mounted) return;

    final action = await LinkPreviewSheet.show(context, rawContent: rawValue);
    if (!mounted) return;

    if (action == LinkPreviewAction.open) {
      Navigator.of(context).pop(ScanResult(url: rawValue, shouldLaunch: true));
    } else if (action == LinkPreviewAction.copy) {
      _showSnackBar('Link berhasil disalin!');
      Navigator.of(context).pop(ScanResult(url: rawValue, shouldLaunch: false));
    } else {
      try {
        await _controller.start();
      } catch (_) {}
      if (mounted) setState(() => _isScanCompleted = false);
    }
  }

  Future<void> _scanFromGallery() async {
    if (_isProcessingGallery || _isAnalyzing) return;

    setState(() => _isProcessingGallery = true);

    // Hentikan kamera live agar resource kamera tidak bentrok
    try {
      await _controller.stop();
    } catch (_) {}

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );

      if (image == null) {
        // Pengguna membatalkan pemilihan gambar
        _isProcessingGallery = false;
        if (mounted && !_isScanCompleted && _cameraPermissionStatus == PermissionStatus.granted) {
          try {
            await _controller.start();
          } catch (_) {}
        }
        return;
      }

      if (mounted) {
        setState(() => _isAnalyzing = true);
      }

      String? detectedValue;

      if (kIsWeb) {
        // Platform Web: Dekode byte gambar menggunakan QrImageDecoder (zxing2)
        try {
          final bytes = await image.readAsBytes();
          detectedValue = QrImageDecoder.decodeBytes(bytes);
        } catch (e) {
          debugPrint('Web QR decode error: $e');
        }
      } else {
        // Platform Native (Android/iOS): Coba ML Kit terlebih dahulu
        try {
          final BarcodeCapture? barcode = await _controller.analyzeImage(image.path);
          if (barcode != null && barcode.barcodes.isNotEmpty) {
            for (final b in barcode.barcodes) {
              final val = b.displayValue ?? b.rawValue;
              if (val != null && val.trim().isNotEmpty) {
                detectedValue = val.trim();
                break;
              }
            }
          }
        } catch (e) {
          debugPrint('Mobile ML Kit analyzeImage error: $e');
        }

        // Fallback jika ML Kit tidak mendeteksi: gunakan pure Dart decoder
        if (detectedValue == null || detectedValue.isEmpty) {
          try {
            final bytes = await image.readAsBytes();
            detectedValue = QrImageDecoder.decodeBytes(bytes);
          } catch (e) {
            debugPrint('Mobile fallback decode error: $e');
          }
        }
      }

      if (mounted) {
        setState(() => _isAnalyzing = false);
      }

      if (detectedValue != null && detectedValue.trim().isNotEmpty) {
        _isProcessingGallery = false;
        await _handleQrCodeDetected(detectedValue.trim());
        return;
      }

      _showSnackBar('Tidak ada QR Code ditemukan dalam gambar ini.');
    } catch (e) {
      debugPrint('Error memindai gambar dari galeri: $e');
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
      _showSnackBar('Gagal membaca gambar. Pastikan gambar jelas.', isError: true);
    } finally {
      _isProcessingGallery = false;
      if (mounted && !_isScanCompleted && _cameraPermissionStatus == PermissionStatus.granted) {
        try {
          await _controller.start();
        } catch (_) {}
      }
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
              size: 15,
              color: isError
                  ? const Color(0xFFEF4444)
                  : Colors.white.withValues(alpha: 0.6),
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
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Widget _buildPermissionDeniedUI({required bool isPermanentlyDenied}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.videocam_off_rounded,
                size: 36,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Akses Kamera Diperlukan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isPermanentlyDenied
                  ? 'Izin kamera ditolak secara permanen. Buka Pengaturan HP untuk mengaktifkannya.'
                  : 'Aplikasi membutuhkan akses kamera untuk memindai QR Code.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.40),
                fontSize: 13,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: isPermanentlyDenied
                  ? () => openAppSettings()
                  : _checkAndRequestPermission,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Text(
                  isPermanentlyDenied ? 'Buka Pengaturan' : 'Izinkan Akses Kamera',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final scanWindowSize = screenSize.width * 0.65;
    final scanWindowTop =
        (screenSize.height - scanWindowSize) / 2 - 40;
    final scanWindowRect = Rect.fromCenter(
      center: Offset(
          screenSize.width / 2, scanWindowTop + (scanWindowSize / 2)),
      width: scanWindowSize,
      height: scanWindowSize,
    );

    final isPermissionGranted =
        _cameraPermissionStatus == PermissionStatus.granted;
    final isPermanentlyDenied =
        _cameraPermissionStatus == PermissionStatus.permanentlyDenied;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
        title: const Text(
          'SCAN QR',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 3.0,
          ),
        ),
        centerTitle: true,
        actions: [
          if (isPermissionGranted) ...[
            // Zoom
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, child) {
                final isZoomed = state.zoomScale > 0.0;
                return _buildAppBarAction(
                  icon: isZoomed
                      ? Icons.zoom_out_rounded
                      : Icons.zoom_in_rounded,
                  isActive: isZoomed,
                  onTap: () =>
                      _controller.setZoomScale(isZoomed ? 0.0 : 0.5),
                );
              },
            ),
            // Torch
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, child) {
                final isTorchOn = state.torchState == TorchState.on;
                return _buildAppBarAction(
                  icon: isTorchOn
                      ? Icons.flash_on_rounded
                      : Icons.flash_off_rounded,
                  isActive: isTorchOn,
                  onTap: () => _controller.toggleTorch(),
                );
              },
            ),
          ],
          // Gallery (selalu dapat diakses)
          _buildAppBarAction(
            icon: Icons.photo_library_outlined,
            isActive: _isProcessingGallery,
            onTap: _scanFromGallery,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          // Camera or permission state
          if (_isCheckingPermission)
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white54),
                ),
              ),
            )
          else if (!isPermissionGranted)
            _buildPermissionDeniedUI(
                isPermanentlyDenied: isPermanentlyDenied)
          else
            MobileScanner(
              controller: _controller,
              errorBuilder: (context, error) {
                final msg = error.errorCode == MobileScannerErrorCode.permissionDenied
                    ? 'Izin kamera ditolak.'
                    : 'Kamera tidak tersedia.';
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam_off_rounded,
                            size: 36,
                            color: Colors.white.withValues(alpha: 0.3)),
                        const SizedBox(height: 14),
                        Text(
                          msg,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () => _controller.start(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.12)),
                            ),
                            child: const Text(
                              'Coba Lagi',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              onDetect: (BarcodeCapture capture) {
                if (_isScanCompleted) return;
                for (final barcode in capture.barcodes) {
                  final value = barcode.displayValue ?? barcode.rawValue;
                  if (value != null && value.trim().isNotEmpty) {
                    _handleQrCodeDetected(value.trim());
                    break;
                  }
                }
              },
            ),

          // Overlay mask (dark surround)
          if (isPermissionGranted)
            Positioned.fill(
              child: CustomPaint(
                painter: _ScannerOverlayPainter(
                  scanWindow: scanWindowRect,
                  borderRadius: 20,
                  overlayColor: Colors.black.withValues(alpha: 0.72),
                ),
              ),
            ),

          // Frame + laser
          if (isPermissionGranted)
            Positioned(
              left: scanWindowRect.left,
              top: scanWindowRect.top,
              width: scanWindowSize,
              height: scanWindowSize,
              child: Stack(
                children: [
                  // Subtle border
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),

                  // Laser line
                  AnimatedBuilder(
                    animation: _scanLineAnimation,
                    builder: (context, child) {
                      final top =
                          _scanLineAnimation.value * (scanWindowSize - 48) +
                              24;
                      return Positioned(
                        top: top,
                        left: 18,
                        right: 18,
                        child: Container(
                          height: 1.5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.6),
                                Colors.white.withValues(alpha: 0.85),
                                Colors.white.withValues(alpha: 0.6),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Corner brackets
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ScannerFramePainter(
                        color: Colors.white.withValues(alpha: 0.75),
                        strokeWidth: 2.5,
                        borderRadius: 20,
                        cornerLength: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Instruction label
          if (isPermissionGranted)
            Positioned(
              top: scanWindowRect.bottom + 22,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Arahkan QR code ke dalam bingkai',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.40),
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),

          // Loading overlay saat analisis gambar galeri berlangsung
          if (_isAnalyzing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.70),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Menganalisis gambar...',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.80),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBarAction({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6, top: 10, bottom: 10),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.07),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: isActive ? 0.20 : 0.09),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size: 17,
          color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

// ─── Overlay Painter ───────────────────────────────────────────────────────────

class _ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;
  final double borderRadius;
  final Color overlayColor;

  const _ScannerOverlayPainter({
    required this.scanWindow,
    required this.borderRadius,
    required this.overlayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          scanWindow,
          Radius.circular(borderRadius),
        ),
      );

    final combined = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    canvas.drawPath(combined, Paint()..color = overlayColor);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter old) =>
      old.scanWindow != scanWindow ||
      old.borderRadius != borderRadius ||
      old.overlayColor != overlayColor;
}

// ─── Frame Painter ─────────────────────────────────────────────────────────────

class _ScannerFramePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double borderRadius;
  final double cornerLength;

  _ScannerFramePainter({
    required this.color,
    required this.strokeWidth,
    required this.borderRadius,
    required this.cornerLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    // Top-left
    path.moveTo(0, cornerLength);
    path.lineTo(0, borderRadius);
    path.arcToPoint(Offset(borderRadius, 0),
        radius: Radius.circular(borderRadius), clockwise: true);
    path.lineTo(cornerLength, 0);

    // Top-right
    path.moveTo(size.width - cornerLength, 0);
    path.lineTo(size.width - borderRadius, 0);
    path.arcToPoint(Offset(size.width, borderRadius),
        radius: Radius.circular(borderRadius), clockwise: true);
    path.lineTo(size.width, cornerLength);

    // Bottom-right
    path.moveTo(size.width, size.height - cornerLength);
    path.lineTo(size.width, size.height - borderRadius);
    path.arcToPoint(Offset(size.width - borderRadius, size.height),
        radius: Radius.circular(borderRadius), clockwise: true);
    path.lineTo(size.width - cornerLength, size.height);

    // Bottom-left
    path.moveTo(cornerLength, size.height);
    path.lineTo(borderRadius, size.height);
    path.arcToPoint(Offset(0, size.height - borderRadius),
        radius: Radius.circular(borderRadius), clockwise: true);
    path.lineTo(0, size.height - cornerLength);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerFramePainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.borderRadius != borderRadius ||
      old.cornerLength != cornerLength;
}
