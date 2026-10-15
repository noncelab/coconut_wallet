import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/widgets/common/buttons/bottom_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('long action labels wrap and grow beyond the default height', (tester) async {
    const label = 'In den Tresor übertragen';
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 100,
              child: BottomActionButton(
                iconPath: FeatureWalletIconPath.vault,
                label: label,
                labelMaxLines: null,
                buttonLayout: BottomActionButtonLayout.horizontal,
                textStyle: const TextStyle(fontSize: 14, height: 1.5),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final labelSize = tester.getSize(find.text(label));
    expect(labelSize.height, greaterThan(BottomActionButton.horizontalHeight));
    expect(tester.getSize(find.byType(BottomActionButton)).height, greaterThanOrEqualTo(labelSize.height));
    expect(tester.takeException(), isNull);
  });
}
