import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:coconut_wallet/providers/view_model/home/home_view_model.dart';
import 'package:coconut_wallet/screens/home/widget_configure_sheet.dart';
import 'package:flutter/widgets.dart';

/// All Features 검색에서 홈 구성과 관계없이 공통 가짜 잔액 설정을 연다.
Future<void> openFakeBalanceFromSearch(BuildContext context, HomeViewModel viewModel) async {
  await WidgetConfigureSheet.openSettings(
    context,
    heading: t.wallet_home_screen.edit.fake_balance.fake_balance_display,
    title: t.wallet_home_screen.edit.fake_balance.fake_balance_setting,
    spec: const HomeWidgetSettingsSpec(fakeBalance: true),
    wallets: viewModel.wallets,
    initial: const HomeWidgetSettings(),
    compactFakeBalance: true,
  );
}
