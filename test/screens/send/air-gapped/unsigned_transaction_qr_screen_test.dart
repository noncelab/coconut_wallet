import 'dart:convert';

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/air-gapped/unsigned_transaction_qr_view_model.dart';
import 'package:coconut_wallet/screens/send/air-gapped/unsigned_transaction_qr_screen.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  String get language => 'th';
}

/// [source] 지갑의 서명 요청 QR 화면을 태국어로 열고 위쪽 안내 글을 돌려준다.
Future<String> _thaiGuide(WidgetTester tester, WalletImportSource source, {bool isMultisig = false}) async {
  LocaleSettings.setLocaleSync(AppLocale.th);
  addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final sendInfo =
      SendInfoProvider()
        // QR에 담기만 하므로 실제 거래가 아니어도 된다
        ..setTxWaitingForSign(base64Encode(List.filled(96, 7)))
        ..setIsMultisig(isMultisig)
        ..setWalletImportSource(source);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<SendInfoProvider>.value(value: sendInfo),
        ChangeNotifierProvider<PreferenceProvider>(create: (_) => _Preferences()),
      ],
      child: MaterialApp(theme: buildCoconutThemeData(), home: const UnsignedTransactionQrScreen(walletName: 'Daily')),
    ),
  );
  await tester.pump();

  final guides =
      tester
          .widgetList<RichText>(find.descendant(of: find.byType(CoconutToolTip), matching: find.byType(RichText)))
          .map((richText) => richText.text.toPlainText())
          .toList();
  expect(guides, hasLength(1));
  // 화면이 QR을 넘기는 타이머를 스스로 멈추지 않는다(Coldcard). 테스트가 끝나기 전에 멈추고 화면을 내린다
  tester.element(find.byType(Scaffold)).read<UnsignedTransactionQrViewModel>().stopBbqrTimer();
  await tester.pumpWidget(const SizedBox());
  return guides.single;
}

/// 코드가 조각 사이에 넣는 공백·쉼표가 조각의 것과 겹치지 않았는지 본다(줄 앞뒤 공백은 따지지 않는다).
void _expectCleanJoins(String guide) {
  for (final line in guide.split('\n')) {
    expect(line.trim(), isNot(matches(RegExp(r' {2,}|,\s*,|\s,'))), reason: '"$line"');
  }
}

// 안내 글은 코드가 번역 조각과 쉼표·공백을 이어 붙여 만든다. 태국어 조각이 그 자리에 맞는지 화면에 나온 글로 본다
void main() {
  for (final isMultisig in [false, true]) {
    testWidgets('Thai vault guide (${isMultisig ? 'multisig' : 'single sig'}) is one sentence with single spaces', (
      tester,
    ) async {
      final guide = await _thaiGuide(tester, WalletImportSource.coconutVault, isMultisig: isMultisig);
      final tip = t.tooltip.unsigned_tx_qr;
      final menu = isMultisig ? t.sign_multisig : t.sign;

      expect(
        guide,
        "${tip.open_vault}, ${tip.select_wallet(name: 'Daily')}, ${tip.select_menu(menu: "'$menu'")}, "
        '${tip.scan_qr_below}',
      );
      _expectCleanJoins(guide);
    });
  }

  testWidgets('Thai hardware wallet guides have no doubled spaces and say "select" before the menu name', (
    tester,
  ) async {
    for (final source in [
      WalletImportSource.seedSigner,
      WalletImportSource.keystone,
      WalletImportSource.passport,
      WalletImportSource.jade,
      WalletImportSource.coldCard,
      WalletImportSource.krux,
    ]) {
      final guide = await _thaiGuide(tester, source);
      _expectCleanJoins(guide);

      final guides = t.unsigned_tx_qr_screen;
      final selectThenMenu = switch (source) {
        WalletImportSource.seedSigner => '${guides.guide_seedsigner.step1_end} ${guides.guide_seedsigner.step1_em}',
        WalletImportSource.keystone => '${guides.guide_keystone.step1_end} ${guides.guide_keystone.step1_em}',
        WalletImportSource.passport => '${guides.guide_passport.step1_end} ${guides.guide_passport.step1_em}',
        WalletImportSource.jade => '${guides.guide_jade.step1_end} ${guides.guide_jade.step1_em}',
        WalletImportSource.krux => '${guides.guide_krux.select} ${guides.guide_krux.step1_em}',
        _ => guides.guide_coldcard.step1_em,
      };
      expect(guide, contains(selectThenMenu), reason: source.name);
    }
  });
}
