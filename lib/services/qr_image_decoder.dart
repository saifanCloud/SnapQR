import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

class QrImageDecoder {
  /// Decode QR Code from raw image bytes.
  /// Works across all platforms including Flutter Web and Android.
  static String? decodeBytes(Uint8List bytes) {
    try {
      final img.Image? decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) return null;

      // Downscale if image is excessively large to keep decoding fast and within memory bounds
      img.Image processedImage = decodedImage;
      if (processedImage.width > 1200 || processedImage.height > 1200) {
        processedImage = img.copyResize(
          processedImage,
          width: processedImage.width > processedImage.height ? 1200 : null,
          height: processedImage.height >= processedImage.width ? 1200 : null,
          interpolation: img.Interpolation.linear,
        );
      }

      // Convert to 4-channel ABGR pixel buffer
      final converted = processedImage.convert(numChannels: 4);
      final int32List = converted
          .getBytes(order: img.ChannelOrder.abgr)
          .buffer
          .asInt32List();

      final source = RGBLuminanceSource(
        processedImage.width,
        processedImage.height,
        int32List,
      );

      // Attempt 1: HybridBinarizer (standard ZXing adaptive binarizer)
      try {
        final bitmap = BinaryBitmap(HybridBinarizer(source));
        final result = QRCodeReader().decode(bitmap);
        if (result.text.isNotEmpty) return result.text;
      } catch (_) {}

      // Attempt 2: GlobalHistogramBinarizer (fallback for high/flat contrast)
      try {
        final bitmap = BinaryBitmap(GlobalHistogramBinarizer(source));
        final result = QRCodeReader().decode(bitmap);
        if (result.text.isNotEmpty) return result.text;
      } catch (_) {}

      return null;
    } catch (e) {
      debugPrint('QrImageDecoder error: $e');
      return null;
    }
  }
}
