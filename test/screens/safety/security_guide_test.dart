import 'dart:async';

import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/screens/safety/security_guide_screen.dart';
import 'package:coconut_wallet/widgets/features/safety/transaction_safety_banner.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_guide_scaffold.dart';
import 'package:coconut_wallet/widgets/features/transaction/card/transaction_item_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mock/wallet_mock.dart';
import 'safety_test_harness.dart';

double _progress(WidgetTester tester) =>
    tester
        .widget<FractionallySizedBox>(
          find.descendant(of: find.byType(SafetyGuideProgressBar), matching: find.byType(FractionallySizedBox)),
        )
        .widthFactor!;

Future<void> _openGuide(WidgetTester tester, Future<void> Function(BuildContext) open) async {
  unawaited(open(originContext(tester)));
  await tester.pumpAndSettle();
}

void main() {
  final strings = t.safety_guide;

  testWidgets('Free guide: STEP1 → STEP2 → STEP3 → marked → STEP4 → done, then back to where it started', (
    tester,
  ) async {
    usePhoneSize(tester);
    final safety = fixedSafety(incidents: [testIncident(state: IncidentState.responding)]);
    await tester.pumpWidget(
      safetyTestApp(
        origin(),
        safety: safety,
        wallets: FakeWallets([WalletMock.createSingleSigWalletItem(id: kWalletId)], balance: 50000),
      ),
    );
    await _openGuide(tester, (context) => SecurityGuide.start(context, kIncidentId));
    SafetyIncident incident() => safety.incidentFor(kWalletId, kTxid)!;

    expect(find.byKey(const Key('safety-guide-step1')), findsOneWidget);
    expect(_progress(tester), 0.04);
    await tapVisible(tester, find.byKey(const Key('safety-guide-step1-not-found')));

    expect(find.byKey(const Key('safety-guide-step2')), findsOneWidget);
    expect(incident().guideStep, 2);
    expect(_progress(tester), 0.25);
    for (final task in ['create', 'utxo', 'send']) {
      expect(find.byKey(Key('safety-guide-step2-$task')), findsOneWidget);
    }
    await tester.tap(find.text(strings.step2.moved));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.step2.moved_confirm));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('safety-guide-step3')), findsOneWidget);
    expect(incident().guideStep, 3);
    await tester.tap(find.text(strings.step3.mark));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('safety-guide-step3-marked')), findsOneWidget);
    expect(safety.isCaution(kWalletId), isTrue);
    expect(incident().guideStep, 4);
    expect(find.text(strings.caution.badge), findsOneWidget); // 지갑 카드 배지
    await tester.tap(find.text(strings.next_step));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('safety-guide-step4')), findsOneWidget);
    expect(find.text(strings.step4.watch_only_title), findsOneWidget); // 보기 전용 지갑
    await tester.tap(find.text(strings.step4.complete));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('safety-guide-done')), findsOneWidget);
    expect(incident().state, IncidentState.completed);
    expect(find.text(strings.complete.free_body_marked), findsOneWidget);
    expect(find.text(strings.help_center.never_asks), findsOneWidget);
    expect(find.byKey(const Key('safety-guide-help')), findsNothing); // 도움 받기 행은 Premium만
    await tester.tap(find.text(t.done));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('origin')), findsOneWidget);
    expect(find.byType(SafetyGuidePage), findsNothing);
  });

  testWidgets('resume opens the saved step', (tester) async {
    usePhoneSize(tester);
    final safety = fixedSafety(incidents: [testIncident(state: IncidentState.responding, guideStep: 3)]);
    await tester.pumpWidget(safetyTestApp(origin(), safety: safety));
    await _openGuide(tester, (context) => SecurityGuide.resume(context, kIncidentId));
    expect(find.byKey(const Key('safety-guide-step3')), findsOneWidget);
    expect(_progress(tester), 0.5);
  });

  testWidgets('"Do it later" closes the guide and keeps the incident responding at its step', (tester) async {
    usePhoneSize(tester);
    final safety = fixedSafety(incidents: [testIncident(state: IncidentState.responding, guideStep: 2)]);
    await tester.pumpWidget(safetyTestApp(origin(), safety: safety));
    await _openGuide(tester, (context) => SecurityGuide.resume(context, kIncidentId));
    expect(find.byKey(const Key('safety-guide-step2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('safety-guide-later')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('origin')), findsOneWidget);
    expect(safety.incidentFor(kWalletId, kTxid)!.state, IncidentState.responding);
    expect(safety.incidentFor(kWalletId, kTxid)!.guideStep, 2);
  });

  testWidgets('"Yes, it\'s mine" on STEP1 recognizes the incident and closes the guide', (tester) async {
    usePhoneSize(tester);
    final safety = fixedSafety(incidents: [testIncident(state: IncidentState.responding)]);
    await tester.pumpWidget(safetyTestApp(origin(), safety: safety));
    await _openGuide(tester, (context) => SecurityGuide.start(context, kIncidentId));
    await tapVisible(tester, find.byKey(const Key('safety-guide-step1-found')));

    expect(safety.incidentFor(kWalletId, kTxid)!.state, IncidentState.recognized);
    expect(find.byType(SafetyGuidePage), findsNothing);
    await settleToasts(tester);
  });

  testWidgets('STEP4 link opens the exposure sheet without asking to move funds again', (tester) async {
    usePhoneSize(tester);
    final safety = fixedSafety(incidents: [testIncident(state: IncidentState.responding, guideStep: 4)]);
    await tester.pumpWidget(safetyTestApp(origin(), safety: safety));
    await _openGuide(tester, (context) => SecurityGuide.resume(context, kIncidentId));
    expect(find.text(strings.step4.hot_title), findsOneWidget); // 지갑 정보가 없으면 핫월렛 문구

    await tester.tap(find.byKey(const Key('safety-guide-later')));
    await tester.pumpAndSettle();
    expect(find.text(strings.exposure.no_reuse_title), findsOneWidget);
    expect(find.text(strings.help_center.never_asks), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('safety-exposure-got-it')));
    expect(find.text(strings.exposure.no_reuse_title), findsNothing);
    expect(find.byKey(const Key('safety-guide-step4')), findsOneWidget);
  });

  testWidgets('"Review guide" on a finished incident walks the guide without changing it', (tester) async {
    usePhoneSize(tester);
    final finished = testIncident(state: IncidentState.completed, guideStep: 4);
    final safety = fixedSafety(incidents: [finished]);
    await tester.pumpWidget(
      safetyTestApp(origin(child: const TransactionSafetyBanner(walletId: kWalletId, txHash: kTxid)), safety: safety),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.tx_banner.review_guide));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('safety-guide-step1')), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('safety-guide-step1-not-found')));
    expect(find.byKey(const Key('safety-guide-step2')), findsOneWidget);
    expect(find.byKey(const Key('safety-guide-step2-premium')), findsNothing);
    expect(safety.incidentFor(kWalletId, kTxid), finished); // 상태·단계 그대로
  });

  testWidgets('a Premium response ends with the summary and the help row', (tester) async {
    usePhoneSize(tester);
    final safety = fixedSafety(
      incidents: [testIncident(state: IncidentState.responding, mode: IncidentResponseMode.premium, guideStep: 4)],
    );
    await tester.pumpWidget(safetyTestApp(origin(), safety: safety));
    await _openGuide(tester, (context) => SecurityGuide.resume(context, kIncidentId));
    await tester.tap(find.text(strings.step4.complete));
    await tester.pumpAndSettle();

    expect(find.text(strings.complete.premium_title), findsOneWidget);
    expect(find.text(strings.complete.none), findsOneWidget); // 대응 거래 없음
    expect(find.text(strings.complete.wallet_normal), findsOneWidget);
    expect(find.text(strings.help_center.subtitle), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('safety-guide-help')));
    expect(find.byKey(const Key('help-channel-discord')), findsOneWidget);
    expect(find.byKey(const Key('help-channel-email')), findsOneWidget);
    expect(find.text(strings.help_center.never_asks), findsNWidgets(2)); // 완료 화면 + 시트
  });

  group('resume after a Premium move was sent', () {
    final assistAt = DateTime(2026, 10, 20, 10);
    SafetyProvider sentAfterAssist() => SafetyProvider.fixed(
      null,
      state: SafetyState(
        incidents: [
          SafetyIncident(
            walletId: kWalletId,
            txid: kTxid,
            detectedAt: DateTime(2026, 10, 20, 9),
            state: IncidentState.responding,
            responseMode: IncidentResponseMode.premium,
            guideStep: 2,
            assistStartedAt: assistAt,
          ),
        ],
        lastBroadcast: (walletId: kWalletId, txid: 'move', at: assistAt.add(const Duration(minutes: 5))),
      ),
    );

    testWidgets('shows "transaction sent" once, records STEP3, then continues to STEP3', (tester) async {
      usePhoneSize(tester);
      final safety = sentAfterAssist();
      await tester.pumpWidget(safetyTestApp(origin(), safety: safety));
      await _openGuide(tester, (context) => SecurityGuide.resume(context, kIncidentId));

      expect(find.byKey(const Key('safety-guide-submitted')), findsOneWidget);
      expect(find.byKey(const Key('safety-guide-back-up-now')), findsNothing);
      expect(safety.incidentFor(kWalletId, kTxid)!.guideStep, 3);
      await tester.tap(find.text(strings.continue_review));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('safety-guide-step3')), findsOneWidget);
    });

    testWidgets('offers "back up now" for a hot wallet made during the response', (tester) async {
      usePhoneSize(tester);
      final hot = SinglesigWalletItem(
        id: 2,
        name: 'new',
        colorIndex: 0,
        iconIndex: 0,
        descriptor: WalletMock.createSingleSigWalletItem().descriptor,
        hotWalletMetadata: HotWalletMetadata(
          walletId: 2,
          secureStorageKey: 'key',
          masterFingerprint: 'D45AA182',
          derivationPath: "m/84'/1'/0'",
          accountIndex: 0,
          backupVerified: false,
          enterPassphraseWhenSigning: false,
          createdAt: assistAt.add(const Duration(minutes: 1)),
        ),
      );
      // 이동 거래(move)의 받는 주소가 새 핫월렛(2)의 주소
      await tester.pumpWidget(
        safetyTestApp(
          origin(),
          safety: sentAfterAssist(),
          wallets: FakeWallets(
            [hot],
            records: {'move'},
            owned: {
              2: {kRecipient},
            },
          ),
        ),
      );
      await _openGuide(tester, (context) => SecurityGuide.resume(context, kIncidentId));

      expect(find.byKey(const Key('safety-guide-back-up-now')), findsOneWidget);
      expect(find.text(strings.move.backup_reminder), findsOneWidget);
    });

    // R1-M3: 보낸 거래 요약도 잔액 숨김·가짜 잔액·설정 없음이면 금액 없이 "보낸 거래 · 지갑 이름"
    final privacy = [
      ('normal', FakePreferences(), true),
      ('hidden balance', FakePreferences(isBalanceHidden: true), false),
      ('fake balance', FakePreferences(isFakeBalanceActive: true), false),
      ('no preference provider', null, false),
    ];
    for (final (label, preferences, showsAmount) in privacy) {
      testWidgets('the sent transaction summary follows the amount privacy rule: $label', (tester) async {
        usePhoneSize(tester);
        await tester.pumpWidget(
          safetyTestApp(
            origin(),
            safety: sentAfterAssist(),
            wallets: FakeWallets(
              [WalletMock.createSingleSigWalletItem(id: kWalletId, name: 'daily')],
              records: {'move'},
            ),
            preferences: preferences,
          ),
        );
        await _openGuide(tester, (context) => SecurityGuide.resume(context, kIncidentId));

        expect(find.byKey(const Key('safety-guide-submitted-tx')), findsOneWidget);
        expect(find.byType(TransactionItemCard), showsAmount ? findsOneWidget : findsNothing);
        expect(find.text(BitcoinUnit.btc.displayBitcoinAmount(-50000)), showsAmount ? findsOneWidget : findsNothing);
        expect(find.text(t.wallet_health.critical.sent_transaction), showsAmount ? findsNothing : findsOneWidget);
        expect(find.textContaining('daily'), showsAmount ? findsNothing : findsOneWidget);
      });
    }
  });

  // D2: 요약의 "대응 거래"는 Safety Assist를 시작한 뒤 이 지갑에서 보낸 거래만
  group('Premium summary only counts a send made after Safety Assist started', () {
    final assistAt = DateTime(2026, 10, 20, 10);
    final cases = [
      (
        'a normal send before Safety Assist',
        (walletId: kWalletId, txid: 'pay', at: DateTime(2026, 10, 20, 9, 30)),
        false,
      ),
      ('a send from another wallet', (walletId: 2, txid: 'other', at: DateTime(2026, 10, 20, 10, 30)), false),
      (
        'the response sent after Safety Assist',
        (walletId: kWalletId, txid: 'move', at: DateTime(2026, 10, 20, 10, 30)),
        true,
      ),
    ];
    for (final (label, broadcast, sent) in cases) {
      testWidgets(label, (tester) async {
        usePhoneSize(tester);
        final safety = SafetyProvider.fixed(
          null,
          state: SafetyState(
            incidents: [
              SafetyIncident(
                walletId: kWalletId,
                txid: kTxid,
                detectedAt: DateTime(2026, 10, 20, 9),
                state: IncidentState.responding,
                responseMode: IncidentResponseMode.premium,
                guideStep: 4,
                assistStartedAt: assistAt,
              ),
            ],
            lastBroadcast: broadcast,
          ),
        );
        await tester.pumpWidget(safetyTestApp(origin(), safety: safety));
        await _openGuide(tester, (context) => SecurityGuide.resume(context, kIncidentId));
        await tester.tap(find.text(strings.step4.complete));
        await tester.pumpAndSettle();

        expect(find.text(strings.complete.sent), sent ? findsOneWidget : findsNothing);
        expect(find.text(strings.complete.none), sent ? findsNothing : findsOneWidget);
      });
    }
  });

  // D4: 끝난 사건 다시 보기는 사용 주의 표시를 포함해 아무것도 바꾸지 않는다
  testWidgets('reviewing a finished incident to the end leaves the whole state unchanged', (tester) async {
    usePhoneSize(tester);
    final safety = fixedSafety(incidents: [testIncident(state: IncidentState.completed, guideStep: 4)]); // 사용 주의는 이미 해제
    final before = safety.state;
    await tester.pumpWidget(
      safetyTestApp(origin(child: const TransactionSafetyBanner(walletId: kWalletId, txHash: kTxid)), safety: safety),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.tx_banner.review_guide));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byKey(const Key('safety-guide-step1-not-found')));
    expect(find.text(strings.step2.moved), findsNothing); // "완료했어요" 확인 없이
    await tester.tap(find.text(strings.next_step));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-guide-step3')), findsOneWidget);
    expect(find.text(strings.step3.mark), findsNothing);
    await tester.tap(find.text(strings.next_step));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-guide-step3-marked')), findsNothing);
    expect(find.byKey(const Key('safety-guide-step4')), findsOneWidget);
    await tester.tap(find.text(strings.step4.complete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.done));
    await tester.pumpAndSettle();

    expect(safety.state, before);
    expect(safety.isCaution(kWalletId), isFalse);
  });

  testWidgets('cancelling the "other wallets too" notice on STEP1 keeps the guide open', (tester) async {
    usePhoneSize(tester);
    final safety = fixedSafety(
      incidents: [
        testIncident(state: IncidentState.responding),
        SafetyIncident(walletId: 2, txid: kTxid, detectedAt: DateTime(2026, 10, 20, 9)),
      ],
    );
    await tester.pumpWidget(safetyTestApp(origin(), safety: safety));
    await _openGuide(tester, (context) => SecurityGuide.start(context, kIncidentId));
    await tapVisible(tester, find.byKey(const Key('safety-guide-step1-found')));

    expect(find.text(strings.recognize.shared_title), findsOneWidget);
    await tester.tap(find.text(t.cancel));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-guide-step1')), findsOneWidget);
    expect(safety.incidentFor(kWalletId, kTxid)!.state, IncidentState.responding);
  });
}
