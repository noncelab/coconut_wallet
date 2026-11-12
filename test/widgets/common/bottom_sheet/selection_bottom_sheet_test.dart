import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/widgets/common/bottom_sheet/selectable_settings_row.dart';
import 'package:coconut_wallet/widgets/common/bottom_sheet/selection_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 통화 시트처럼 긴 목록을 끝까지 내려도 마지막 줄이 아래 시스템 영역 위에 있다.
  // 0: 시스템 영역 없음, 24: 제스처 탐색 막대, 48: Android 3버튼 탐색 막대
  for (final inset in [0.0, 24.0, 48.0]) {
    testWidgets('the last row ends above a ${inset.toInt()} px bottom inset', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(bottom: inset);
      tester.view.viewPadding = FakeViewPadding(bottom: inset);
      addTearDown(tester.view.reset);
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildCoconutThemeData(),
          home: SelectionBottomSheet<int>(
            title: 'title',
            selectedValue: 0,
            scrollController: controller,
            showAppBar: false,
            items: [
              for (var i = 0; i < 44; i++)
                SelectionItem<int>(title: 'row $i', subtitle: 'name', value: i, onTap: () {}),
            ],
          ),
        ),
      );
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();

      final last = tester.getRect(find.ancestor(of: find.text('row 43'), matching: find.byType(SelectableSettingsRow)));
      expect(last.bottom, lessThanOrEqualTo(780 - inset));
    });
  }
}
