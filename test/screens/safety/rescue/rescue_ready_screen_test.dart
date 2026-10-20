import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
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
import 'package:coconut_wallet/screens/safety/rescue/rescue_ready_screen.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:coconut_wallet/services/safety/sweep_builder.dart';
import 'package:coconut_wallet/services/safety/wallet_verification.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:flutter/material.dart';
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

  @override
  Future<void> moveNow(BuildContext context, int walletId) async => moves.add(walletId);

  @override
  Future<bool> derivesFromExcludedWallet(int walletId, String address) async => derivedFromExcluded.contains(address);
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

  WatchOnlyVerification verification(WalletItemBase wallet, VerificationResult result, {String? descriptorHash}) =>
      WatchOnlyVerification(
        method: VerificationMethod.qr,
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
        expect(textOf(tester, find.text(copy.wallets_title)).style!.color, colors.primaryText);
        expect(textOf(tester, find.text(copy.description)).style!.color, colors.secondaryText);
        expect(find.text(copy.on_device), findsOneWidget);

        final fee = BitcoinUnit.btc.displayBitcoinAmount(1410, withUnit: true);
        final ready = find.descendant(
          of: find.byKey(const Key('rescue-wallet-1')),
          matching: find.textContaining('→ w2 · ${copy.draft_ready(time: t.relative_time.minutes_ago(n: 3))}'),
        );
        expect(ready, findsOneWidget);
        expect(textOf(tester, ready).data, contains('${t.estimated_fee} $fee'));
        expect(textOf(tester, ready).style!.color, colors.secondaryText);
        expect(
          find.descendant(of: find.byKey(const Key('rescue-wallet-6')), matching: find.text(copy.not_set)),
          findsOneWidget,
        );
        // 잔액 있는 w1이 맨 위
        expect(
          tester.getTopLeft(find.byKey(const Key('rescue-wallet-1'))).dy,
          lessThan(tester.getTopLeft(find.byKey(const Key('rescue-wallet-2'))).dy),
        );
        // 사고가 없으면 지금 이동은 보이지 않는다
        expect(find.byKey(const Key('rescue-move-now-1')), findsNothing);
      });

      testWidgets('행 → 목적지 시트(보기 전용 먼저, MFP 없음·이 기기 경고) → 저장', (tester) async {
        await pumpScreen(tester, variant);
        await tester.tap(find.byKey(const Key('rescue-wallet-6')));
        await tester.pumpAndSettle();

        final copy = t.premium.destination;
        expect(find.text(t.premium.rescue.destination), findsOneWidget);
        final ids = [
          for (final id in ['wallet:2', 'wallet:4', 'address:new', 'wallet:1', 'hot:new'])
            tester.getTopLeft(find.byKey(Key('rescue-destination-$id'))).dy,
        ];
        expect(ids, [...ids]..sort(), reason: '보기 전용(MFP 있음) → MFP 없음 → 주소 입력 → 이 기기 지갑 → 이 기기 새 핫월렛(SafetyAssist 순서)');
        expect(find.byKey(const Key('rescue-destination-off')), findsNothing, reason: '목적지가 없으면 끄기도 없다');
        expect(
          find.descendant(
            of: find.byKey(const Key('rescue-destination-wallet:4')),
            matching: find.text(copy.unknown_seed),
          ),
          findsOneWidget,
        );
        final warning = find.descendant(
          of: find.byKey(const Key('rescue-destination-wallet:1')),
          matching: find.text(copy.new_hot_wallet_warning),
        );
        expect(textOf(tester, warning).style!.color, colors.warningText);

        await tester.tap(find.byKey(const Key('rescue-destination-wallet:2')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.premium.rescue.save));
        await tester.pumpAndSettle();
        expect(rescue.destinationOf(6)?.walletId, 2);
        expect(find.text(t.premium.rescue.saved_toast), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
      });

      testWidgets('주소 불일치 지갑은 목적지에서 빠지고, 정해 둔 목적지면 다시 정하라고 보인다. 검증된 지갑은 표시 없음', (tester) async {
        store.state = store.state.copyWith(
          watchOnlyVerifications: {
            2: verification(wallets.walletItemList[1], VerificationResult.mismatch),
            4: verification(wallets.walletItemList[2], VerificationResult.match),
          },
        );
        await pumpScreen(tester, variant, safety: store.state);
        final invalid = find.descendant(
          of: find.byKey(const Key('rescue-wallet-1')),
          matching: find.text('→ w2 · ${t.premium.rescue.destination_invalid}'),
        );
        expect(textOf(tester, invalid).style!.color, colors.warningText);

        await tester.tap(find.byKey(const Key('rescue-wallet-6')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('rescue-destination-wallet:2')), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(const Key('rescue-destination-wallet:4')),
            matching: find.text(t.wallet_health.check.watch_only_verify.not_verified),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('rescue-destination-wallet:1')),
            matching: find.text(t.wallet_health.check.watch_only_verify.not_verified),
          ),
          findsNothing,
          reason: '핫월렛은 보기 전용 검증 대상이 아니다',
        );
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
        expect(find.text(AddressValidationError.notRegtestnetAddress.message), findsOneWidget);
        await tester.tap(find.byKey(const Key('rescue-address-save')));
        await tester.pumpAndSettle();
        expect(rescue.destinationOf(6), isNull, reason: '비활성 버튼');

        await tester.enterText(field, own);
        await tester.pump();
        expect(find.text(t.premium.destination.error_self_address), findsOneWidget);

        // 만들어 둔 주소 목록 밖이지만 이 지갑에서 나온 주소: 저장을 누를 때 걸러진다(Grok §5)
        final beyondGap = wallets.walletItemList.last.walletBase.getAddress(500);
        rescue.derivedFromExcluded.add(beyondGap);
        await tester.enterText(field, beyondGap);
        await tester.pump();
        await tester.tap(find.byKey(const Key('rescue-address-save')));
        await tester.pumpAndSettle();
        expect(find.text(t.premium.destination.error_self_address), findsOneWidget);
        expect(rescue.destinationOf(6), isNull);

        await tester.enterText(field, _external.toUpperCase());
        await tester.pump();
        expect(find.text(t.premium.destination.external_warning), findsOneWidget);
        await tester.tap(find.byKey(const Key('rescue-address-save')));
        await tester.pumpAndSettle();
        expect(rescue.destinationOf(6)?.address, _external);
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
            matching: find.textContaining(t.premium.rescue.draft_paused(time: t.relative_time.minutes_ago(n: 3))),
          ),
          findsOneWidget,
        );
        final moveNow = find.byKey(const Key('rescue-move-now-1'));
        expect(
          textOf(tester, find.descendant(of: moveNow, matching: find.byType(Text))).style!.color,
          colors.premiumText,
        );
        await tester.tap(moveNow);
        await tester.pumpAndSettle();
        expect(rescue.moves, [1]);
      });

      testWidgets('목적지가 사용 주의가 되면 다시 정하라고 보인다', (tester) async {
        store.state = store.state.copyWith(cautionWalletIds: {2});
        await pumpScreen(tester, variant);
        final line = find.descendant(
          of: find.byKey(const Key('rescue-wallet-1')),
          matching: find.text('→ w2 · ${t.premium.rescue.destination_invalid}'),
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

      testWidgets('페이월이 true를 돌려줘도 지금 권한이 없으면 목적지를 정하지 않는다(G-R4)', (tester) async {
        premium.emit(const PremiumState(PremiumStatus.none));
        await pumpScreen(tester, variant);
        // 목적지 없는 지갑: 시트 전에 페이월
        await tester.tap(find.byKey(const Key('rescue-wallet-6')));
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.byType(PremiumPaywallScreen))).pop(true); // "구매 완료"지만 아직 활성 아님
        await tester.pumpAndSettle();
        expect(find.text(t.premium.rescue.destination), findsNothing, reason: '시트를 열지 않는다');
        expect(rescue.destinationOf(6), isNull);

        // 정해 둔 목적지 바꾸기: 고른 뒤 페이월
        premium.emit(const PremiumState(PremiumStatus.expired));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('rescue-wallet-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('rescue-destination-wallet:4')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.premium.rescue.save));
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.byType(PremiumPaywallScreen))).pop(true);
        await tester.pumpAndSettle();
        expect(rescue.destinationOf(1)?.walletId, 2, reason: '바꾸지 않는다');
        expect(find.text(t.premium.rescue.saved_toast), findsNothing);
      });

      testWidgets('구독이 끝나도 정해 둔 목적지는 페이월 없이 지울 수 있고, 다른 곳으로 바꾸면 페이월(G-R6)', (tester) async {
        premium.emit(const PremiumState(PremiumStatus.expired));
        await pumpScreen(tester, variant);
        await tester.tap(find.byKey(const Key('rescue-wallet-1')));
        await tester.pumpAndSettle();
        expect(find.byType(PremiumPaywallScreen), findsNothing);
        await tester.tap(find.byKey(const Key('rescue-destination-wallet:4')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.premium.rescue.save));
        await tester.pumpAndSettle();
        expect(find.byType(PremiumPaywallScreen), findsOneWidget, reason: '바꾸기는 Premium');
        // 페이월을 구독 없이 닫는다(닫기 버튼과 같은 결과)
        Navigator.of(tester.element(find.byType(PremiumPaywallScreen))).pop(false);
        await tester.pumpAndSettle();
        expect(rescue.destinationOf(1)?.walletId, 2, reason: '구독하지 않으면 그대로');

        await tester.tap(find.byKey(const Key('rescue-wallet-1')));
        await tester.pumpAndSettle();
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
            matching: find.text('→ w2 · ${t.premium.rescue.draft_paused_none}'),
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
          matching: find.text('→ w2 · ${t.premium.assist.fee_too_high(percent: SweepFee.maxSharePercent)}'),
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

  testWidgets('검증 기록이 없거나 디스크립터가 바뀐 기록이면 미검증', (tester) async {
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
    final notVerified = t.wallet_health.check.watch_only_verify.not_verified;
    final warningText = resolveCoconutThemeExtension(variant: CoconutThemeVariant.light).colors.warningText;
    for (final id in ['wallet:2', 'wallet:4']) {
      final caption = find.descendant(of: find.byKey(Key('rescue-destination-$id')), matching: find.text(notVerified));
      expect(textOf(tester, caption).style!.color, warningText, reason: id);
    }
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
