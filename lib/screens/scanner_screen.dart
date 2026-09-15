import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/scan_result.dart';
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
      // Re-check permission if user returned from Settings
      Permission.camera.status.then((status) async {
        if (!mounted) return;
        setState(() {
          _cameraPermissionStatus = status;
        });
        if (status.isGranted && !_isScanCompleted) {
          try {
            await _controller.start();
          } catch (_) {}
        }
      });
    } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      try {
        _controller.stop();
      } catch (_) {}
    }
  }

  Future<void> _checkAndRequestPermission() async {
    setState(() {
      _isCheckingPermission = true;
    });

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

    // Security: Reject payloads that are unreasonably large (> 4096 chars)
    if (rawValue.length > 4096) {
      _showErrorSnackBar('QR code terlalu panjang dan tidak dapat diproses.');
      return;
    }

    setState(() {
      _isScanCompleted = true;
    });

    try {
      await _controller.stop();
    } catch (_) {}

    if (!mounted) return;

    final action = await LinkPreviewSheet.show(context, rawContent: rawValue);

    if (!mounted) return;

    if (action == LinkPreviewAction.open) {
      Navigator.of(context).pop(ScanResult(url: rawValue, shouldLaunch: true));
    } else if (action == LinkPreviewAction.copy) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
              SizedBox(width: 10),
              Text('Link berhasil disalin!', style: TextStyle(color: Colors.white)),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.of(context).pop(ScanResult(url: rawValue, shouldLaunch: false));
    } else {
      // Action rescan or modal dismissed -> resume camera
      try {
        await _controller.start();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _isScanCompleted = false;
        });
      }
    }
  }

  Future<void> _scanFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final BarcodeCapture? barcode = await _controller.analyzeImage(image.path);
      if (barcode != null && barcode.barcodes.isNotEmpty) {
        String? detectedValue;
        for (final b in barcode.barcodes) {
          final val = b.displayValue ?? b.rawValue;
          if (val != null && val.trim().isNotEmpty) {
            detectedValue = val.trim();
            break;
          }
        }

        if (detectedValue != null) {
          await _handleQrCodeDetected(detectedValue);
        } else {
          _showNoQrCodeSnackBar();
        }
      } else {
        _showNoQrCodeSnackBar();
      }
    } catch (e) {
      _showErrorSnackBar(e.toString());
    }
  }

  void _showNoQrCodeSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Tidak ada QR Code ditemukan dalam gambar ini.',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Error: $error',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
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
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.videocam_off_rounded,
                size: 48,
                color: Color(0xFF0EA5E9),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Izin Kamera Diperlukan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isPermanentlyDenied
                  ? 'Izin akses kamera telah ditolak secara permanen. Mohon aktifkan izin kamera melalui Pengaturan HP untuk mulai memindai QR Code.'
                  : 'Aplikasi membutuhkan izin akses kamera Anda untuk dapat memindai QR Code secara langsung.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: isPermanentlyDenied
                  ? () => openAppSettings()
                  : _checkAndRequestPermission,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              icon: Icon(
                isPermanentlyDenied ? Icons.settings_rounded : Icons.camera_alt_rounded,
                size: 18,
              ),
              label: Text(
                isPermanentlyDenied ? 'Buka Pengaturan HP' : 'Izinkan Akses Kamera',
                style: const TextStyle(fontWeight: FontWeight.w600),
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
    final scanWindowTop = (screenSize.height - scanWindowSize) / 2 - 40;
    final scanWindowRect = Rect.fromCenter(
      center: Offset(screenSize.width / 2, scanWindowTop + (scanWindowSize / 2)),
      width: scanWindowSize,
      height: scanWindowSize,
    );

    final isPermissionGranted = _cameraPermissionStatus == PermissionStatus.granted;
    final isPermanentlyDenied = _cameraPermissionStatus == PermissionStatus.permanentlyDenied;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'SCAN QR CODE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
          ),
        ),
        centerTitle: true,
        actions: [
          if (isPermissionGranted) ...[
            // Zoom toggle button
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, child) {
                final zoomScale = state.zoomScale;
                final isZoomed = zoomScale > 0.0;
                return IconButton(
                  icon: Icon(
                    isZoomed ? Icons.zoom_out_rounded : Icons.zoom_in_rounded,
                    color: isZoomed ? const Color(0xFF0EA5E9) : Colors.white70,
                  ),
                  tooltip: isZoomed ? 'Reset Zoom (1x)' : 'Zoom In (2x)',
                  onPressed: () {
                    _controller.setZoomScale(isZoomed ? 0.0 : 0.5);
                  },
                );
              },
            ),
            // Torch toggle button
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, child) {
                final isTorchOn = state.torchState == TorchState.on;
                return IconButton(
                  icon: Icon(
                    isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    color: isTorchOn ? const Color(0xFF0EA5E9) : Colors.white70,
                  ),
                  onPressed: () => _controller.toggleTorch(),
                );
              },
            ),
            // Camera switch button
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, child) {
                final isFront = state.cameraDirection == CameraFacing.front;
                return IconButton(
                  icon: Icon(
                    isFront ? Icons.camera_front_rounded : Icons.camera_rear_rounded,
                    color: Colors.white70,
                  ),
                  onPressed: () => _controller.switchCamera(),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Camera Preview or Permission State
          if (_isCheckingPermission)
            const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0EA5E9)),
              ),
            )
          else if (!isPermissionGranted)
            _buildPermissionDeniedUI(isPermanentlyDenied: isPermanentlyDenied)
          else
            MobileScanner(
              controller: _controller,
              errorBuilder: (context, error) {
                final errorMessage = error.errorDetails?.message ?? error.errorCode.name;
                return Center(
                  child: Container(
                    margin: const EdgeInsets.all(32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.videocam_off_rounded,
                          size: 48,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Kamera Tidak Tersedia',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.errorCode == MobileScannerErrorCode.permissionDenied
                              ? 'Izin akses kamera ditolak. Mohon aktifkan izin kamera di Pengaturan HP Anda.'
                              : 'Gagal menginisialisasi kamera ($errorMessage).',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => _controller.start(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0EA5E9),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Coba Lagi'),
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

          // Custom High-Performance Cutout Mask (Path.combine prevents GPU black screen)
          if (isPermissionGranted)
            Positioned.fill(
              child: CustomPaint(
                painter: _ScannerOverlayPainter(
                  scanWindow: scanWindowRect,
                  borderRadius: 24,
                  overlayColor: Colors.black.withValues(alpha: 0.65),
                ),
              ),
            ),

          // Corner Borders and Laser Scan Line Animation
          if (isPermissionGranted)
            Positioned(
              left: scanWindowRect.left,
              top: scanWindowRect.top,
              width: scanWindowSize,
              height: scanWindowSize,
              child: Stack(
                children: [
                  // Visual boundary line
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),

                  // Animated Scanning Laser Line
                  AnimatedBuilder(
                    animation: _scanLineAnimation,
                    builder: (context, child) {
                      final topOffset =
                          _scanLineAnimation.value * (scanWindowSize - 40) + 20;
                      return Positioned(
                        top: topOffset,
                        left: 20,
                        right: 20,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0EA5E9),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0EA5E9).withValues(alpha: 0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Outer stylish corner brackets
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ScannerFramePainter(
                        color: const Color(0xFF0EA5E9),
                        strokeWidth: 4,
                        borderRadius: 24,
                        cornerLength: 32,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Instruction Text below scan window
          if (isPermissionGranted)
            Positioned(
              top: scanWindowRect.bottom + 24,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'Arahkan QR code tepat di dalam bingkai',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),

          // Gallery Image Selection Button overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.photo_library_rounded,
                  color: Colors.white,
                ),
                tooltip: 'Scan dari Galeri',
                onPressed: _scanFromGallery,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for semi-transparent dark overlay with rounded transparent cutout.
/// Uses PathOperation.difference for full GPU / Impeller / Skia compatibility.
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

    final combinedPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    final paint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(combinedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.overlayColor != overlayColor;
  }
}

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

    // Top-left corner
    path.moveTo(0, cornerLength);
    path.lineTo(0, borderRadius);
    path.arcToPoint(
      Offset(borderRadius, 0),
      radius: Radius.circular(borderRadius),
      clockwise: true,
    );
    path.lineTo(cornerLength, 0);

    // Top-right corner
    path.moveTo(size.width - cornerLength, 0);
    path.lineTo(size.width - borderRadius, 0);
    path.arcToPoint(
      Offset(size.width, borderRadius),
      radius: Radius.circular(borderRadius),
      clockwise: true,
    );
    path.lineTo(size.width, cornerLength);

    // Bottom-right corner
    path.moveTo(size.width, size.height - cornerLength);
    path.lineTo(size.width, size.height - borderRadius);
    path.arcToPoint(
      Offset(size.width - borderRadius, size.height),
      radius: Radius.circular(borderRadius),
      clockwise: true,
    );
    path.lineTo(size.width - cornerLength, size.height);

    // Bottom-left corner
    path.moveTo(cornerLength, size.height);
    path.lineTo(borderRadius, size.height);
    path.arcToPoint(
      Offset(0, size.height - borderRadius),
      radius: Radius.circular(borderRadius),
      clockwise: true,
    );
    path.lineTo(0, size.height - cornerLength);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerFramePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.cornerLength != cornerLength;
  }
}
