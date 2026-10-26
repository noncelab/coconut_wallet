import 'dart:async';
import 'dart:io';

import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_edit_bottom_sheet.dart';
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/wallet/icon/icon_palette_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Wallet extends Fake implements WalletItemBase {
  @override
  String get name => 'Fixture wallet';
  @override
  String get descriptor => 'public-fixture';
  @override
  int get iconIndex => 0;
  @override
  int get colorIndex => 0;
}

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  @override
  WalletItemBase getWalletById(int id) => _Wallet();
}

void main() {
  setUpAll(() async {
    for (final family in ['Pretendard', 'SpaceGrotesk']) {
      final loader = FontLoader(family);
      for (final weight in ['Regular', 'Bold']) {
        loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$family-$weight.ttf').readAsBytesSync())));
      }
      await loader.load();
    }
  });
  for (final variant in CoconutThemeVariant.values) {
    for (final palette in [false, true]) {
      for (final keyboard in [false, true]) {
        testWidgets('$variant actual wallet edit footer German 2x palette=$palette keyboard=$keyboard', (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(344.38, 746.21);
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 54);
          tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 54);
          addTearDown(tester.view.reset);
          final locale = LocaleSettings.currentLocale;
          LocaleSettings.setLocaleSync(AppLocale.de);
          addTearDown(() => LocaleSettings.setLocaleSync(locale));
          await tester.pumpWidget(
            ChangeNotifierProvider<WalletProvider>(
              create: (_) => _Wallets(),
              child: MaterialApp(
                theme: buildCoconutThemeData(variant: variant).copyWith(platform: TargetPlatform.android),
                builder:
                    (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: const TextScaler.linear(2), disableAnimations: true),
                      child: child!,
                    ),
                home: Scaffold(
                  body: Builder(
                    builder:
                        (context) => TextButton(
                          onPressed:
                              () => unawaited(
                                CommonBottomSheets.showBottomSheet_100<String>(
                                  context: context,
                                  screenName: AnalyticsScreenNames.walletInfoEditSheet,
                                  isDismissible: true,
                                  useSafeArea: false,
                                  backgroundColor: Colors.transparent,
                                  child: WalletInfoEditBottomSheet(
                                    id: 7,
                                    walletImportSource:
                                        palette
                                            ? WalletImportSource.coconutVault
                                            : WalletImportSource.extendedPublicKey,
                                    isCustomAccount: palette,
                                    isHotWallet: false,
                                  ),
                                ),
                              ),
                          child: const Text('open'),
                        ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          if (keyboard) {
            tester.widget<EditableText>(find.byType(EditableText)).focusNode.requestFocus();
            tester.view.viewInsets = const FakeViewPadding(bottom: 280);
            tester.view.padding = const FakeViewPadding(top: 24);
            await tester.pumpAndSettle();
          }
          final bodyScroll =
              find
                  .descendant(of: find.byType(WalletInfoEditBottomSheet), matching: find.byType(SingleChildScrollView))
                  .first;
          final scrollable = find.descendant(of: bodyScroll, matching: find.byType(Scrollable)).first;
          final position = tester.state<ScrollableState>(scrollable).position;
          position.jumpTo(position.maxScrollExtent);
          await tester.pumpAndSettle();
          final button = find.descendant(
            of: find.byType(FixedBottomButton),
            matching: find.byType(ShrinkAnimationButton),
          );
          final buttonRect = tester.getRect(button);
          final last = palette ? find.byType(IconPaletteCell).last : find.byType(CoconutTextField);
          final lastRect = tester.getRect(last);
          final padding = tester.widget<SingleChildScrollView>(bodyScroll).padding!.resolve(TextDirection.ltr).bottom;
          debugPrint(
            'WALLET_EDIT_FOOTER theme=${variant.name} palette=$palette keyboard=$keyboard label=${t.done} button=$buttonRect last=$lastRect reserved=$padding scroll=${position.maxScrollExtent}',
          );
          expect(tester.takeException(), isNull);
          expect(find.text('Fertig'), findsOneWidget);
          expect(buttonRect.height, lessThan(padding - FixedBottomButton.fixedBottomButtonDefaultBottomPadding));
          expect(padding, greaterThan(buttonRect.height + FixedBottomButton.fixedBottomButtonDefaultBottomPadding));
          if (!palette || !keyboard) {
            expect(lastRect.bottom, lessThanOrEqualTo(buttonRect.top));
          } else {
            expect(lastRect.bottom, greaterThan(746.21 - 280));
          }
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
}
