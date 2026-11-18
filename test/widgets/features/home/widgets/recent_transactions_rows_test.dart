import 'package:coconut_wallet/widgets/features/home/widgets/activity_widget_views.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recent transactions show three rows unless told otherwise', () {
    expect(RecentTransactionsView.defaultRows, 3);
  });
}
