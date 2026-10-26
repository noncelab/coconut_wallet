import 'dart:io';

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/wallet_widget_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('real fonts: four wallets fit the 4x2 tile at the largest tile text scale', (tester) async {
    for (final height in [140.0, 148.0, 156.0, 164.0, 172.0, 190.0]) {
      for (final scale in [1.0, kHomeTileMaxTextScale]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildCoconutThemeData(),
            home: MediaQuery(
              data: MediaQueryData(size: const Size(800, 800), textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: height * 2 + 12,
                    height: height,
                    child: BalanceByWalletView(
                      shares: [
                        for (var i = 0; i < 4; i++)
                          HomeBalanceShare(walletId: i + 1, name: 'Wallet ${i + 1}', balance: 1000 + i, colorIndex: i),
                      ],
                      total: const HomeAmount('0.0012', 'BTC'),
                      amountText: (sats) => '0.0000$sats',
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: 'height $height, text scale $scale');
      }
    }
  });
}
