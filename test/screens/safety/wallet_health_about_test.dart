import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_inputs.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/services/safety/safety_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../model/safety/safety_fixtures.dart' as f;

void main() {
  tearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  group('M12 "not enough data" note', () {
    // 자금·사용 기록이 없는 보기 전용 지갑은 점수 있는 영역이 2개여도 총점이 없다(엔진 조건: 활동 && 2개 이상)
    test('a fresh watch-only wallet has two scored categories but no score yet', () {
      final report = SafetyEngine.evaluate(
        f.inputs(
          wallets: [f.wallet(1, kind: SafetyWalletKind.watchOnly)],
          state: const SafetyState(),
          update: AppUpdateStatus.upToDate,
        ),
      );
      expect(report.status, WalletHealthStatus.notEnoughData);
      expect(report.score, isNull);
      expect(report.categories.values.where((c) => c.score != null).length, greaterThanOrEqualTo(2));
    });

    // 그래서 About 안내는 차례로 세 가지를 말한다: 활동(비트코인·잔액이나 거래 기록), 4개 영역 중 2개 이상, 그 전 점검도 영역별로 반영
    for (final (locale, meaning) in [
      (AppLocale.ko, ['비트코인이나 거래 기록이 있고', '4개 영역 중 2개 이상', '그 전에 한 점검도 영역별 결과에 반영']),
      (
        AppLocale.en,
        [
          'bitcoin or transaction history',
          'at least 2 of the 4 categories',
          'before then still count in each category',
        ],
      ),
      (AppLocale.ja, ['残高か取引履歴があり', '4つの分野のうち2つ以上', 'それまでに行ったチェックも分野ごとの結果に反映']),
      (
        AppLocale.es,
        [
          'bitcoin o historial de transacciones',
          'al menos 2 de las 4 categorías',
          'antes también cuentan en cada categoría',
        ],
      ),
      (
        AppLocale.de,
        ['Bitcoin oder einen Transaktionsverlauf', 'mindestens 2 der 4 Bereiche', 'vorher machst, zählen trotzdem'],
      ),
    ]) {
      test('says activity, 2 of 4 categories and earlier checks still count, in ${locale.name}', () {
        LocaleSettings.setLocaleSync(locale);
        expect(t.wallet_health.about.min_coverage, stringContainsInOrder(meaning));
      });
    }
  });
}
