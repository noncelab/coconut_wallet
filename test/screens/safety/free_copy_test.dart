import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter_test/flutter_test.dart';

/// Free 대응 문구는 상시 감시를 암시하지 않는다("다음 동기화 때 다시 확인"만). 다섯 언어 모두
void main() {
  test('Free incident copy never promises monitoring in any language', () {
    final banned = RegExp(r'monitor|모니터링|감시|監視|überwach', caseSensitive: false);
    for (final locale in AppLocale.values) {
      final tr = locale.buildSync();
      final g = tr.safety_guide;
      final copy = [
        g.tx_banner.unreviewed_body,
        g.tx_banner.recognized_body,
        g.tx_banner.responding_body,
        g.tx_banner.completed_body,
        g.recognize.body,
        g.recognize.external_signer_hint,
        g.unknown.body,
        g.unknown.step1_body,
        g.unknown.step2_body,
        g.unknown.step3_body,
        g.unknown.step4_body,
        g.step1.body,
        g.step2.free_body,
        g.step2.task_create_body,
        g.step2.task_utxo_body,
        g.step2.task_send_body,
        g.step2.moved_confirm_body,
        g.step3.body,
        g.step3.sync_note,
        g.step3.marked_body,
        g.step4.hot_body,
        g.step4.watch_only_body,
        g.step4.multisig_body,
        g.exposure.no_reuse_body,
        g.exposure.other_wallets_body,
        g.exposure.remove_copies_body,
        g.complete.title,
        g.complete.free_body,
        g.complete.free_body_marked,
        g.caution.banner_body,
        g.help_center.never_asks,
        tr.wallet_health.alerts.empty_body,
        tr.wallet_health.incident.dropped_body,
      ];
      for (final text in copy) {
        expect(text, isNot(matches(banned)), reason: '${locale.languageCode}: $text');
      }
    }
  });
}
