import 'package:coconut_wallet/widgets/features/home/widgets/activity_widget_views.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recent transactions show three rows unless told otherwise', () {
    expect(RecentTransactionsView.defaultRows, 3);
  });

  test('monochrome icons fade the translucent circle fill toward the card but keep solid lines', () {
    expect(monochromeIconAlpha(1), 1);
    expect(monochromeIconAlpha(0.2), lessThan(0.2));
    expect(monochromeIconAlpha(0.2), greaterThan(0));
    expect(monochromeIconAlpha(0.1), lessThan(0.1));
    expect(monochromeIconAlpha(0), 0);
  });
}
