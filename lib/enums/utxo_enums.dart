import 'package:coconut_wallet/localization/strings.g.dart';

enum UtxoOrder { byAmountDesc, byAmountAsc, byTimestampDesc, byTimestampAsc }

extension UtxoOrderEnumExtension on UtxoOrder {
  String get text {
    switch (this) {
      case UtxoOrder.byAmountDesc:
        return t.utxo_order_enums.amt_desc;
      case UtxoOrder.byAmountAsc:
        return t.utxo_order_enums.amt_asc;
      case UtxoOrder.byTimestampDesc:
        return t.utxo_order_enums.time_desc;
      case UtxoOrder.byTimestampAsc:
        return t.utxo_order_enums.time_asc;
    }
  }
}

enum UtxoMergeStep {
  entry, // UTXO 합치기 필요 없음 안내 문구
  selectMergeMethod, // 정리 기준(작음 금액, 태그, 중복주소)
  selectAmountRange, // 기준 금액 설정
  selectTag, // 태그 설정
  selectReceivingAddress, // 받는 주소 설정(ready)
}

extension UtxoMergeStepExtension on UtxoMergeStep {
  String? getHeaderText(Translations t) {
    switch (this) {
      case UtxoMergeStep.selectMergeMethod:
        return t.merge_utxos_screen.select_merge_method;
      case UtxoMergeStep.selectAmountRange:
        return t.merge_utxos_screen.select_amount_range;
      case UtxoMergeStep.selectTag:
        return t.merge_utxos_screen.select_tag;
      case UtxoMergeStep.entry:
      case UtxoMergeStep.selectReceivingAddress:
        return null;
    }
  }
}

enum UtxoMergeMethod { smallAmounts, sameTag, sameAddress }

extension UtxoMergeMethodExtension on UtxoMergeMethod {
  String getLabel(Translations t) {
    switch (this) {
      case UtxoMergeMethod.smallAmounts:
        return t.merge_utxos_screen.merge_method_bottomsheet.merge_small_amounts;
      case UtxoMergeMethod.sameTag:
        return t.merge_utxos_screen.merge_method_bottomsheet.merge_same_tag;
      case UtxoMergeMethod.sameAddress:
        return t.merge_utxos_screen.merge_method_bottomsheet.merge_same_address;
    }
  }

  String getSummaryText(
    Translations t, {
    required bool isCustomAmountLessThan,
    required String summaryAmountThresholdText,
    required String? effectiveSelectedTagName,
  }) {
    switch (this) {
      case UtxoMergeMethod.smallAmounts:
        return isCustomAmountLessThan
            ? t.merge_utxos_screen.summary_card_headline_under(amount: summaryAmountThresholdText)
            : t.merge_utxos_screen.summary_card_headline_or_less(amount: summaryAmountThresholdText);
      case UtxoMergeMethod.sameTag:
        return t.merge_utxos_screen.selected_tag_title(name: effectiveSelectedTagName ?? '');
      case UtxoMergeMethod.sameAddress:
        return t.merge_utxos_screen.reused_address;
    }
  }
}

enum UtxoAmountRange { below0_01, below0_001, below0_0001, custom }

extension UtxoAmountRangeExtension on UtxoAmountRange {
  String getDisplayAmountText() {
    switch (this) {
      case UtxoAmountRange.below0_01:
        return '0.01 BTC';
      case UtxoAmountRange.below0_001:
        return '0.001 BTC';
      case UtxoAmountRange.below0_0001:
        return '0.0001 BTC';
      case UtxoAmountRange.custom:
        throw StateError('Custom amount range should be handled by caller.');
    }
  }
}

enum UtxoSplitMethod { byAmount, evenly, manually }

extension UtxoSplitMethodExtension on UtxoSplitMethod {
  String getLabel(Translations t) {
    switch (this) {
      case UtxoSplitMethod.byAmount:
        return t.split_utxo_screen.method_bottom_sheet.split_by_amount;
      case UtxoSplitMethod.evenly:
        return t.split_utxo_screen.method_bottom_sheet.split_evenly;
      case UtxoSplitMethod.manually:
        return t.split_utxo_screen.method_bottom_sheet.split_manually;
    }
  }
}

enum UtxoSplitStep {
  selectUtxo, // UTXO 선택
  selectSplitMethod, // 분할 방법 선택
  enterDetails, // 분할 방법별 추가 입력 단계
}
