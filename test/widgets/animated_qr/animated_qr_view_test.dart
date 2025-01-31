import 'package:coconut_wallet/widgets/animated_qr/animated_qr_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  group('AnimatedQrView', () {
    const List<String> testData = [
      "QR Code 1",
      "QR Code 2",
      "QR Code 3",
    ];
    const double qrSize = 200.0;
    const int milliSeconds = 500;

    testWidgets('rendering test', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnimatedQrView(
            data: testData,
            size: qrSize,
            milliSeconds: milliSeconds,
          ),
        ),
      );

      // QrImageView 위젯이 존재하는지 확인
      expect(find.byType(QrImageView), findsOneWidget);
    });
  });
}
