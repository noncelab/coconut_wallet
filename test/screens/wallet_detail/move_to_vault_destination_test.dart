import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/wallet_detail/move_to_vault_bottom_sheets.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/widgets/common/text/icon_title_description.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no balance takes priority over every watch-only wallet count', () {
    for (final count in [0, 1, 2, 3]) {
      expect(resolveMoveToVaultDestination(0, count), MoveToVaultDestination.noBalance);
    }
  });
  test('positive balance without watch-only wallets shows the add-wallet sheet', () {
    expect(resolveMoveToVaultDestination(1, 0), MoveToVaultDestination.noWatchOnlyWallet);
  });
  test('two or more watch-only wallets show the selection sheet', () {
    for (final count in [2, 3]) {
      expect(resolveMoveToVaultDestination(1, count), MoveToVaultDestination.selectWatchOnlyWallet);
    }
  });
  test('positive balance with exactly one watch-only wallet shows the selection sheet', () {
    expect(resolveMoveToVaultDestination(1, 1), MoveToVaultDestination.selectWatchOnlyWallet);
  });

  testWidgets('vault guide separates registration from balance viewing in every supported language', (tester) async {
    final previousLocale = LocaleSettings.currentLocale;
    addTearDown(() => LocaleSettings.setLocaleSync(previousLocale));
    final descriptions = {
      for (final locale in AppLocale.values)
        locale: locale.translations.wallet_detail_screen.vault_watch_only_description,
    };
    expect(descriptions[AppLocale.ko], '‘보기 전용 지갑’을 등록해 보세요.\n키를 노출하지 않고도 앱에서 금고 속 비트코인 잔액을 확인할 수 있어요.');
    expect(descriptions.values.toSet(), hasLength(AppLocale.values.length));
    for (final entry in descriptions.entries) {
      expect(entry.value.split('\n'), [isNotEmpty, isNotEmpty], reason: entry.key.languageCode);
      LocaleSettings.setLocaleSync(entry.key);
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(entry.key),
          theme: buildCoconutThemeData(),
          home: const Scaffold(body: ShowVaultNoWatchOnlyWalletBottomSheet(walletId: 1)),
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(find.text(entry.value)).text;
      expect(paragraph.toPlainText(), entry.value);
      expect(
        paragraph.toPlainText(includeSemanticsLabels: false),
        entry.key == AppLocale.ko ? TextUtils.preventLineBreakInsideWords(entry.value) : entry.value,
      );
    }
  });

  for (final variant in CoconutThemeVariant.values) {
    testWidgets('vault guide icons use the primary icon color in ${variant.name}', (tester) async {
      final expected = ColorFilter.mode(
        resolveCoconutThemeExtension(variant: variant).colors.iconPrimary,
        BlendMode.srcIn,
      );
      for (final sheet in const [
        ShowVaultNoBalanceBottomSheet(walletId: 1),
        ShowVaultNoWatchOnlyWalletBottomSheet(walletId: 1),
      ]) {
        await tester.pumpWidget(
          MaterialApp(theme: buildCoconutThemeData(variant: variant), home: Scaffold(body: sheet)),
        );
        final icons = find.descendant(of: find.byType(IconTitleDescription), matching: find.byType(SvgPicture));
        expect(tester.widgetList<SvgPicture>(icons).map((icon) => icon.colorFilter), [expected, expected]);
      }
    });
  }

  for (final hasBalance in [false, true]) {
    testWidgets('vault instructions align and scroll above the action with balance: $hasBalance', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCoconutThemeData(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SizedBox(
                width: 320,
                height: 400,
                child:
                    hasBalance
                        ? const ShowVaultNoWatchOnlyWalletBottomSheet(walletId: 1)
                        : const ShowVaultNoBalanceBottomSheet(walletId: 1),
              ),
            ),
          ),
        ),
      );
      final strings = t.wallet_detail_screen;
      final title = hasBalance ? strings.vault_watch_only_title : strings.vault_no_balance_title;
      final description = hasBalance ? strings.vault_watch_only_description : strings.vault_no_balance_description;
      expect(tester.getTopLeft(find.text(title)).dx, tester.getTopLeft(find.text(strings.vault_intro)).dx);
      expect(tester.getTopLeft(find.text(description)).dx, tester.getTopLeft(find.text(strings.vault_description)).dx);
      expect(tester.renderObject<RenderParagraph>(find.text(description)).textAlign, TextAlign.start);

      final action = find.text(hasBalance ? strings.vault_connect_watch_only_wallet : t.receive);
      final actionRect = tester.getRect(action.hitTestable());
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable)).position;
      expect(scroll.maxScrollExtent, greaterThan(0));
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pump();
      expect(tester.getBottomLeft(find.text(description)).dy, lessThan(actionRect.top));
      expect(tester.getRect(action.hitTestable()), actionRect);
    });
  }
}
