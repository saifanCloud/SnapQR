import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_scanner/main.dart';
import 'package:cloud_scanner/models/scan_item.dart';
import 'package:cloud_scanner/services/web_metadata_service.dart';
import 'package:cloud_scanner/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WebMetadataService Tests', () {
    test('extracts clean header for known web domains', () {
      expect(WebMetadataService.extractHeader('https://github.com/flutter/flutter'), equals('GitHub'));
      expect(WebMetadataService.extractHeader('https://www.google.com/search?q=test'), equals('Google'));
      expect(WebMetadataService.extractHeader('https://youtube.com/watch?v=123'), equals('YouTube'));
      expect(WebMetadataService.extractHeader('https://tokopedia.com/product/1'), equals('Tokopedia'));
    });

    test('extracts clean header for general websites', () {
      expect(WebMetadataService.extractHeader('https://example.com/test'), equals('Example.com'));
    });

    test('extracts clean header for special QR schemes', () {
      expect(WebMetadataService.extractHeader('WIFI:S:HomeWifi;T:WPA;P:secret;;'), equals('Wi-Fi: HomeWifi'));
      expect(WebMetadataService.extractHeader('mailto:hello@example.com'), equals('Email: hello@example.com'));
      expect(WebMetadataService.extractHeader('tel:+628123456789'), equals('Phone: +628123456789'));
      expect(WebMetadataService.extractHeader('Good morning everyone'), equals('Text / Note'));
    });

    test('prioritizes saved title when available', () {
      expect(
        WebMetadataService.extractHeader('https://github.com', 'GitHub: Where the world builds software'),
        equals('GitHub: Where the world builds software'),
      );
    });
  });

  group('ScanItem Serialization Tests', () {
    test('serializes and deserializes title correctly', () {
      final item = ScanItem(
        url: 'https://flutter.dev',
        timestamp: DateTime(2026, 10, 1, 20, 0),
        title: 'Flutter Dev',
      );

      final json = item.toJson();
      expect(json['title'], equals('Flutter Dev'));
      expect(json['url'], equals('https://flutter.dev'));

      final restored = ScanItem.fromJson(json);
      expect(restored.title, equals('Flutter Dev'));
      expect(restored.url, equals('https://flutter.dev'));
    });
  });

  group('ThemeService Tests', () {
    test('toggles theme between dark and light', () async {
      await ThemeService.instance.init();
      final initial = ThemeService.instance.isDarkMode;

      await ThemeService.instance.toggleTheme();
      expect(ThemeService.instance.isDarkMode, isNot(initial));

      await ThemeService.instance.toggleTheme();
      expect(ThemeService.instance.isDarkMode, equals(initial));
    });
  });

  testWidgets('App boots and renders properly', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('FAST & SECURE SCANNER'), findsOneWidget);

    // Advance past splash screen
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('SNAPQR'), findsOneWidget);
    expect(find.text('SCAN QR CODE'), findsOneWidget);
  });
}

