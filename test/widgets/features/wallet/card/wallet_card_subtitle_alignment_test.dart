import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_appearance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart' show kHomeWidgetHeaderHeight;
import 'package:coconut_wallet/widgets/features/home/widgets/wallet_widget_views.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../mock/wallet_mock.dart';

void main() {
  setUpAll(() async {
    for (final family in ['Pretendard', 'SpaceGrotesk']) {
      final loader = FontLoader(family);
      for (final weight in ['Regular', 'Bold']) {
        loader.addFont(rootBundle.load('assets/fonts/$family-$weight.ttf'));
      }
      await loader.load();
    }
  });

  for (final home in [false, true]) {
    for (final edge in [138.0, 179.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final secondary in [null, '2 days ago']) {
          for (final balance in ['21.0000 0000 BTC', '2 100 000 000 sats', null]) {
            final boundedDifference = home && edge == 138 && scale == 2 && secondary == null;
            testWidgets(
              '${boundedDifference ? 'bounded subtitle difference' : 'small subtitle alignment'} with real fonts: '
              'home=$home edge=$edge scale=$scale secondary=$secondary balance=$balance',
              (tester) async {
                final withMfp = WalletMock.createSingleSigWalletItem(id: 1, name: '가족의 장기 저축 지갑');
                final body = withMfp.descriptor.split('#').first.replaceFirst('D45AA182', '00000000');
                final withoutMfp = SinglesigWalletItem(
                  id: 2,
                  name: '공개키로 가져온 보기 전용 지갑',
                  colorIndex: 0,
                  iconIndex: 0,
                  descriptor: '$body#${Checksum.getChecksum(body)}',
                );
                final multisig = WalletMock.createMultiSigWalletItem(id: 3, name: '다중서명 가족 공동 지갑');
                final wallets = [withMfp, withoutMfp, multisig];
                Future<void> pump({bool develop = false}) async {
                  await tester.pumpWidget(
                    MaterialApp(
                      theme: buildCoconutThemeData(),
                      home: MediaQuery(
                        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                        child: Scaffold(
                          body: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final wallet in wallets)
                                  SizedBox.square(
                                    dimension: edge,
                                    child:
                                        develop && boundedDifference && wallet == multisig
                                            ? const SizedBox.shrink()
                                            : develop
                                            ? _developSmallCard(
                                              wallet,
                                              tappable: !home,
                                              subtitle:
                                                  wallet == withMfp
                                                      ? 'D45A A182'
                                                      : wallet == multisig
                                                      ? '2/3'
                                                      : null,
                                              subtitleKey:
                                                  wallet == multisig ? 'wallet-card-quorum' : 'wallet-card-mfp',
                                              balance: balance,
                                              secondary: secondary,
                                            )
                                            : home
                                            ? WalletStackView(
                                              keyPrefix: 'alignment-${wallet.id}',
                                              wallets: [wallet],
                                              size: WalletCardSize.small,
                                              emptyText: 'empty',
                                              balanceTextOf: (_) => balance,
                                              secondaryTextOf: (_) => secondary,
                                            )
                                            : WalletCard(
                                              wallet: wallet,
                                              appearance: WalletAppearance.of(wallet),
                                              size: WalletCardSize.small,
                                              balanceDisplay: balance,
                                              secondaryText: secondary,
                                              onPressed: () {},
                                            ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                  await tester.pumpAndSettle();
                  expect(tester.takeException(), isNull);
                }

                List<Rect> subtitleCardRects() => [
                  for (final index in boundedDifference ? [0] : [0, 2]) ...[
                    tester.getRect(find.text(wallets[index].name)),
                    tester.getRect(find.byKey(Key(index == 0 ? 'wallet-card-mfp' : 'wallet-card-quorum'))),
                    if (balance != null) tester.getRect(find.byKey(const Key('wallet-card-balance')).at(index)),
                  ],
                ];
                List<Rect>? baseline;
                if (edge == 179 || scale < 2 || boundedDifference) {
                  await pump(develop: true);
                  baseline = subtitleCardRects();
                }
                await pump();
                if (baseline != null) {
                  final actual = subtitleCardRects();
                  for (var index = 0; index < baseline.length; index++) {
                    expect(
                      actual[index],
                      rectMoreOrLessEquals(baseline[index], epsilon: .01),
                      reason: 'subtitle cards must retain develop 5dc819af6 geometry (rect $index)',
                    );
                  }
                }
                final cards = find.byType(WalletCard);
                expect(cards, findsNWidgets(3));
                final names = [for (final wallet in wallets) tester.getRect(find.text(wallet.name))];
                // At 138px/2x without secondary text, only the width-fitted MFP still fits on develop.
                // Keep its geometry; missing subtitles and quorum share the constrained natural line instead.
                final alignedIndex = boundedDifference ? 1 : 0;
                for (final name in names.skip(alignedIndex + 1)) {
                  expect(name.top, closeTo(names[alignedIndex].top, .01));
                  expect(name.bottom, closeTo(names[alignedIndex].bottom, .01));
                }
                if (boundedDifference) {
                  expect(tester.getSize(find.byKey(const Key('wallet-card-mfp'))).height, closeTo(34, .01));
                  expect(tester.getRect(find.byKey(const Key('wallet-card-mfp'))).height, closeTo(29.9465, .01));
                  expect(names[1].top - names[0].top, closeTo(balance == null ? -1.0535 : 14.4465, .01));
                }
                if (balance != null) {
                  final balances = find.byKey(const Key('wallet-card-balance'));
                  expect(balances, findsNWidgets(3));
                  final first = tester.getRect(balances.at(alignedIndex));
                  for (var index = 0; index < 3; index++) {
                    final rect = tester.getRect(balances.at(index));
                    if (index >= alignedIndex) {
                      expect(rect.top, closeTo(first.top, .01));
                      expect(rect.bottom, closeTo(first.bottom, .01));
                    }
                    expect(rect.height, greaterThan(0));
                    expect(rect.bottom, lessThanOrEqualTo(names[index].top));
                    expect(tester.renderObject<RenderParagraph>(balances.at(index)).didExceedMaxLines, isFalse);
                  }
                }
                expect(find.byKey(const Key('wallet-card-mfp')), findsOneWidget);
                expect(find.byKey(const Key('wallet-card-quorum')), findsOneWidget);
                for (var index = 0; index < 3; index++) {
                  final card = tester.getRect(cards.at(index));
                  final texts = find.descendant(of: cards.at(index), matching: find.byType(Text));
                  for (final element in texts.evaluate()) {
                    final rect = tester.getRect(find.byWidget(element.widget));
                    expect(rect.left, greaterThanOrEqualTo(card.left));
                    expect(rect.right, lessThanOrEqualTo(card.right));
                    expect(rect.top, greaterThanOrEqualTo(card.top));
                    expect(rect.bottom, lessThanOrEqualTo(card.bottom));
                  }
                }
                await tester.pumpWidget(const SizedBox.shrink());
                expect(tester.takeException(), isNull);
              },
            );
          }
        }
      }
    }
  }
}

// Small-card layout from develop 5dc819af6, kept independent of WalletCard's new height calculation.
Widget _developSmallCard(
  WalletItemBase wallet, {
  required bool tappable,
  required String? subtitle,
  required String subtitleKey,
  required String? balance,
  required String? secondary,
}) => Builder(
  builder: (context) {
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WalletCard.iconOf(wallet, WalletAppearance.of(wallet)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      constraints: const BoxConstraints(minHeight: kHomeWidgetHeaderHeight),
                      alignment: Alignment.centerRight,
                      child: FittedBox(fit: BoxFit.scaleDown, child: WalletCard.typeLabelOf(wallet)),
                    ),
                    if (secondary != null)
                      Text(
                        secondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: CoconutTypography.body3_12_Bold.copyWith(
                          color: context.coconutColors.primaryText,
                          height: 1,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (balance != null)
            Expanded(
              child: Align(
                alignment: const Alignment(-1, 0.2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    balance,
                    key: const Key('wallet-card-balance'),
                    style: CoconutTypography.heading4_18_NumberBold.copyWith(color: context.coconutColors.primaryText),
                  ),
                ),
              ),
            )
          else
            const Spacer(),
          Text(
            wallet.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CoconutTypography.body2_14_Bold.copyWith(color: context.coconutColors.primaryText),
          ),
          if (subtitle != null)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                subtitle,
                key: Key(subtitleKey),
                maxLines: 1,
                style: CoconutTypography.body3_12_Number.copyWith(color: context.coconutColors.secondaryTextStrong),
              ),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
    return tappable ? ShrinkAnimationButton(onPressed: () {}, child: SizedBox.expand(child: content)) : content;
  },
);
