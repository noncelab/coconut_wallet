import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/rescue_ready_provider.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/premium/premium_paywall_screen.dart';
import 'package:coconut_wallet/screens/safety/assist/assist_move_screens.dart' show AssistSignerGuideScreen;
import 'package:coconut_wallet/screens/safety/rescue/rescue_ready_screen.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:coconut_wallet/services/safety/sweep_builder.dart';
import 'package:coconut_wallet/services/safety/wallet_verification.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../services/safety/safety_fakes.dart';

const _attackTxid = 'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1';
const _external = 'bcrt1qxa3vg30kvqsd73knsv0dj8z26jx223chv8fzcx';

Uint8List _entropy(int seed) => Uint8List.fromList(List.filled(16, seed));

SinglesigWalletItem _single(int id, int seed, {bool hot = false}) {
  final vault = SingleSignatureVault.fromEntropy(_entropy(seed));
  return SinglesigWalletItem(
    id: id,
    name: 'w$id',
    colorIndex: 0,
    iconIndex: 0,
    descriptor: vault.descriptor,
    hotWalletMetadata:
        hot
            ? HotWalletMetadata(
              walletId: id,
              secureStorageKey: 'k$id',
              masterFingerprint: vault.keyStore.masterFingerprint,
              derivationPath: vault.derivationPath,
              accountIndex: 0,
              backupVerified: true,
              enterPassphraseWhenSigning: false,
              createdAt: DateTime(2026, 10, 1),
            )
            : null,
  );
}

SinglesigWalletItem _withoutMfp(int id, int seed) {
  final xpub = SingleSignatureVault.fromEntropy(_entropy(seed)).keyStore.extendedPublicKey.serialize();
  final wallet = SingleSignatureWallet.fromExtendedPublicKey(
    AddressType.p2wpkh,
    xpub,
    WalletAddService.masterFingerprintPlaceholder,
  );
  return SinglesigWalletItem(id: id, name: 'w$id', colorIndex: 0, iconIndex: 0, descriptor: wallet.descriptor);
}

class _Wallets extends SafetyWalletsFake {
  _Wallets(super.wallets);

  /// 주소 → 그 주소를 가진 지갑들(같은 디스크립터를 핫·보기 전용으로 둘 다 가질 수 있다)
  final owners = <String, Set<int>>{};

  @override
  WalletAddress getReceiveAddress(int walletId) => throw StateError('no generated address');

  @override
  int? findWalletIdContainingAddress(String address) => owners[address]?.first;

  @override
  bool containsAddress(int walletId, String address, {bool? isChange}) => owners[address]?.contains(walletId) ?? false;
}

/// 지금 이동은 Safety Assist 흐름(Track H)이 맡는다. 화면은 부르기만 하는지 본다
class _Rescue extends RescueReadyProvider {
  _Rescue({required super.walletProvider, required super.nodeProvider, required super.entitlement, super.store})
    : super(fetchFees: () async => RecommendedFee(10, 10, 10, 10, 1));

  final moves = <int>[];

  /// 제외 지갑에서 도출된 주소(실제 도출은 isolate라 위젯 테스트의 가짜 시간에서 돌지 않는다. 규칙은 provider 테스트가 본다)
  final derivedFromExcluded = <String>{};

  /// 도출 확인 자체가 실패(isolate 오류 등)
  bool deriveFails = false;

  @override
  Future<void> moveNow(BuildContext context, int walletId) async => moves.add(walletId);

  @override
  Future<bool> derivesFromExcludedWallet(int walletId, String address) async {
    if (deriveFails) throw StateError('derive failed');
    return derivedFromExcluded.contains(address);
  }
}

/// 저장소에 쓴 뒤 알리는 SafetyProvider 흉내
class _Safety extends SafetyProvider {
  _Safety() : super.fixed(null);

  void ping() => notifyListeners();
}

