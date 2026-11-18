import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_add/hot_wallet_restore_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_add/hot_wallet/hot_wallet_restore_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Wallets extends Fake implements WalletProvider {
  @override
  List<WalletItemBase> get walletItemList => const [];
}

class _Preferences extends Fake implements PreferenceProvider {
  @override
  String get language => 'ko';
}

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  Future<void> open(WidgetTester tester, {MnemonicOnlyRestore? mnemonicOnly}) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          InheritedProvider<WalletProvider>.value(value: _Wallets()),
          InheritedProvider<PreferenceProvider>.value(value: _Preferences()),
          Provider<AnalyticsService>.value(value: AnalyticsService(null, true)),
        ],
        child: MaterialApp(theme: buildCoconutThemeData(), home: HotWalletRestoreScreen(mnemonicOnly: mnemonicOnly)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterWords(WidgetTester tester, List<String> words) async {
    for (var i = 0; i < words.length; i++) {
      await tester.enterText(find.byType(EditableText).at(i), words[i]);
      await tester.pump();
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  FixedBottomButton button(WidgetTester tester) => tester.widget<FixedBottomButton>(find.byType(FixedBottomButton));

  testWidgets('without the option the passphrase and name sections stay', (tester) async {
    await open(tester);

    expect(find.text(t.wallet_home_screen.hot_wallet_create.use_passphrase), findsOneWidget);
    expect(find.text(t.wallet_home_screen.hot_wallet_create.wallet_name), findsOneWidget);
  });

  testWidgets('words only: no passphrase or name, twelve fields and the caller copy', (tester) async {
    await open(tester, mnemonicOnly: MnemonicOnlyRestore(title: '복원 제목', submitLabel: '복원 버튼', onSubmit: (_) async {}));

    expect(find.text(t.wallet_home_screen.hot_wallet_create.use_passphrase), findsNothing);
    expect(find.text(t.wallet_home_screen.hot_wallet_create.wallet_name), findsNothing);
    expect(find.text(t.wallet_home_screen.hot_wallet_create.word_count(count: 12)), findsNothing);
    expect(find.text('복원 제목'), findsOneWidget);
    expect(button(tester).text, '복원 버튼');
  });

  testWidgets('words only: valid words go to the caller', (tester) async {
    String? submitted;
    await open(
      tester,
      mnemonicOnly: MnemonicOnlyRestore(
        title: '복원',
        submitLabel: '단어로 복원',
        onSubmit: (Uint8List mnemonic) async => submitted = utf8.decode(mnemonic),
      ),
    );
    final words = [...List.filled(11, 'abandon'), 'about'];

    await enterWords(tester, words);
    expect(button(tester).isActive, isTrue);
    await tester.tap(find.text('단어로 복원'));
    await tester.pumpAndSettle();

    expect(submitted, words.join(' '));
  });

  testWidgets('words only: a bad checksum keeps the button off', (tester) async {
    await open(tester, mnemonicOnly: MnemonicOnlyRestore(title: '복원', submitLabel: '복원', onSubmit: (_) async {}));

    await enterWords(tester, List.filled(12, 'abandon'));

    expect(button(tester).isActive, isFalse);
  });

  test('a scanned 24-word SeedQR counts as 24 words', () {
    final viewModel = HotWalletRestoreViewModel();
    viewModel.setScannedMnemonic(Uint8List.fromList(utf8.encode(List.filled(24, 'abandon').join(' '))), 24);

    expect(viewModel.mnemonicWordCount, 24);
  });
}
