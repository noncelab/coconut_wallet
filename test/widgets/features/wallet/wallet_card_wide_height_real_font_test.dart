import 'dart:io';

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/model/wallet/wallet_appearance.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../mock/wallet_mock.dart';

Future<void> _load(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    loader.addFont(
      Future.value(ByteData.view(Uint8List.fromList(File('assets/fonts/$file').readAsBytesSync()).buffer)),
    );
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _load('Pretendard', ['Pretendard-Regular.ttf', 'Pretendard-Bold.ttf']);
    await _load('SpaceGrotesk', ['SpaceGrotesk-Regular.ttf', 'SpaceGrotesk-Bold.ttf']);
  });

  for (final scale in [1.0, 1.1, 1.3, 1.6, 2.0]) {
    testWidgets('real fonts: a wide card at its measured height fits its content at text scale $scale', (tester) async {
      final wallet = WalletMock.createSingleSigWalletItem(id: 1, name: '자녀 상속 지갑');
      double? height;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCoconutThemeData(),
          home: MediaQuery(
            data: MediaQueryData(size: const Size(390, 844), textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  height = WalletCard.wideHeightOf(context);
                  return Center(
                    child: SizedBox(
                      width: 358,
                      height: height,
                      child: WalletCard(
                        wallet: wallet,
                        appearance: WalletAppearance.of(wallet),
                        size: WalletCardSize.wide,
                        balanceDisplay: '0.1234 5678 BTC',
                        balanceAtEnd: true,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull, reason: 'height $height');
    });
  }
}
