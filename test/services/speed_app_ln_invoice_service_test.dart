import 'package:coconut_wallet/services/speed_app_ln_invoice_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final SpeedAppLnInvoiceService invoiceService = SpeedAppLnInvoiceService();

  group('SpeedAppLnInvoiceService', () {
    test('라이트닝 인보이스 주소 얻기', () async {
      const amounts = [1000, 5000, 10000, 30000, 50000, 100000, 1000000, 3000000, 5000000];
      for (var amount in amounts) {
        final invoice = await invoiceService.getLnInvoiceOfPow(amount);
        expect(invoice.startsWith("lnbc"), true);
      }
    });

    test('잘못된 amount 지정한 경우 exception', () async {
      const amounts = [-100000, -50000, -10000, -5000, -3000, -1000, 0, 600000000000, 800000000000, 1000000000000];
      for (var amount in amounts) {
        expect(() => invoiceService.getLnInvoiceOfPow(amount), throwsException);
      }
    });
  });
}
