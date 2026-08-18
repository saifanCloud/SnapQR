import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../models/scan_result.dart';
import '../widgets/link_preview_sheet.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
  );
  final ImagePicker _picker = ImagePicker();
  late AnimationController _animationController;
  late Animation<double> _scanLineAnimation;
  bool _isScanCompleted = false;

  Future<void> _handleQrCodeDetected(String rawValue) async {
    if (_isScanCompleted) return;
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
        final rawValue = barcode.barcodes.first.rawValue;
        if (rawValue != null && rawValue.isNotEmpty) {
          await _handleQrCodeDetected(rawValue);
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
          'No QR Code found in this image.',
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
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scanWindowSize = MediaQuery.of(context).size.width * 0.65;
    final scanWindowOffset = (MediaQuery.of(context).size.height - scanWindowSize) / 2 - 40;

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
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Camera Preview
          MobileScanner(
            controller: _controller,
            onDetect: (BarcodeCapture capture) {
              if (_isScanCompleted) return;

              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final rawValue = barcodes.first.rawValue;
                if (rawValue != null && rawValue.isNotEmpty) {
                  _handleQrCodeDetected(rawValue);
                }
              }
            },
          ),

          // Custom Semi-transparent Dark Mask Overlay
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.65),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Align(
                    alignment: const Alignment(0, -0.1),
                    child: Container(
                      width: scanWindowSize,
                      height: scanWindowSize,
                      decoration: BoxDecoration(
                        color: Colors.red, // Any color to punch the cutout
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Corner Borders and Laser Scan Line Animation
          Align(
            alignment: const Alignment(0, -0.1),
            child: SizedBox(
              width: scanWindowSize,
              height: scanWindowSize,
              child: Stack(
                children: [
                  // Visual boundary line
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF0EA5E9).withOpacity(0.3),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),

                  // Animated Scanning Laser Line
                  AnimatedBuilder(
                    animation: _scanLineAnimation,
                    builder: (context, child) {
                      final topOffset = _scanLineAnimation.value * (scanWindowSize - 40) + 20;
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
                                color: const Color(0xFF0EA5E9).withOpacity(0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Outer brackets (custom painter for stylish corners)
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
          ),

          // Instruction Text below scan window
          Positioned(
            top: scanWindowOffset + scanWindowSize + 40,
            left: 20,
            right: 20,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'Align QR code within the frame to scan',
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
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.photo_library_rounded,
                  color: Colors.white,
                ),
                tooltip: 'Scan from Gallery',
                onPressed: _scanFromGallery,
              ),
            ),
          ),
        ],
      ),
    );
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
