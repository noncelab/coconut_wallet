import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/send/select_wallet_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_item_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Wallet extends Fake implements WalletItemBase {
  _Wallet(this.id);
  @override
  final int id;
  @override
  String get name => 'Test wallet';
  @override
  WalletType get walletType => WalletType.singleSignature;
  @override
  WalletImportSource get walletImportSource => WalletImportSource.coconutVault;
  @override
  int get colorIndex => 0;
  @override
  int get iconIndex => 0;
  @override
  bool get hasLocalKey => false;
}

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  _Wallets(this.walletItemList);
  @override
  final List<WalletItemBase> walletItemList;
  @override
  Map<int, Balance> fetchWalletBalanceMap() => {};
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  _Preferences(this.walletOrder);
  @override
  final List<int> walletOrder;
}

void main() {
  for (final viewport in [const Size(375, 667), const Size(320, 568)]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final bottomInset in [0.0, 34.0]) {
        testWidgets('last wallet is fully visible and selectable: $viewport $scale inset=$bottomInset', (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = viewport;
          tester.view.padding = FakeViewPadding(bottom: bottomInset);
          tester.view.viewPadding = FakeViewPadding(bottom: bottomInset);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final wallets = List<WalletItemBase>.generate(8, _Wallet.new);
          final walletProvider = _Wallets(wallets);
          final preferences = _Preferences(wallets.reversed.map((wallet) => wallet.id).toList());
          addTearDown(walletProvider.dispose);
          addTearDown(preferences.dispose);
          int? confirmed;
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<WalletProvider>.value(value: walletProvider),
                ChangeNotifierProvider<PreferenceProvider>.value(value: preferences),
              ],
              child: MaterialApp(
                theme: buildCoconutThemeData(),
                home: Builder(
                  builder:
                      (context) => Scaffold(
                        body: TextButton(
                          onPressed:
                              () => CommonBottomSheets.showDraggableBottomSheet<void>(
                                context: context,
                                screenName: 'test-select-wallet',
                                childBuilder:
                                    (controller) => SelectWalletBottomSheet(
                                      walletId: wallets.last.id,
                                      scrollController: controller,
                                      currentUnit: BitcoinUnit.btc,
                                      showOnlyMfpWallets: false,
                                      onWalletChanged: (id) {
                                        confirmed = id;
                                        Navigator.pop(context);
                                      },
                                    ),
                              ),
                          child: const Text('Open selector'),
                        ),
                      ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open selector'));
          await tester.pumpAndSettle();
          final sheet = find.byType(SelectWalletBottomSheet);
          final button = find.descendant(of: sheet, matching: find.text(t.select));
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(confirmed, isNull);
          final scrollable = find.descendant(of: sheet, matching: find.byType(Scrollable));
          await tester.drag(scrollable, const Offset(0, -1500));
          await tester.pumpAndSettle();
          final card = find.descendant(
            of: sheet,
            matching: find.byWidgetPredicate(
              (widget) => widget is WalletItemCard && widget.walletItem.id == wallets.first.id,
            ),
          );
          await tester.scrollUntilVisible(card, 200, scrollable: scrollable);
          await tester.pumpAndSettle();
          final position = tester.state<ScrollableState>(scrollable).position;
          position.jumpTo(position.maxScrollExtent);
          await tester.pumpAndSettle();
          final cardRect = tester.getRect(card);
          final buttonControl = find.ancestor(of: button, matching: find.byType(ShrinkAnimationButton));
          final buttonRect = tester.getRect(buttonControl);
          expect(cardRect.top, greaterThanOrEqualTo(tester.getRect(scrollable).top));
          expect(cardRect.bottom, lessThanOrEqualTo(buttonRect.top - 12));
          expect(buttonRect.bottom, lessThan(viewport.height - bottomInset));
          expect(card.hitTestable(), findsOneWidget);
          expect(button.hitTestable(), findsOneWidget);
          await tester.tap(card);
          await tester.pumpAndSettle();
          expect(confirmed, isNull);
          expect(tester.getRect(buttonControl), buttonRect);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(confirmed, wallets.first.id);
          expect(sheet, findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
