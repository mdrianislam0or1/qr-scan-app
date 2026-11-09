import 'package:flutter_test/flutter_test.dart';
import 'package:qr_scan_app/main.dart';

void main() {
  testWidgets('App smoke test builds cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(const QrScanApp());
    expect(find.text('QR Secure Scanner'), findsOneWidget);
  });
}
