import 'package:coconut_wallet/widgets/animated_qr/animated_qr_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

void main() {
  group('AnimatedQrScanner', () {
    late Function(QRViewController) mockSetQRViewController;
    late Function(String) mockOnComplete;
    late Function(String) mockOnFailed;

    setUp(() {
      mockSetQRViewController = (QRViewController controller) {};
      mockOnComplete = (String result) {};
      mockOnFailed = (String error) {};
    });

    testWidgets('rendering test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedQrScanner(
              setQRViewController: mockSetQRViewController,
              onComplete: mockOnComplete,
              onFailed: mockOnFailed,
            ),
          ),
        ),
      );

      expect(find.byType(QRView), findsOneWidget);
    });
  });
}
