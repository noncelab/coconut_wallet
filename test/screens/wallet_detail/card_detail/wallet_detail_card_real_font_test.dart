import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/wallet/wallet_appearance.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/screens/wallet_detail/card_detail/wallet_detail_card_carousel.dart';
import 'package:coconut_wallet/widgets/common/amount/animated_balance.dart';
import 'package:coconut_wallet/widgets/common/amount/fiat_price.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../mock/wallet_mock.dart';

class _Prices extends Fake with ChangeNotifier implements PriceProvider {
  @override
  String getFiatPrice(int satoshiAmount, {FiatCode? fiatCode, bool showCurrencySymbol = true}) => '₩ 12,345';
}

class _Connectivity extends Fake with ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isInternetOn => true;
}

Rect _paintedRect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
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

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final unit in BitcoinUnit.values) {
        for (final balance in [10000000, 123456789]) {
          final scenario = 'width-$width-scale-$scale-${unit.name}-$balance';
          testWidgets('real detail card fits $scenario', (tester) async {
            tester.view.physicalSize = Size(width, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final capture = GlobalKey();
            final wallet = WalletMock.createSingleSigWalletItem(name: '지갑 Wallet');
            final pressed = <String>[];
            final actions = WalletDetailCardAction.standard(
              hasBalance: true,
              onReceive: () => pressed.add('receive'),
              onSend: () => pressed.add('send'),
              onOrganize: () => pressed.add('organize'),
              onChart: () => pressed.add('chart'),
            );
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<PriceProvider>.value(value: _Prices()),
                  ChangeNotifierProvider<ConnectivityProvider>.value(value: _Connectivity()),
                ],
                child: MaterialApp(
                  theme: buildCoconutThemeData(),
                  home: MediaQuery(
                    data: MediaQueryData(size: Size(width, 800), textScaler: TextScaler.linear(scale)),
                    child: Scaffold(
                      body: RepaintBoundary(
                        key: capture,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: WalletDetailCardCarousel(
                            wallets: [wallet],
                            initialIndex: 0,
                            onFocusChanged: (_) {},
                            cardBuilder:
                                (_, wallet, focused) => WalletDetailCard(
                                  wallet: wallet,
                                  appearance: WalletAppearance.of(wallet),
                                  balance: balance,
                                  unit: unit,
                                  actions: actions,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            final exceptions = <String>[];
            final firstException = tester.takeException();
            if (firstException != null) exceptions.add(firstException.toString());
            await tester.pumpAndSettle();
            final nextException = tester.takeException();
            if (nextException != null) exceptions.add(nextException.toString());
            final card = find.byType(WalletDetailCard);
            final amount = find.descendant(of: find.byType(AnimatedBalance), matching: find.byType(Text));
            final fiat = find.descendant(of: find.byType(FiatPrice), matching: find.byType(Text));
            final cardRect = _paintedRect(tester, card);
            final amountRect = _paintedRect(tester, amount);
            final fiatRect = _paintedRect(tester, fiat);
            final evidence = Platform.environment['DETAIL_FONT_EVIDENCE_DIR'];
            if (evidence != null) {
              final directory = Directory(evidence)..createSync(recursive: true);
              File('${directory.path}/$scenario.json').writeAsStringSync(
                jsonEncode({
                  'scenario': scenario,
                  'frameworkErrors': exceptions,
                  'card': cardRect.toString(),
                  'amount': amountRect.toString(),
                  'fiat': fiatRect.toString(),
                  'amountText': tester.widget<Text>(amount).data,
                  'fiatText': tester.widget<Text>(fiat).data,
                  'actionSizes': [for (final action in actions) tester.getSize(find.byKey(action.key)).toString()],
                }),
              );
              await tester.runAsync(() async {
                final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(capture));
                final image = await boundary.toImage();
                final png = await image.toByteData(format: ui.ImageByteFormat.png);
                File('${directory.path}/$scenario.png').writeAsBytesSync(png!.buffer.asUint8List());
                image.dispose();
              });
            }
            expect(exceptions, isEmpty, reason: scenario);
            expect(tester.widget<Text>(amount).data, unit.displayBitcoinAmount(balance));
            expect(tester.widget<Text>(fiat).data, '₩ 12,345');
            expect(MediaQuery.textScalerOf(tester.element(amount)).scale(28), closeTo(28 * scale, 0.01));
            for (final rect in [amountRect, fiatRect]) {
              expect(rect.left, greaterThanOrEqualTo(cardRect.left));
              expect(rect.right, lessThanOrEqualTo(cardRect.right));
              expect(rect.top, greaterThanOrEqualTo(cardRect.top));
              expect(rect.bottom, lessThanOrEqualTo(cardRect.bottom));
            }
            expect(amountRect.bottom, lessThanOrEqualTo(fiatRect.top));
            for (final action in actions) {
              final button = find.byKey(action.key);
              expect(tester.getSize(button).width, greaterThanOrEqualTo(44));
              expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
              expect(fiatRect.bottom, lessThanOrEqualTo(_paintedRect(tester, button).top));
              await tester.tap(button);
              await tester.pumpAndSettle();
            }
            expect(pressed, ['receive', 'send', 'organize', 'chart']);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }
}
