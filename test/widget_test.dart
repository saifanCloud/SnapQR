import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_scanner/main.dart';

void main() {
  testWidgets('App smoke test - verifies app boots and navigates to HomeScreen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that title is rendered during splash screen.
    expect(find.text('CLOUD SCANNER'), findsWidgets);

    // Advance time past the splash timer (2 seconds) and page transition (600ms)
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 700));

    // Verify that HomeScreen is reached and SCAN QR CODE button is present
    expect(find.text('SCAN QR CODE'), findsOneWidget);
  });
}
