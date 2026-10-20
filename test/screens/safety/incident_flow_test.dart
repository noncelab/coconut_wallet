import 'dart:async';

import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/screens/safety/incident_sheets.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:coconut_wallet/widgets/features/safety/transaction_safety_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mock/wallet_mock.dart';
import 'safety_test_harness.dart';

Widget _detail() => origin(child: const TransactionSafetyBanner(walletId: kWalletId, txHash: kTxid));

void main() {
  final strings = t.safety_guide;

  testWidgets('review link → "I recognize it" records it and turns the banner green', (tester) async {
    final safety = fixedSafety(incidents: [testIncident()]);
    await tester.pumpWidget(safetyTestApp(_detail(), safety: safety));
    await tester.pumpAndSettle();

    await tester.tap(findText(strings.tx_banner.review));
    await tester.pumpAndSettle();
    expect(findText(strings.recognize.title), findsOneWidget);
    expect(findText(strings.recognize.signed_elsewhere), findsNothing);
    await tester.tap(find.byKey(const Key('incident-recognize-yes')));
    await tester.pumpAndSettle();

    expect(safety.incidentFor(kWalletId, kTxid)!.state, IncidentState.recognized);
    expect(safety.state.recognizedTxids, contains(kTxid));
    expect(find.byKey(const Key('transaction-safety-banner-recognized')), findsOneWidget);
    expect(findText(strings.recognize.recognized_toast), findsOneWidget);
    await settleToasts(tester);
  });

  testWidgets('"I don\'t recognize it" → what to do now → Get started opens STEP1 as responding', (tester) async {
    usePhoneSize(tester);
    final safety = fixedSafety(incidents: [testIncident()]);
    await tester.pumpWidget(safetyTestApp(_detail(), safety: safety));
    await tester.pumpAndSettle();

    await tester.tap(findText(strings.tx_banner.review));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('incident-recognize-no')));
    await tester.pumpAndSettle();

    expect(safety.incidentFor(kWalletId, kTxid)!.state, IncidentState.responding);
    expect(safety.incidentFor(kWalletId, kTxid)!.responseMode, IncidentResponseMode.free);
    expect(findText(strings.unknown.what_to_do), findsOneWidget);
    for (final step in [strings.unknown.step1_title, strings.unknown.step4_title]) {
      expect(findText(step), findsOneWidget);
    }
    await tester.tap(findText(strings.unknown.get_started));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('safety-guide-step1')), findsOneWidget);
    expect(safety.incidentFor(kWalletId, kTxid)!.guideStep, 1);
  });

  testWidgets('with a ready rescue draft "what to do now" leads with "Move now"', (tester) async {
    usePhoneSize(tester);
    final rescue = FakeRescue();
    await tester.pumpWidget(safetyTestApp(_detail(), safety: fixedSafety(incidents: [testIncident()]), rescue: rescue));
    await tester.pumpAndSettle();
    await tester.tap(findText(strings.tx_banner.review));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('incident-recognize-no')));
    await tester.pumpAndSettle();

    expect(findText(t.premium.rescue.destination_line(destination: rescue.destination)), findsOneWidget);
    expect(findText(strings.unknown.get_started), findsNothing);
    expect(findText(strings.unknown.step_by_step), findsOneWidget);
    await tester.tap(findText(t.premium.rescue.move_now));
    await tester.pumpAndSettle();
    expect(rescue.moves, 1);
  });

  testWidgets('watch-only wallets get the "signed elsewhere" hint', (tester) async {
    final safety = fixedSafety(incidents: [testIncident()]);
    await tester.pumpWidget(
      safetyTestApp(
        _detail(),
        safety: safety,
        wallets: FakeWallets([WalletMock.createSingleSigWalletItem(id: kWalletId)]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(findText(strings.tx_banner.review));
    await tester.pumpAndSettle();
    expect(findText(strings.recognize.signed_elsewhere), findsOneWidget);
  });

  testWidgets('openSafetyIncident opens the detail and asks once the transition has settled', (tester) async {
    final safety = fixedSafety(incidents: [testIncident()]);
    await tester.pumpWidget(
      safetyTestApp(
        origin(),
        safety: safety,
        wallets: FakeWallets(const [], records: {kTxid}),
        routes: {AppRouteNames.transactionDetail: (_) => _detail()},
      ),
    );
    unawaited(openSafetyIncident(originContext(tester), walletId: kWalletId, txid: kTxid));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byKey(const Key('transaction-safety-banner-unreviewed')), findsOneWidget);
    expect(findText(strings.recognize.title), findsNothing); // 전환 중에는 아직

    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(findText(strings.recognize.title), findsOneWidget);
  });

  testWidgets('without autoReview the detail opens quietly; a vanished transaction goes straight to the sheet', (
    tester,
  ) async {
    final safety = fixedSafety(incidents: [testIncident(), testIncident(txid: 'gone')]);
    await tester.pumpWidget(
      safetyTestApp(
        origin(),
        safety: safety,
        wallets: FakeWallets(const [], records: {kTxid}),
        routes: {AppRouteNames.transactionDetail: (_) => _detail()},
      ),
    );
    unawaited(openSafetyIncident(originContext(tester), walletId: kWalletId, txid: kTxid, autoReview: false));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('transaction-safety-banner-unreviewed')), findsOneWidget);
    expect(findText(strings.recognize.title), findsNothing);

    Navigator.of(tester.element(find.byKey(const Key('origin')).last)).pop();
    await tester.pumpAndSettle();
    unawaited(openSafetyIncident(originContext(tester), walletId: kWalletId, txid: 'gone'));
    await tester.pumpAndSettle();
    expect(findText(strings.recognize.title), findsOneWidget);
  });

  group('a pending send from before the wallet was added (no incident yet)', () {
    const pending = 'pend';

    Future<SafetyProvider> openPending(WidgetTester tester, {bool selfTransfer = false}) async {
      final safety = SafetyProvider.fixed(
        null,
        state: SafetyState(
          baselines: {
            kWalletId: WalletBaseline(
              height: 100,
              pendingSentAtBaseline: selfTransfer ? const {} : const {pending},
              unexpectedSelfTxids: selfTransfer ? const {pending} : const {},
              at: DateTime(2026, 10, 20),
            ),
          },
        ),
      );
      await tester.pumpWidget(
        safetyTestApp(
          origin(),
          safety: safety,
          wallets: FakeWallets(const [], records: {pending}),
          routes: {
            AppRouteNames.transactionDetail:
                (_) => origin(child: const TransactionSafetyBanner(walletId: kWalletId, txHash: pending)),
          },
        ),
      );
      unawaited(openSafetyIncident(originContext(tester), walletId: kWalletId, txid: pending));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(findText(strings.recognize.title), findsOneWidget);
      final review = t.wallet_health.review;
      expect(findText(selfTransfer ? review.self_transfer.body : review.recent_at_add.body), findsOneWidget);
      expect(findText(strings.recognize.body), findsNothing);
      return safety;
    }

    testWidgets('a self-transfer made outside Coconut uses its own explanation', (tester) async {
      final safety = await openPending(tester, selfTransfer: true);
      await tester.tap(find.byKey(const Key('incident-recognize-yes')));
      await tester.pumpAndSettle();
      expect(safety.state.recognizedTxids, contains(pending));
      await settleToasts(tester);
    });

    testWidgets('"It\'s mine" closes it without creating an incident', (tester) async {
      final safety = await openPending(tester);
      await tester.tap(find.byKey(const Key('incident-recognize-yes')));
      await tester.pumpAndSettle();
      expect(safety.state.recognizedTxids, contains(pending));
      expect(safety.incidentFor(kWalletId, pending), isNull);
      await settleToasts(tester);
    });

    testWidgets('"I don\'t recognize it" creates the incident and continues to what to do now', (tester) async {
      usePhoneSize(tester);
      final safety = await openPending(tester);
      await tester.tap(find.byKey(const Key('incident-recognize-no')));
      await tester.pumpAndSettle();
      expect(safety.incidentFor(kWalletId, pending)!.state, IncidentState.responding);
      expect(findText(strings.unknown.what_to_do), findsOneWidget);
    });
  });

  // D3: 거래 기록이 없는 끝난 사건도 눌러서 저장된 사건 요약을 볼 수 있다(완료면 가이드 다시 보기)
  for (final state in [IncidentState.recognized, IncidentState.completed]) {
    testWidgets('a ${state.name} incident whose transaction record is gone opens a read-only summary', (tester) async {
      final safety = fixedSafety(incidents: [testIncident(state: state)]);
      await tester.pumpWidget(safetyTestApp(origin(), safety: safety, wallets: FakeWallets(const [])));
      unawaited(openSafetyIncident(originContext(tester), walletId: kWalletId, txid: kTxid, autoReview: false));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('transaction-safety-banner-${state.name}')), findsOneWidget);
      expect(
        findText(strings.tx_banner.review_guide),
        state == IncidentState.completed ? findsOneWidget : findsNothing,
      );
      expect(safety.incidentFor(kWalletId, kTxid)!.state, state);
    });
  }

  // 레드팀 §5: 고르기 전에 사실(보낸 금액·받는 주소)부터, 다른 기기 서명 안내는 작게 뒤에
  /// 사건 지갑 1의 인지 시트를 연다(거래 기록 있음, [outputs] 기본은 받는 주소 + 거스름)
  Future<void> openRecognize(
    WidgetTester tester, {
    PreferenceProvider? preferences,
    List<TransactionAddress>? outputs,
    double? smallPhoneScale,
  }) async {
    if (smallPhoneScale == null) {
      usePhoneSize(tester);
    } else {
      useSmallPhone(tester, smallPhoneScale);
    }
    await tester.pumpWidget(
      safetyTestApp(
        origin(),
        safety: fixedSafety(incidents: [testIncident()]),
        wallets: FakeWallets([WalletMock.createSingleSigWalletItem(id: kWalletId)], records: {kTxid}, outputs: outputs),
        preferences: preferences,
        routes: {AppRouteNames.transactionDetail: (_) => _detail()},
      ),
    );
    unawaited(openSafetyIncident(originContext(tester), walletId: kWalletId, txid: kTxid));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(findText(t.safety_guide.recognize.title), findsOneWidget);
  }

  String short(String address) => '${address.substring(0, 10)}…${address.substring(address.length - 8)}';
  String recipientText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('incident-recognize-recipient'))).data!;

  testWidgets('the recognize sheet shows amount and recipient before the choices, with a smaller hint', (tester) async {
    await openRecognize(tester, preferences: FakePreferences());

    expect(findText(BitcoinUnit.btc.displayBitcoinAmount(50000, withUnit: true)), findsOneWidget);
    expect(recipientText(tester), short(kRecipient)); // 가운데 줄임
    expect(findText(strings.recognize.recipient), findsOneWidget);
    expect(find.byKey(const Key('incident-recognize-recipient-more')), findsNothing);
    expect(findTextContaining(kChange.substring(0, 10)), findsNothing); // 거스름(내 주소)은 받는 주소가 아니다
    double top(Finder finder) => tester.getTopLeft(finder).dy;
    final facts = find.byKey(const Key('incident-recognize-facts'));
    final hint = find.byKey(const Key('incident-recognize-signed-elsewhere'));
    expect(top(facts), lessThan(top(find.byKey(const Key('incident-recognize-yes')))));
    expect(top(hint), greaterThan(top(find.byKey(const Key('incident-recognize-no')))));
    final yesTitle = tester.widget<Text>(findText(strings.recognize.yes_title));
    expect(tester.widget<Text>(hint).style!.fontSize, lessThan(yesTitle.style!.fontSize!));
    expect(findText(strings.help_center.never_asks), findsOneWidget); // 같은 화면에 "절대 묻지·시키지 않아요"
    expect(top(findText(strings.help_center.never_asks)), greaterThan(top(hint)));
  });

  // D3/M5: 320dp · 1.3/2.0배 · 독일어에서도 사실 상자가 넘치지 않고, 금액과 주소("외 N개" 포함)를 자르지 않는다
  for (final scale in [1.3, 2.0]) {
    testWidgets('the facts box fits 320dp at ${scale}x in German without cutting the amount or address', (
      tester,
    ) async {
      useLocale(AppLocale.de);
      await openRecognize(
        tester,
        preferences: FakePreferences(),
        smallPhoneScale: scale,
        outputs: [
          TransactionAddress(kRecipient, 30000),
          TransactionAddress('bcrt1qsecond00000000000000000000000000000000', 20000),
          TransactionAddress(kChange, 10000),
        ],
      );
      expect(tester.takeException(), isNull);
      final box = tester.getRect(find.byKey(const Key('incident-recognize-facts')));
      for (final part in [
        findText(BitcoinUnit.btc.displayBitcoinAmount(50000, withUnit: true)),
        find.byKey(const Key('incident-recognize-recipient')),
        find.byKey(const Key('incident-recognize-recipient-more')),
      ]) {
        expect(part, findsOneWidget);
        final rect = tester.getRect(part);
        expect(rect.left >= box.left && rect.right <= box.right, isTrue);
      }
      expect(recipientText(tester), short(kRecipient)); // 줄여 맞출 뿐 끝 글자까지 그대로
    });
  }

  // D5/M10: 비상 이동 초안이 있는 "지금 할 일"(버튼 + 부가 줄)도 320dp·2.0배에서 마지막 줄이 버튼 위로 올라온다
  testWidgets('the what-to-do sheet scrolls its last step clear of the footer at 2.0x on 320dp', (tester) async {
    useSmallPhone(tester, 2.0);
    useLocale(AppLocale.de);
    await tester.pumpWidget(
      safetyTestApp(_detail(), safety: fixedSafety(incidents: [testIncident()]), rescue: FakeRescue()),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, findText(t.safety_guide.tx_banner.review)); // 2.0배에서는 배너 링크가 화면 아래에 있다
    await tapVisible(tester, find.byKey(const Key('incident-recognize-no')));
    final footer = find.byKey(const Key('incident-what-to-do-move-now'));
    expect(footer, findsOneWidget);
    // 2.0배에서는 단계 목록이 아직 만들어지지 않을 만큼 아래에 있다. 늘 있는 제목으로 스크롤 영역을 먼저 잡고(제목은
    // 스크롤되면 사라진다), 지연 목록의 끝이 아이템이 만들어질 때마다 늘어나므로 더 늘지 않을 때까지 끝으로 옮긴다
    final positions = [
      for (final element
          in find.ancestor(of: findText(t.safety_guide.unknown.title), matching: find.byType(Scrollable)).evaluate())
        ((element as StatefulElement).state as ScrollableState).position,
    ];
    for (var i = 0; i < 10 && positions.any((p) => p.pixels < p.maxScrollExtent); i++) {
      for (final position in positions) {
        position.jumpTo(position.maxScrollExtent);
      }
      await tester.pumpAndSettle();
    }
    final last = tester.getRect(find.byType(SafetyNumberedRow).last).bottom;
    expect(last, lessThanOrEqualTo(tester.getRect(footer).top));
    final fade = tester.getRect(find.byKey(const Key('incident-what-to-do-fade')));
    expect(last, lessThanOrEqualTo(fade.top + fade.height / 2)); // 페이드의 불투명한 절반 위(X1)
    expect(tester.takeException(), isNull);
  });

  // R1-M3: 잔액 숨김·가짜 잔액·설정 없음이면 사실 상자(금액·받는 주소)를 통째로 뺀다
  final privacy = [
    ('normal', FakePreferences(), true),
    ('hidden balance', FakePreferences(isBalanceHidden: true), false),
    ('fake balance', FakePreferences(isFakeBalanceActive: true), false),
    ('no preference provider', null, false),
  ];
  for (final (label, preferences, showsFacts) in privacy) {
    testWidgets('the recognize sheet follows the amount privacy rule: $label', (tester) async {
      await openRecognize(tester, preferences: preferences);

      final shown = showsFacts ? findsOneWidget : findsNothing;
      expect(find.byKey(const Key('incident-recognize-facts')), shown);
      expect(findText(BitcoinUnit.btc.displayBitcoinAmount(50000, withUnit: true)), shown);
      expect(findText(short(kRecipient)), shown);
      expect(find.byKey(const Key('incident-recognize-yes')), findsOneWidget); // 선택지는 그대로
    });
  }

  // R1-m1: 받는 곳은 첫 외부 주소 + "외 N개". 주소 없는 출력(스크립트 '')·내 주소는 빼고, 모두 내 주소면 줄을 뺀다
  group('the recipient row', () {
    const second = 'bcrt1qsecond00000000000000000000000000000000';

    testWidgets('two external outputs plus change: first address and "+1 more"', (tester) async {
      await openRecognize(
        tester,
        preferences: FakePreferences(),
        outputs: [
          TransactionAddress(kRecipient, 30000),
          TransactionAddress(second, 20000),
          TransactionAddress(kChange, 10000),
        ],
      );
      expect(recipientText(tester), short(kRecipient));
      expect(findText(strings.recognize.recipient_more(n: 1)), findsOneWidget);
      expect(findText(short(second)), findsNothing);
    });

    testWidgets('a leading script output (no address) is skipped', (tester) async {
      await openRecognize(
        tester,
        preferences: FakePreferences(),
        outputs: [TransactionAddress('', 0), TransactionAddress(kRecipient, 50000), TransactionAddress(kChange, 10000)],
      );
      expect(recipientText(tester), short(kRecipient));
      expect(find.byKey(const Key('incident-recognize-recipient-more')), findsNothing);
    });

    testWidgets('all outputs are this wallet\'s: amount only, no recipient row', (tester) async {
      await openRecognize(
        tester,
        preferences: FakePreferences(),
        outputs: [TransactionAddress('', 0), TransactionAddress(kChange, 50000)],
      );
      expect(find.byKey(const Key('incident-recognize-facts')), findsOneWidget);
      expect(findText(strings.recognize.recipient), findsNothing);
      expect(find.byKey(const Key('incident-recognize-recipient')), findsNothing);
    });
  });

  // 레드팀 §6: 같은 거래가 다른 지갑에도 열려 있으면 함께 닫힌다는 것을 먼저 묻는다
  testWidgets('"It\'s mine" asks first when the same transaction is open in another wallet', (tester) async {
    final safety = fixedSafety(
      incidents: [testIncident(), SafetyIncident(walletId: 2, txid: kTxid, detectedAt: DateTime(2026, 10, 20, 9))],
    );
    final wallets = FakeWallets([
      WalletMock.createSingleSigWalletItem(id: kWalletId, name: 'daily'),
      WalletMock.createSingleSigWalletItem(id: 2, name: 'savings'),
    ]);
    await tester.pumpWidget(safetyTestApp(_detail(), safety: safety, wallets: wallets));
    await tester.pumpAndSettle();

    Future<void> chooseMine() async {
      await tester.tap(find.byKey(const Key('incident-recognize-yes')));
      await tester.pumpAndSettle();
      expect(findText(strings.recognize.shared_title), findsOneWidget);
      expect(findTextContaining('savings2'), findsOneWidget);
    }

    await tester.tap(findText(strings.tx_banner.review));
    await tester.pumpAndSettle();
    await chooseMine();
    await tester.tap(findText(t.cancel));
    await tester.pumpAndSettle();
    expect(safety.incidentFor(kWalletId, kTxid)!.state, IncidentState.detected); // 취소하면 그대로

    await chooseMine(); // 취소하면 인지 시트에 남아 바로 다시 고를 수 있다
    await tester.tap(findText(strings.recognize.shared_confirm));
    await tester.pumpAndSettle();
    expect(safety.incidentFor(kWalletId, kTxid)!.state, IncidentState.recognized);
    expect(safety.incidentFor(2, kTxid)!.state, IncidentState.recognized); // 같은 txid는 함께 닫힌다
    await settleToasts(tester);
  });

  // R1-m2: 사건이 없는 검토 항목(기준점 대기 출금)에서도 함께 표시 확인을 취소하면 인지 시트로 돌아온다
  testWidgets('cancelling the shared confirm on a review item returns to the recognize sheet unchanged', (
    tester,
  ) async {
    const other = 2;
    final safety = SafetyProvider.fixed(
      null,
      state: SafetyState(
        incidents: [testIncident()],
        baselines: {
          other: WalletBaseline(height: 100, pendingSentAtBaseline: const {kTxid}, at: DateTime(2026, 10, 20)),
        },
      ),
    );
    final before = safety.state;
    await tester.pumpWidget(
      safetyTestApp(
        origin(),
        safety: safety,
        wallets: FakeWallets(
          [
            WalletMock.createSingleSigWalletItem(id: kWalletId, name: 'daily'),
            WalletMock.createSingleSigWalletItem(id: other, name: 'savings'),
          ],
          records: {kTxid},
        ),
        routes: {
          AppRouteNames.transactionDetail:
              (_) => origin(child: const TransactionSafetyBanner(walletId: other, txHash: kTxid)),
        },
      ),
    );
    unawaited(openSafetyIncident(originContext(tester), walletId: other, txid: kTxid));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(findText(t.wallet_health.review.recent_at_add.body), findsOneWidget);
    expect(safety.incidentFor(other, kTxid), isNull); // 이 지갑에는 사건이 없다

    await tester.tap(find.byKey(const Key('incident-recognize-yes')));
    await tester.pumpAndSettle();
    expect(findTextContaining('daily1'), findsOneWidget); // 함께 닫힐 다른 지갑
    await tester.tap(findText(t.cancel));
    await tester.pumpAndSettle();

    expect(findText(strings.recognize.shared_title), findsNothing);
    expect(find.byKey(const Key('incident-recognize-yes')), findsOneWidget); // 선택지가 그대로 있다
    expect(find.byKey(const Key('incident-recognize-no')), findsOneWidget);
    expect(safety.state, before);

    await tester.tap(find.byKey(const Key('incident-recognize-yes')));
    await tester.pumpAndSettle();
    await tester.tap(findText(strings.recognize.shared_confirm));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('incident-recognize-yes')), findsNothing);
    expect(safety.state.recognizedTxids, contains(kTxid));
    expect(safety.incidentFor(kWalletId, kTxid)!.state, IncidentState.recognized);
    await settleToasts(tester);
  });

  // Grok G4: 인지는 txid 단위라 그 거래가 보이는 다른 지갑의 기준점 검토 항목도 함께 닫힌다 → 그 지갑도 먼저 묻는다
  for (final (label, incidents) in [
    ('a review item in two wallets', const <SafetyIncident>[]),
    ('an incident here and only a review item in the other wallet', [testIncident()]),
  ]) {
    testWidgets('"It\'s mine" asks first for $label; cancel leaves both unchanged', (tester) async {
      final review = WalletBaseline(height: 100, pendingSentAtBaseline: const {kTxid}, at: DateTime(2026, 10, 20));
      final safety = SafetyProvider.fixed(
        null,
        state: SafetyState(incidents: incidents, baselines: {if (incidents.isEmpty) kWalletId: review, 2: review}),
      );
      final before = safety.state;
      await tester.pumpWidget(
        safetyTestApp(
          origin(),
          safety: safety,
          wallets: FakeWallets(
            [
              WalletMock.createSingleSigWalletItem(id: kWalletId, name: 'daily'),
              WalletMock.createSingleSigWalletItem(id: 2, name: 'savings'),
            ],
            records: {kTxid},
          ),
          routes: {AppRouteNames.transactionDetail: (_) => _detail()},
        ),
      );
      unawaited(openSafetyIncident(originContext(tester), walletId: kWalletId, txid: kTxid));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(safety.incidentFor(2, kTxid), isNull); // 다른 지갑에는 사건 없이 검토 항목만

      await tester.tap(find.byKey(const Key('incident-recognize-yes')));
      await tester.pumpAndSettle();
      expect(findText(strings.recognize.shared_title), findsOneWidget);
      expect(findTextContaining('savings2'), findsOneWidget);
      expect(findTextContaining('daily1'), findsNothing); // 지금 지갑은 이름에 넣지 않는다
      await tester.tap(findText(t.cancel));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('incident-recognize-yes')), findsOneWidget); // 인지 시트로 돌아온다
      expect(safety.state, before); // 두 지갑 모두 그대로
    });
  }
}
