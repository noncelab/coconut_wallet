import 'dart:async';

import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/screens/safety/security_guide_screen.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:coconut_wallet/widgets/features/safety/transaction_safety_banner.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_guide_scaffold.dart';
import 'package:coconut_wallet/widgets/features/transaction/card/transaction_item_card.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
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
    await tester.tap(findText(strings.step2.moved));
    await tester.pumpAndSettle();
    await tester.tap(findText(strings.step2.moved_confirm));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('safety-guide-step3')), findsOneWidget);
    expect(incident().guideStep, 3);
    await tester.tap(findText(strings.step3.mark));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('safety-guide-step3-marked')), findsOneWidget);
    expect(safety.isCaution(kWalletId), isTrue);
    expect(incident().guideStep, 4);
    expect(findText(strings.caution.badge), findsOneWidget); // 지갑 카드 배지
    await tester.tap(findText(strings.next_step));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('safety-guide-step4')), findsOneWidget);
    expect(findText(strings.step4.watch_only_title), findsOneWidget); // 보기 전용 지갑
    await tester.tap(findText(strings.step4.complete));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('safety-guide-done')), findsOneWidget);
    expect(incident().state, IncidentState.completed);
    expect(findText(strings.complete.free_body_marked), findsOneWidget);
    expect(findText(strings.help_center.never_asks), findsOneWidget);
    expect(find.byKey(const Key('safety-guide-help')), findsNothing); // 도움 받기 행은 Premium만
    await tester.tap(findText(t.done));
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
    expect(findText(strings.step4.hot_title), findsOneWidget); // 지갑 정보가 없으면 핫월렛 문구

    await tester.tap(find.byKey(const Key('safety-guide-later')));
    await tester.pumpAndSettle();
    // D8: 시트 제목은 짧게, 상황 문장은 본문 머리 제목으로
    expect(findText(strings.exposure.sheet_title), findsOneWidget);
    expect(tester.widget<Text>(findText(strings.exposure.title)).style!.fontSize, 18);
    expect(findText(strings.exposure.no_reuse_title), findsOneWidget);
    expect(findText(strings.help_center.never_asks), findsOneWidget);
    // D21: 줄 → 버튼 → 사기 예방 문장 순서
    expect(
      tester.getRect(findText(strings.help_center.never_asks)).top,
      greaterThan(tester.getRect(find.byKey(const Key('safety-exposure-got-it'))).bottom),
    );
    await tapVisible(tester, find.byKey(const Key('safety-exposure-got-it')));
    expect(findText(strings.exposure.no_reuse_title), findsNothing);
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
    await tester.tap(findText(strings.tx_banner.review_guide));
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
    await tester.tap(findText(strings.step4.complete));
    await tester.pumpAndSettle();

    expect(findText(strings.complete.premium_title), findsOneWidget);
    expect(findText(strings.complete.none), findsOneWidget); // 대응 거래 없음
    expect(findText(strings.complete.wallet_normal), findsOneWidget);
    expect(findText(strings.help_center.subtitle), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('safety-guide-help')));
    expect(find.byKey(const Key('help-channel-discord')), findsOneWidget);
    expect(find.byKey(const Key('help-channel-email')), findsOneWidget);
    expect(findText(strings.help_center.never_asks), findsNWidgets(2)); // 완료 화면 + 시트
  });

  // M4: 가이드의 지갑 카드는 홈 지갑 카드 모양이라 홈 타일과 같은 1.2배 상한을 둔다(둘레 글은 시스템 배율 그대로)
  testWidgets('the guide wallet card keeps the home 1.2x cap at 2.0x on 320dp', (tester) async {
    useSmallPhone(tester, 2.0);
    final safety = fixedSafety(incidents: [testIncident(state: IncidentState.responding, guideStep: 2)]);
    await tester.pumpWidget(
      safetyTestApp(
        origin(),
        safety: safety,
        wallets: FakeWallets([WalletMock.createSingleSigWalletItem(id: kWalletId)], balance: 123456),
        preferences: FakePreferences(),
      ),
    );
    await _openGuide(tester, (context) => SecurityGuide.resume(context, kIncidentId));
    expect(find.byKey(const Key('safety-guide-step2')), findsOneWidget);
    final card = find.byType(WalletCard);
    expect(card, findsOneWidget);
    expect(MediaQuery.textScalerOf(tester.element(card)).scale(10), closeTo(12, 0.001));
    expect(MediaQuery.textScalerOf(tester.element(findText(strings.step2.title))).scale(10), closeTo(20, 0.001));
    expect(tester.takeException(), isNull);
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
      await tester.tap(findText(strings.continue_review));
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
      expect(findText(strings.move.backup_reminder), findsOneWidget);
    });

    // M10/R4: 큰 글자에서 버튼이 두 줄이 되고 "지금 백업하기"가 붙어도 마지막 안내가 버튼과 페이드 위로 스크롤된다
    testWidgets('the submitted page scrolls the backup reminder clear of the footer at 2.0x on 320dp', (tester) async {
      useSmallPhone(tester, 2.0);
      useLocale(AppLocale.en);
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
          // 금액 없는 요약 줄(앱 공용 TransactionItemCard는 2.0배·320dp에서 따로 넘친다: 리드에 보고)
          preferences: FakePreferences(isBalanceHidden: true),
        ),
      );
      await _openGuide(tester, (context) => SecurityGuide.resume(context, kIncidentId));
      expect(find.byKey(const Key('safety-guide-back-up-now')), findsOneWidget);
      final scroll = find.descendant(
        of: find.byKey(const Key('safety-guide-submitted')),
        matching: find.byType(SingleChildScrollView),
      );
      await tester.dragFrom(tester.getTopLeft(scroll) + const Offset(40, 24), const Offset(0, -8000)); // 버튼 묶음 위에서 끈다
      await tester.pumpAndSettle();
      final last = tester.getRect(findText(t.safety_guide.move.backup_reminder)).bottom;
      expect(last, lessThanOrEqualTo(tester.getRect(find.byKey(const Key('safety-result-button'))).top));
      final fade = tester.getRect(find.byKey(const Key('safety-result-fade')));
      expect(last, lessThanOrEqualTo(fade.top + fade.height / 2)); // 페이드의 불투명한 절반 위(X1)
      expect(tester.takeException(), isNull);
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
        expect(findText(BitcoinUnit.btc.displayBitcoinAmount(-50000)), showsAmount ? findsOneWidget : findsNothing);
        expect(findText(t.wallet_health.critical.sent_transaction), showsAmount ? findsNothing : findsOneWidget);
        expect(findTextContaining('daily'), showsAmount ? findsNothing : findsOneWidget);
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
        await tester.tap(findText(strings.step4.complete));
        await tester.pumpAndSettle();

        expect(findText(strings.complete.sent), sent ? findsOneWidget : findsNothing);
        expect(findText(strings.complete.none), sent ? findsNothing : findsOneWidget);
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
    await tester.tap(findText(strings.tx_banner.review_guide));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byKey(const Key('safety-guide-step1-not-found')));
    expect(findText(strings.step2.moved), findsNothing); // "완료했어요" 확인 없이
    await tester.tap(findText(strings.next_step));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-guide-step3')), findsOneWidget);
    expect(findText(strings.step3.mark), findsNothing);
    await tester.tap(findText(strings.next_step));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-guide-step3-marked')), findsNothing);
    expect(find.byKey(const Key('safety-guide-step4')), findsOneWidget);
    await tester.tap(findText(strings.step4.complete));
    await tester.pumpAndSettle();
    await tester.tap(findText(t.done));
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

    expect(findText(strings.recognize.shared_title), findsOneWidget);
    await tester.tap(findText(t.cancel));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-guide-step1')), findsOneWidget);
    expect(safety.incidentFor(kWalletId, kTxid)!.state, IncidentState.responding);
  });

  // D10/M9: 완료 화면 Premium 요약의 값도 폭 안에서 줄을 바꾼다(긴 독일어 "Mit Vorsicht nutzen")
  for (final scale in [1.3, 2.0]) {
    testWidgets('the Premium done summary fits 320dp at ${scale}x in German', (tester) async {
      useSmallPhone(tester, scale);
      useLocale(AppLocale.de);
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
              assistStartedAt: DateTime(2026, 10, 20, 10),
            ),
          ],
          cautionWalletIds: const {kWalletId},
        ),
      );
      await tester.pumpWidget(safetyTestApp(origin(), safety: safety));
      await _openGuide(tester, (context) => SecurityGuide.resume(context, kIncidentId));
      await tapVisible(tester, find.byKey(const Key('safety-guide-button')));
      expect(find.byKey(const Key('safety-guide-done')), findsOneWidget);
      expect(tester.takeException(), isNull);
      final value = findText(t.safety_guide.caution.badge);
      expect(value, findsOneWidget);
      expect(tester.getRect(value).right, lessThanOrEqualTo(320));
    });
  }

  // R33: STEP4의 복구 자료 자가 점검 기록과, 다시 열었을 때의 상태 줄
  group('recovery-material self-review', () {
    SafetyIncident step4({RecoveryReviewStatus review = RecoveryReviewStatus.notChecked, IncidentState? state}) =>
        SafetyIncident(
          walletId: kWalletId,
          txid: kTxid,
          detectedAt: DateTime(2026, 10, 20, 9),
          state: state ?? IncidentState.responding,
          responseMode: IncidentResponseMode.free,
          guideStep: 4,
          recoveryReview: review,
        );

    Future<_ReviewRecorder> openStep4(WidgetTester tester, SafetyIncident incident) async {
      usePhoneSize(tester);
      final safety = _ReviewRecorder(SafetyState(incidents: [incident]));
      await tester.pumpWidget(safetyTestApp(origin(), safety: safety));
      await _openGuide(tester, (context) => SecurityGuide.resume(context, kIncidentId));
      return safety;
    }

    testWidgets('"Finish the security review" records it as reviewed by the user', (tester) async {
      final safety = await openStep4(tester, step4());
      await tapVisible(tester, find.byKey(const Key('safety-guide-button')));
      expect(safety.reviews, [RecoveryReviewStatus.completedByUser]);
      expect(find.byKey(const Key('safety-guide-done')), findsOneWidget);
    });

    testWidgets('the exposure link records a suspected exposure and opens only the exposure guidance', (tester) async {
      final safety = await openStep4(tester, step4());
      await tapVisible(tester, find.byKey(const Key('safety-guide-later')));
      expect(safety.reviews, [RecoveryReviewStatus.exposureSuspected]);
      expect(find.byKey(const Key('safety-exposure-got-it')), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('safety-exposure-got-it')));
      expect(find.byKey(const Key('safety-guide-step4')), findsOneWidget); // 자금 이동 단계로 되돌리지 않는다
      expect(find.byKey(const Key('safety-guide-step2')), findsNothing);
    });

    testWidgets('finishing after a suspected exposure keeps that mark', (tester) async {
      final safety = await openStep4(tester, step4(review: RecoveryReviewStatus.exposureSuspected));
      await tapVisible(tester, find.byKey(const Key('safety-guide-button')));
      expect(safety.reviews, isEmpty);
    });

    for (final (review, text) in [
      (RecoveryReviewStatus.notChecked, null),
      (RecoveryReviewStatus.completedByUser, t.safety_guide.step4.status_reviewed),
      (RecoveryReviewStatus.exposureSuspected, t.safety_guide.step4.status_exposure_suspected),
    ]) {
      testWidgets('reopening STEP4 shows the saved status (${review.name})', (tester) async {
        await openStep4(tester, step4(review: review));
        final line = find.byKey(const Key('safety-guide-step4-review-status'));
        expect(line, text == null ? findsNothing : findsOneWidget);
        if (text != null) expect(find.descendant(of: line, matching: findText(text)), findsOneWidget);
      });
    }

    testWidgets('reviewing a finished incident records nothing', (tester) async {
      usePhoneSize(tester);
      final safety = _ReviewRecorder(
        SafetyState(incidents: [step4(state: IncidentState.completed, review: RecoveryReviewStatus.completedByUser)]),
      );
      await tester.pumpWidget(
        safetyTestApp(origin(child: const TransactionSafetyBanner(walletId: kWalletId, txHash: kTxid)), safety: safety),
      );
      await tester.pumpAndSettle();
      await tester.tap(findText(strings.tx_banner.review_guide));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('safety-guide-step1-not-found')));
      await tester.tap(findText(strings.next_step));
      await tester.pumpAndSettle();
      await tester.tap(findText(strings.next_step));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('safety-guide-step4')), findsOneWidget);
      expect(find.byKey(const Key('safety-guide-step4-review-status')), findsOneWidget); // 저장된 상태는 보인다
      await tapVisible(tester, find.byKey(const Key('safety-guide-later')));
      await tapVisible(tester, find.byKey(const Key('safety-exposure-got-it')));
      await tapVisible(tester, find.byKey(const Key('safety-guide-button')));
      expect(safety.reviews, isEmpty);
    });
  });
  // X7: STEP2 Premium 줄은 큰 글자(1.3배~)에서 칩을 글 위에, 보통 크기에서는 나란히
  for (final (scale, stacked) in [(1.0, false), (2.0, true)]) {
    testWidgets(
      'the STEP2 Premium row ${stacked ? 'stacks the chip above the text' : 'keeps chip and text side by side'} at ${scale}x',
      (tester) async {
        useSmallPhone(tester, scale);
        final safety = fixedSafety(incidents: [testIncident(state: IncidentState.responding, guideStep: 2)]);
        await tester.pumpWidget(safetyTestApp(origin(), safety: safety, entitlement: FakeEntitlementService()));
        await _openGuide(tester, (context) => SecurityGuide.resume(context, kIncidentId));
        final row = find.byKey(const Key('safety-guide-step2-premium'));
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        final chip = tester.getRect(find.descendant(of: row, matching: find.byType(PremiumChip)));
        final text = tester.getRect(find.byKey(const Key('safety-guide-step2-premium-text')));
        if (stacked) {
          expect(text.top, greaterThanOrEqualTo(chip.bottom));
        } else {
          expect(text.left, greaterThan(chip.right));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}

/// 복구 자료 점검 기록만 받아 두는 제공자(고정 제공자에는 지갑 목록이 없어 실제 기록은 지갑 종류를 알 수 없다)
class _ReviewRecorder extends SafetyProvider {
  _ReviewRecorder(SafetyState state) : super.fixed(null, state: state);

  final reviews = <RecoveryReviewStatus>[];

  @override
  Future<void> recordRecoveryReview(String id, RecoveryReviewStatus status) async => reviews.add(status);
}