void main() {
  setUpAll(() {
    NetworkType.setNetworkType(NetworkType.regtest);
    LocaleSettings.setLocaleSync(AppLocale.ko);
  });

  late _Wallets wallets;
  late SafetyNodeFake node;
  late SafetyStoreFake store;
  late FakeEntitlementService premium;
  late _Rescue rescue;
  late RescueDraftSummary draft;

  setUp(() {
    wallets = _Wallets([_single(1, 1, hot: true), _single(2, 2), _withoutMfp(4, 4), _single(6, 6, hot: true)]);
    wallets.balances[1] = Balance(150000, 0);
    node = SafetyNodeFake();
    store = SafetyStoreFake();
    draft = RescueDraftSummary(
      destinationAddress: _external,
      amount: 148590,
      fee: 1410,
      inputCount: 2,
      feeRate: 10,
      preparedAt: DateTime.now().subtract(const Duration(minutes: 3)),
    );
    store.state = SafetyState(
      rescue: {1: (destination: RescueDestination(walletId: 2, setAt: DateTime(2026, 10, 20)), draft: draft)},
    );
    premium = FakeEntitlementService(initial: const PremiumState(PremiumStatus.active));
  });

  tearDown(() {
    rescue.dispose();
    wallets.dispose();
    node.dispose();
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    CoconutThemeVariant variant, {
    int? walletId,
    SafetyState? safety,
    SafetyProvider? safetyProvider,
  }) async {
    // 목적지 시트의 모든 줄이 한 화면에 그려지게(ListView.builder는 화면 밖 줄을 만들지 않는다)
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    rescue = _Rescue(walletProvider: wallets, nodeProvider: node, entitlement: premium, store: store);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WalletProvider>.value(value: wallets),
          ChangeNotifierProvider<RescueReadyProvider>.value(value: rescue),
          Provider<EntitlementService>.value(value: premium),
          if (safety != null || safetyProvider != null)
            ChangeNotifierProvider<SafetyProvider>.value(
              value: safetyProvider ?? SafetyProvider.fixed(null, state: safety),
            ),
        ],
        child: MaterialApp(theme: buildCoconutThemeData(variant: variant), home: RescueReadyScreen(walletId: walletId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Text textOf(WidgetTester tester, Finder finder) => tester.widget<Text>(finder);

  /// 단어 이음 문자(R1, U+2060)를 빼면 [text]와 같은 글. 공용 부품(SafetyChoiceRow·주소 시트·검증 줄)이 이음 문자를
  /// 넣는지와 무관하게 찾는다. 이 화면이 직접 넣는 R1은 따로 정확히 본다
  Finder plainText(String text) => find.byWidgetPredicate((w) => w is Text && w.data?.replaceAll('\u2060', '') == text);
  Finder plainTextContaining(String text) =>
      find.byWidgetPredicate((w) => w is Text && (w.data?.replaceAll('\u2060', '').contains(text) ?? false));

  WatchOnlyVerification verification(
    WalletItemBase wallet,
    VerificationResult result, {
    String? descriptorHash,
    VerificationMethod method = VerificationMethod.qr,
  }) => WatchOnlyVerification(
    method: method,
    result: result,
    matchedIndex: 0,
    descriptorHash: descriptorHash ?? WalletVerification.descriptorHash(wallet.descriptor),
    at: DateTime(2026, 10, 20),
  );

  for (final variant in CoconutThemeVariant.values) {
    final colors = resolveCoconutThemeExtension(variant: variant).colors;

    group(variant.name, () {
      testWidgets('지갑마다 목적지·초안 상태 줄, 테마 색, 잔액 있는 지갑 먼저', (tester) async {
        await pumpScreen(tester, variant);
        final copy = t.premium.rescue;

        final scaffold = tester.widget<Scaffold>(find.byKey(const Key('rescue-ready-screen')));
        expect(scaffold.backgroundColor, colors.background);
        expect(textOf(tester, plainText(copy.wallets_title)).style!.color, colors.primaryText);
        expect(textOf(tester, plainText(copy.description)).style!.color, colors.secondaryText);
        expect(plainText(copy.on_device), findsOneWidget);
        // 이 화면이 직접 쓰는 한국어 글은 단어 중간에서 줄을 바꾸지 않는다(R1)
        for (final text in [copy.wallets_title, copy.description, copy.on_device]) {
          expect(textOf(tester, plainText(text)).data, safetyKoText(text));
        }

        // 모든 사용자에게 제목 위 Premium 칩
        expect(find.byType(PremiumChip), findsOneWidget);
        expect(
          tester.getBottomLeft(find.byType(PremiumChip)).dy,
          lessThan(tester.getTopLeft(plainText(copy.wallets_title)).dy),
        );

        // 상태 줄과 수수료 줄은 따로(숫자가 줄 사이로 갈리지 않게, POLISH I4)
        final row = find.byKey(const Key('rescue-wallet-1'));
        final ready = find.descendant(
          of: row,
          matching: plainText('→ w2 · ${copy.draft_ready(time: t.relative_time.minutes_ago(n: 3))}'),
        );
        expect(textOf(tester, ready).style!.color, colors.secondaryText);
        // 상태 글은 단어 중간 줄바꿈 금지(R1). 행은 keepWords: false라 이 화면이 부분마다 넣는다(다시 감싸도 같으면 적용된 것)
        final status = textOf(tester, ready).data!.split(' · ').last;
        expect(status, isNot(copy.draft_ready(time: t.relative_time.minutes_ago(n: 3))));
        expect(status, safetyKoText(status));
        final fee = find.descendant(
          of: row,
          matching: find.text('${t.estimated_fee} ${BitcoinUnit.btc.displayBitcoinAmount(1410, withUnit: true)}'),
        );
        expect(textOf(tester, fee).style!.color, colors.secondaryText);
        expect(find.ancestor(of: fee, matching: find.byType(FittedBox)), findsOneWidget);
        expect(tester.getTopLeft(fee).dy, greaterThan(tester.getBottomLeft(ready).dy));
        expect(
          find.descendant(of: find.byKey(const Key('rescue-wallet-6')), matching: plainText(copy.not_set)),
          findsOneWidget,
        );
        // 잔액 있는 w1이 맨 위
        expect(
          tester.getTopLeft(find.byKey(const Key('rescue-wallet-1'))).dy,
          lessThan(tester.getTopLeft(find.byKey(const Key('rescue-wallet-2'))).dy),
        );
        // 사고가 없으면 지금 이동은 보이지 않는다
        expect(find.byKey(const Key('rescue-move-now-1')), findsNothing);
        expect(find.byKey(const Key('rescue-premium-note')), findsNothing, reason: '구독 중에는 Premium 안내 없음');
      });

      testWidgets('행 → 목적지 시트(보기 전용 먼저, MFP 없음·이 기기 경고) → 저장', (tester) async {
        await pumpScreen(tester, variant);
        await tester.tap(find.byKey(const Key('rescue-wallet-6')));
        await tester.pumpAndSettle();

        final copy = t.premium.destination;
        expect(find.text(t.premium.rescue.destination), findsOneWidget);
        final ids = [
          for (final id in ['wallet:2', 'wallet:4', 'vault:new', 'address:new', 'wallet:1', 'hot:new'])
            tester.getTopLeft(find.byKey(Key('rescue-destination-$id'))).dy,
        ];
        expect(
          ids,
          [...ids]..sort(),
          reason: '보기 전용(MFP 있음) → MFP 없음 → 볼트 새 지갑 → 주소 입력 → 이 기기 지갑 → 이 기기 새 핫월렛(Assist 순서)',
        );
        expect(find.byKey(const Key('rescue-destination-off')), findsNothing, reason: '목적지가 없으면 끄기도 없다');
        expect(find.byKey(const Key('rescue-destination-premium-note')), findsNothing, reason: '구독 중에는 흐린 줄도 안내도 없다');
        expect(
          find.descendant(
            of: find.byKey(const Key('rescue-destination-wallet:4')),
            matching: plainText(copy.unknown_seed),
          ),
          findsOneWidget,
        );
        // 이 기기 경고: 이미 있는 핫월렛은 "이 지갑도", 새 핫월렛 줄은 "여기 만든 지갑도"(POLISH I9)
        for (final (id, text) in [
          ('wallet:1', copy.existing_hot_wallet_warning),
          ('hot:new', copy.new_hot_wallet_warning),
        ]) {
          final warning = find.descendant(of: find.byKey(Key('rescue-destination-$id')), matching: plainText(text));
          expect(textOf(tester, warning).style!.color, colors.warningText, reason: id);
        }

        await tester.tap(find.byKey(const Key('rescue-destination-wallet:2')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.premium.rescue.save));
        await tester.pumpAndSettle();
        expect(rescue.destinationOf(6)?.walletId, 2);
        expect(find.text(t.premium.rescue.saved_toast), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
      });

      testWidgets('주소 불일치 지갑은 목적지에서 빠지고, 정해 둔 목적지면 다시 정하라고 보인다. 검증된 지갑은 검증 날짜', (tester) async {
        store.state = store.state.copyWith(
          watchOnlyVerifications: {
            2: verification(wallets.walletItemList[1], VerificationResult.mismatch),
            4: verification(wallets.walletItemList[2], VerificationResult.match),
          },
        );
        await pumpScreen(tester, variant, safety: store.state);
        final invalid = find.descendant(
          of: find.byKey(const Key('rescue-wallet-1')),
          matching: plainText('→ w2 · ${t.premium.rescue.destination_invalid}'),
        );
        expect(textOf(tester, invalid).style!.color, colors.warningText);

        await tester.tap(find.byKey(const Key('rescue-wallet-6')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('rescue-destination-wallet:2')), findsNothing);
        final copy = t.premium.destination;
        final verified = find.descendant(
          of: find.byKey(const Key('rescue-destination-wallet:4')),
          matching: plainText(copy.verified_on(date: '26.10.20')),
        );
        expect(textOf(tester, verified).style!.color, colors.success, reason: 'H8: 확인됨은 success');
        for (final text in [copy.verified_on(date: '26.10.20'), copy.not_verified]) {
          expect(
            find.descendant(of: find.byKey(const Key('rescue-destination-wallet:1')), matching: plainText(text)),
            findsNothing,
            reason: '핫월렛은 서명 기기 검증 대상이 아니다',
          );
        }
      });

      testWidgets('지금 목적지는 미리 선택되고 끄기로 지울 수 있다', (tester) async {
        await pumpScreen(tester, variant);
        await tester.tap(find.byKey(const Key('rescue-wallet-1')));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(const Key('rescue-destination-wallet:2')),
            matching: find.text(t.premium.rescue.destination),
          ),
          findsOneWidget,
          reason: '비상 목적지 표시',
        );
        await tester.tap(find.byKey(const Key('rescue-destination-off')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.premium.rescue.save));
        await tester.pumpAndSettle();
        expect(rescue.destinationOf(1), isNull);
        expect(find.text(t.premium.rescue.turned_off_toast), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
      });

      testWidgets('주소 직접 입력: 네트워크·이 지갑 주소는 거절, 맞는 주소는 정규화해서 저장', (tester) async {
        final own = wallets.walletItemList.last.walletBase.getAddress(5);
        wallets.owners[own] = {6};
        await pumpScreen(tester, variant);
        await tester.tap(find.byKey(const Key('rescue-wallet-6')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('rescue-destination-address:new')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.premium.rescue.save));
        await tester.pumpAndSettle();

        final field = find.descendant(
          of: find.byKey(const Key('rescue-address-field')),
          matching: find.byType(EditableText),
        );
        await tester.enterText(field, 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq');
        await tester.pump();
        expect(plainText(AddressValidationError.notRegtestnetAddress.message), findsOneWidget);
        await tester.tap(find.byKey(const Key('rescue-address-save')));
        await tester.pumpAndSettle();
        expect(rescue.destinationOf(6), isNull, reason: '비활성 버튼');

        await tester.enterText(field, own);
        await tester.pump();
        expect(plainText(t.premium.destination.error_self_address), findsOneWidget);

        // 만들어 둔 주소 목록 밖이지만 이 지갑에서 나온 주소: 저장을 누를 때 걸러진다(Grok §5)
        final beyondGap = wallets.walletItemList.last.walletBase.getAddress(500);
        rescue.derivedFromExcluded.add(beyondGap);
        await tester.enterText(field, beyondGap);
        await tester.pump();
        await tester.tap(find.byKey(const Key('rescue-address-save')));
        await tester.pumpAndSettle();
        expect(plainText(t.premium.destination.error_self_address), findsOneWidget);
        expect(rescue.destinationOf(6), isNull);

        await tester.enterText(field, _external.toUpperCase());
        await tester.pump();
        expect(plainText(t.premium.destination.external_warning), findsOneWidget);
        await tester.tap(find.byKey(const Key('rescue-address-save')));
        await tester.pumpAndSettle();
        expect(rescue.destinationOf(6)?.address, _external);
        // 행 부제의 주소 목적지에는 이음 문자가 없다(R1은 주소에 쓰지 않음). 나머지 한국어는 단어 줄바꿈
        final subtitle = find.descendant(
          of: find.byKey(const Key('rescue-wallet-6')),
          matching: find.textContaining('→ ${shortenAddress(_external)} · '),
        );
        expect(subtitle, findsOneWidget, reason: '주소 그대로');
        final detail = textOf(tester, subtitle).data!.split(' · ').last;
        expect(detail, safetyKoText(detail), reason: '상태 글은 R1 적용');
        await tester.pump(const Duration(seconds: 4));
      });

      testWidgets('Premium이 아니면 행을 눌러도 목적지를 바꾸지 않고 페이월을 연다', (tester) async {
        premium.emit(const PremiumState(PremiumStatus.none));
        await pumpScreen(tester, variant);
        await tester.tap(find.byKey(const Key('rescue-wallet-6')));
        await tester.pumpAndSettle();
        expect(find.byType(PremiumPaywallScreen), findsOneWidget);
        expect(find.text(t.premium.rescue.destination), findsNothing);
      });

      testWidgets('구독이 끝나도 사고 지갑의 [지금 이동]은 그대로(자동 갱신만 멈춤)', (tester) async {
        premium.emit(const PremiumState(PremiumStatus.expired));
        store.state = store.state.copyWith(
          incidents: [SafetyIncident(walletId: 1, txid: _attackTxid, detectedAt: DateTime(2026, 10, 20))],
        );
        await pumpScreen(tester, variant);
        expect(
          find.descendant(
            of: find.byKey(const Key('rescue-wallet-1')),
            matching: plainTextContaining(t.premium.rescue.draft_paused(time: t.relative_time.minutes_ago(n: 3))),
          ),
          findsOneWidget,
        );
        final moveNow = find.byKey(const Key('rescue-move-now-1'));
        expect(tester.widget(moveNow), isA<InlineActionButton>(), reason: '앱 표준 버튼(POLISH I3)');
        await tester.tap(moveNow);
        await tester.pumpAndSettle();
        expect(rescue.moves, [1]);
      });

      testWidgets('목적지가 사용 주의가 되면 다시 정하라고 보인다', (tester) async {
        store.state = store.state.copyWith(cautionWalletIds: {2});
        await pumpScreen(tester, variant);
        final line = find.descendant(
          of: find.byKey(const Key('rescue-wallet-1')),
          matching: plainText('→ w2 · ${t.premium.rescue.destination_invalid}'),
        );
        expect(textOf(tester, line).style!.color, colors.warningText);
      });

      for (final locale in [AppLocale.ko, AppLocale.en]) {
        testWidgets('320dp · 글자 1.3배 · ${locale.languageCode}: 화면과 목적지 시트가 넘치지 않는다(리뷰 I-7)', (tester) async {
          LocaleSettings.setLocaleSync(locale);
          addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          rescue = _Rescue(walletProvider: wallets, nodeProvider: node, entitlement: premium, store: store);
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<WalletProvider>.value(value: wallets),
                ChangeNotifierProvider<RescueReadyProvider>.value(value: rescue),
                Provider<EntitlementService>.value(value: premium),
              ],
              child: MaterialApp(
                theme: buildCoconutThemeData(variant: variant),
                builder:
                    (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
                      child: child!,
                    ),
                home: const RescueReadyScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final row = find.byKey(const Key('rescue-wallet-6'));
          await tester.ensureVisible(row);
          await tester.pumpAndSettle();
          await tester.tap(row);
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('rescue-destination-wallet:2')), findsOneWidget, reason: '시트가 실제로 열렸다');
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('페이월이 true를 돌려줘도 지금 권한이 없으면 시트를 열지 않고, 실제로 켜지면 이어서 연다(G-R4·D8)', (tester) async {
        premium.emit(const PremiumState(PremiumStatus.none));
        await pumpScreen(tester, variant);
        // 목적지 없는 지갑: 시트 전에 페이월
        await tester.tap(find.byKey(const Key('rescue-wallet-6')));
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.byType(PremiumPaywallScreen))).pop(true); // "구매 완료"지만 아직 활성 아님
        await tester.pumpAndSettle();
        expect(find.text(t.premium.rescue.destination), findsNothing, reason: '시트를 열지 않는다');
        expect(rescue.destinationOf(6), isNull);

        await tester.tap(find.byKey(const Key('rescue-wallet-6')));
        await tester.pumpAndSettle();
        premium.emit(const PremiumState(PremiumStatus.active));
        Navigator.of(tester.element(find.byType(PremiumPaywallScreen))).pop(true);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('rescue-destination-wallet:2')), findsOneWidget, reason: '결제하면 이어서 시트');
        // 고른 뒤 저장에서는 다시 막지 않는다
        await tester.tap(find.byKey(const Key('rescue-destination-wallet:2')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.premium.rescue.save));
        await tester.pumpAndSettle();
        expect(find.byType(PremiumPaywallScreen), findsNothing);
        expect(rescue.destinationOf(6)?.walletId, 2);
        await tester.pump(const Duration(seconds: 4));
      });

      testWidgets('구독이 끝나면 시트는 페이월 없이 열리고 지우기만 고를 수 있다(G-R6·D8)', (tester) async {
        premium.emit(const PremiumState(PremiumStatus.expired));
        await pumpScreen(tester, variant);
        await tester.tap(find.byKey(const Key('rescue-wallet-1')));
        await tester.pumpAndSettle();
        expect(find.byType(PremiumPaywallScreen), findsNothing);
        SelectableBottomSheetTextItem item(String id) =>
            tester.widget<SelectableBottomSheetTextItem>(find.byKey(Key('rescue-destination-$id')));
        expect(item('wallet:2').isSelected, isTrue, reason: '지금 목적지는 선택된 채로');
        expect(item('wallet:2').isDisabled, isFalse);
        expect(item('off').isDisabled, isFalse);
        for (final id in ['wallet:4', 'vault:new', 'address:new', 'wallet:6', 'hot:new']) {
          expect(item(id).isDisabled, isTrue, reason: id);
        }
        // 흐린 이유를 중립 한 줄로(버튼·가격 없음)
        final note = find.byKey(const Key('rescue-destination-premium-note'));
        expect(textOf(tester, note).data, safetyKoText(t.premium.rescue.premium_note));
        expect(textOf(tester, note).style!.color, colors.secondaryText);
        // 다른 목적지는 눌러도 고르지 않고, 저장에서 페이월도 없다
        await tester.tap(find.byKey(const Key('rescue-destination-wallet:4')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.premium.rescue.save));
        await tester.pumpAndSettle();
        expect(find.byType(PremiumPaywallScreen), findsNothing);
        expect(rescue.destinationOf(1)?.walletId, 2);

        await tester.tap(find.byKey(const Key('rescue-destination-off')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.premium.rescue.save));
        await tester.pumpAndSettle();
        expect(rescue.destinationOf(1), isNull);
        expect(find.text(t.premium.rescue.turned_off_toast), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
      });

      testWidgets('구독이 끝났고 초안이 한 번도 없으면 시각 없이 멈춤을 보인다(리뷰 I-6)', (tester) async {
        premium.emit(const PremiumState(PremiumStatus.expired));
        store.state = SafetyState(
          rescue: {6: (destination: RescueDestination(walletId: 2, setAt: DateTime(2026, 10, 20)), draft: null)},
        );
        await pumpScreen(tester, variant);
        expect(
          find.descendant(
            of: find.byKey(const Key('rescue-wallet-6')),
            matching: plainText('→ w2 · ${t.premium.rescue.draft_paused_none}'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('수수료가 금액의 20%를 넘는 초안은 그 이유를 경고 색으로 보인다(Grok §4)', (tester) async {
        store.state = SafetyState(
          rescue: {
            1: (
              destination: RescueDestination(walletId: 2, setAt: DateTime(2026, 10, 20)),
              draft: RescueDraftSummary(
                destinationAddress: _external,
                amount: 1897,
                fee: 1103,
                inputCount: 1,
                feeRate: 10,
                preparedAt: DateTime.now(),
                blocker: RescueReadyProvider.feeTooHighBlocker,
              ),
            ),
          },
        );
        await pumpScreen(tester, variant);
        final line = find.descendant(
          of: find.byKey(const Key('rescue-wallet-1')),
          matching: plainText('→ w2 · ${t.premium.assist.fee_too_high(percent: SweepFee.maxSharePercent)}'),
        );
        expect(textOf(tester, line).style!.color, colors.warningText);
      });

      testWidgets('SafetyProvider가 알리면 다시 그린다: 새 위급 사건 → [지금 이동] 보임(리뷰 I-5)', (tester) async {
        final safety = _Safety();
        await pumpScreen(tester, variant, safetyProvider: safety);
        expect(find.byKey(const Key('rescue-move-now-1')), findsNothing);

        // SafetyProvider가 저장소에 사건을 쓰고 알린다(지갑 목록·수수료·구독 이벤트 없음)
        store.state = store.state.copyWith(
          incidents: [SafetyIncident(walletId: 1, txid: _attackTxid, detectedAt: DateTime(2026, 10, 20))],
        );
        safety.ping();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('rescue-move-now-1')), findsOneWidget);
      });
    });
  }

  testWidgets('직접 비교로 확인한 목적지는 검증된 것처럼 보이지 않는다(R21)', (tester) async {
    await pumpScreen(
      tester,
      CoconutThemeVariant.light,
      safety: SafetyState(
        watchOnlyVerifications: {
          2: verification(wallets.walletItemList[1], VerificationResult.match, method: VerificationMethod.user),
        },
      ),
    );
    await tester.tap(find.byKey(const Key('rescue-wallet-6')));
    await tester.pumpAndSettle();
    final option = find.byKey(const Key('rescue-destination-wallet:2'));
    final copy = t.premium.destination;
    final confirmed = find.descendant(of: option, matching: plainText(copy.confirmed_on(date: '26.10.20')));
    final colors = resolveCoconutThemeExtension(variant: CoconutThemeVariant.light).colors;
    expect(textOf(tester, confirmed).style!.color, isNot(colors.success), reason: '초록 검증 표시 아님');
    expect(find.descendant(of: option, matching: plainText(copy.verified_on(date: '26.10.20'))), findsNothing);
  });

  testWidgets('검증 기록이 없거나 디스크립터가 바뀐 기록이면 미검증 안내(경보 아님, H8)', (tester) async {
    await pumpScreen(
      tester,
      CoconutThemeVariant.light,
      safety: SafetyState(
        watchOnlyVerifications: {
          2: verification(wallets.walletItemList[1], VerificationResult.match, descriptorHash: 'stale'),
        },
      ),
    );
    await tester.tap(find.byKey(const Key('rescue-wallet-6')));
    await tester.pumpAndSettle();
    final colors = resolveCoconutThemeExtension(variant: CoconutThemeVariant.light).colors;
    for (final id in ['wallet:2', 'wallet:4']) {
      final option = find.byKey(Key('rescue-destination-$id'));
      final caption = find.descendant(of: option, matching: plainText(t.premium.destination.not_verified));
      expect(textOf(tester, caption).style!.color, colors.secondaryText, reason: id);
      final icons = [
        for (final svg in tester.widgetList<SvgPicture>(find.descendant(of: option, matching: find.byType(SvgPicture))))
          (svg.bytesLoader as SvgAssetLoader).assetName,
      ];
      expect(icons, contains(CommonStateIconPath.circleInfo), reason: id);
      expect(icons, isNot(contains(CommonStateIconPath.triangleWarning)), reason: id);
    }
  });

  testWidgets('Premium이 아니고 목적지도 없으면 walletId로 열어도 페이월·시트 없이 화면만(D8)', (tester) async {
    premium.emit(const PremiumState(PremiumStatus.none));
    await pumpScreen(tester, CoconutThemeVariant.light, walletId: 6);
    expect(find.byType(PremiumPaywallScreen), findsNothing);
    expect(find.text(t.premium.rescue.destination), findsNothing);
    expect(find.byType(PremiumChip), findsOneWidget);
    // 설명 아래 Premium 안내 한 줄(D8)
    final note = find.byKey(const Key('rescue-premium-note'));
    expect(textOf(tester, note).data, safetyKoText(t.premium.rescue.premium_note));
    expect(
      textOf(tester, note).style!.color,
      resolveCoconutThemeExtension(variant: CoconutThemeVariant.light).colors.secondaryTextStrong,
    );
    expect(tester.getTopLeft(note).dy, greaterThan(tester.getBottomLeft(plainText(t.premium.rescue.description)).dy));
  });

  testWidgets('구독 확인 중에는 Premium 안내가 깜박이지 않는다(D6·D8)', (tester) async {
    premium.emit(const PremiumState(PremiumStatus.verifying));
    await pumpScreen(tester, CoconutThemeVariant.light);
    expect(find.byKey(const Key('rescue-premium-note')), findsNothing);
    premium.emit(const PremiumState(PremiumStatus.expired));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rescue-premium-note')), findsOneWidget, reason: '만료가 확인되면 보인다');
  });

  testWidgets('볼트 새 지갑: 안내 → 추가된 지갑을 목적지로 저장하고 비상 이동 준비로 돌아온다(UI_SPEC §10.8)', (tester) async {
    await pumpScreen(tester, CoconutThemeVariant.light, walletId: 6);
    expect(plainText(t.premium.destination.vault_new_wallet_body), findsOneWidget);
    await tester.tap(find.byKey(const Key('rescue-destination-vault:new')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.premium.rescue.save));
    await tester.pumpAndSettle();
    final guide = find.byType(AssistSignerGuideScreen);
    expect(guide, findsOneWidget);
    expect(tester.widget<AssistSignerGuideScreen>(guide).sourceWallet.id, 6, reason: '같은 니모닉 거절의 기준');

    // 볼트에서 만든 지갑을 스캔해 추가했다(추가 흐름은 Assist 테스트가 본다). 안내 화면이 받아들이면 onAdded
    final added = _single(8, 8);
    wallets.walletItemListNotifier.value = [...wallets.walletItemList, added];
    tester.widget<AssistSignerGuideScreen>(guide).onAdded(tester.element(guide), added);
    await tester.pumpAndSettle();
    expect(find.byType(AssistSignerGuideScreen), findsNothing);
    expect(find.byKey(const Key('rescue-ready-screen')), findsOneWidget);
    expect(rescue.destinationOf(6)?.walletId, 8);
    expect(find.text(t.premium.rescue.saved_toast), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('볼트 새 지갑 안내에서 그냥 돌아오면 목적지를 바꾸지 않고 다시 고를 수 있다', (tester) async {
    await pumpScreen(tester, CoconutThemeVariant.light, walletId: 6);
    await tester.tap(find.byKey(const Key('rescue-destination-vault:new')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.premium.rescue.save));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(AssistSignerGuideScreen))).pop();
    await tester.pumpAndSettle();
    expect(rescue.destinationOf(6), isNull);
    await tester.tap(find.byKey(const Key('rescue-wallet-6')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rescue-destination-vault:new')), findsOneWidget, reason: '시트가 다시 열린다(막힘 없음)');
  });

  testWidgets('제외 지갑 도출 확인이 실패하면 주소를 받지 않는다(실패 시 거절)', (tester) async {
    await pumpScreen(tester, CoconutThemeVariant.light, walletId: 6);
    await tester.tap(find.byKey(const Key('rescue-destination-address:new')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.premium.rescue.save));
    await tester.pumpAndSettle();
    rescue.deriveFails = true;
    await tester.enterText(
      find.descendant(of: find.byKey(const Key('rescue-address-field')), matching: find.byType(EditableText)),
      _external,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('rescue-address-save')));
    await tester.pumpAndSettle();
    expect(plainText(t.premium.destination.error_self_address), findsOneWidget);
    expect(find.byKey(const Key('rescue-address-field')), findsOneWidget, reason: '시트가 닫히지 않는다');
    expect(rescue.destinationOf(6), isNull);
  });

  testWidgets('주소 직접 입력 시트: 320dp · 글자 2배 · 키보드가 올라와도 넘치지 않는다(GPT M3)', (tester) async {
    await pumpScreen(tester, CoconutThemeVariant.light, walletId: 6);
    await tester.tap(find.byKey(const Key('rescue-destination-address:new')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.premium.rescue.save));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rescue-address-field')), findsOneWidget);

    // 시트를 연 채 작은 화면·큰 글자·키보드(pumpScreen의 view.reset이 되돌린다)
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: find.byKey(const Key('rescue-address-field')), matching: find.byType(EditableText)),
      'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('rescue-address-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rescue-address-save')).hitTestable(), findsOneWidget, reason: '스크롤해서 닿는다');
  });

  testWidgets('지갑 정보에서 구독이 끝난 뒤 열어도 정해 둔 목적지 시트가 열리고 지울 수 있다(G-R6)', (tester) async {
    premium.emit(const PremiumState(PremiumStatus.expired));
    await pumpScreen(tester, CoconutThemeVariant.light, walletId: 1);
    expect(find.byType(PremiumPaywallScreen), findsNothing);
    await tester.tap(find.byKey(const Key('rescue-destination-off')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.premium.rescue.save));
    await tester.pumpAndSettle();
    expect(rescue.destinationOf(1), isNull);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('지갑 정보에서 walletId로 열면 그 지갑의 목적지 시트가 바로 열린다', (tester) async {
    await pumpScreen(tester, CoconutThemeVariant.light, walletId: 6);
    expect(find.text(t.premium.rescue.destination), findsOneWidget);
    expect(find.byKey(const Key('rescue-destination-wallet:2')), findsOneWidget);
  });
}
