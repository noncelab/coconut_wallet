import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/widgets/features/transaction/card/transaction_item_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../mock/transaction_record_mock.dart';

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  TransactionRecord record(TransactionType type, {required bool pending, String? memo}) =>
      TransactionRecordMock.createMockTransactionRecord(
        transactionType: type,
        blockHeight: pending ? 0 : 100,
        amount: type == TransactionType.sent ? -50000 : 50000,
        timestamp: DateTime(2026, 10, 20, 9, 5),
        memo: memo,
        inputAddressList: const [],
        outputAddressList: const [],
      );

  Future<void> pump(WidgetTester tester, TransactionRecord tx, {required double width, required double scale}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        builder:
            (context, child) =>
                MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TransactionItemCard(
                tx: tx,
                currentUnit: BitcoinUnit.btc,
                id: 1,
                // 거래 내역 화면과 같은 카드 여백(transaction_list_screen.dart:572): 320dp에서 내용 폭 244
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 카드 글자는 시스템 글자 크기를 1.2배까지만 따른다. 1.0배 미만·1.1배는 그대로(1.0배는 상한 전과 같은 배치)
  testWidgets('card text follows the system text size up to 1.2x', (tester) async {
    for (final (system, applied) in [(0.9, 0.9), (1.0, 1.0), (1.1, 1.1), (1.3, 1.2), (2.0, 1.2), (3.0, 1.2)]) {
      await pump(tester, record(TransactionType.sent, pending: true), width: 390, scale: system);
      final scaler = tester.renderObject<RenderParagraph>(find.text('09:05')).textScaler;
      expect(scaler.scale(10), closeTo(10 * applied, 1e-9), reason: 'system $system');
    }
  });

  // 좁은 화면 + 큰 글자: 상한(1.2배)과 메모 한 줄 말줄임 덕분에 어느 줄도 넘치지 않는다.
  // 띄어쓰기 없는 20자 메모(한글·W)는 상한만으로는 320dp·1.1배부터 넘치던 경우다(리뷰 B1)
  for (final (name, type, pending) in [
    ('sent', TransactionType.sent, false),
    ('sending', TransactionType.sent, true),
    ('received', TransactionType.received, false),
    ('receiving', TransactionType.received, true),
  ]) {
    testWidgets('at 320dp a $name card does not overflow from 1.1x to 3.0x text, even with a 20-char memo', (
      tester,
    ) async {
      for (final memo in [null, '10월 월세', '관리비월세합산송금내역확인필요한건입니다', 'W' * 20]) {
        for (final scale in [1.1, 1.2, 1.3, 2.0, 3.0]) {
          await pump(tester, record(type, pending: pending, memo: memo), width: 320, scale: scale);
          expect(tester.takeException(), isNull, reason: 'memo: $memo, scale: $scale');
          if (memo != null) expect(find.text(memo), findsOneWidget);
        }
      }
    });
  }
}
