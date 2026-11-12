import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/widgets/common/bottom_sheet/selection_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FiatBottomSheet extends StatelessWidget {
  const FiatBottomSheet({
    super.key,
    required this.scrollController,
    this.title,
    this.closeOnSelect = false,
    this.selectedValue,
    this.onSelected,
  });

  static Future<void> show(
    BuildContext context, {
    String screenName = AnalyticsScreenNames.appSettingsFiatSheet,
    String? title,
    bool closeOnSelect = false,
    FiatCode? selectedValue,
    void Function(FiatCode fiat)? onSelected,
  }) {
    return CommonBottomSheets.showDraggableBottomSheet<void>(
      context: context,
      screenName: screenName,
      title: title ?? t.fiat_bottom_sheet.title,
      backgroundColor: context.coconutColors.background,
      childBuilder:
          (scrollController) => FiatBottomSheet(
            scrollController: scrollController,
            title: title,
            closeOnSelect: closeOnSelect,
            selectedValue: selectedValue,
            onSelected: onSelected,
          ),
    );
  }

  final ScrollController scrollController;

  /// true면 통화 선택 즉시 시트를 닫는다 (계산기 등 선택 결과만 필요한 진입점용).
  final bool closeOnSelect;

  /// 지정하지 않으면 앱 전체 설정의 선택 통화를 표시한다.
  /// [onSelected]와 함께 쓰면 전역 설정과 무관한 로컬 선택 UI로 동작한다.
  final FiatCode? selectedValue;

  /// 지정하면 전역 통화 설정을 바꾸지 않고 선택 값만 콜백으로 전달한다.
  final void Function(FiatCode fiat)? onSelected;

  /// 시트 상단 제목. 기본값은 '통화 설정'.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final selected = selectedValue ?? context.watch<PreferenceProvider>().selectedFiat;
    return SelectionBottomSheet<FiatCode>(
      title: title ?? t.fiat_bottom_sheet.title,
      selectedValue: selected,
      scrollController: scrollController,
      showAppBar: false,
      items: [
        for (final fiat in FiatCode.values)
          SelectionItem<FiatCode>(
            title: fiat.code,
            subtitle: _subtitle(fiat),
            sectionTitle: _sectionTitle(fiat),
            value: fiat,
            onTap: () => _onFiatSelected(context, fiat),
          ),
      ],
    );
  }

  String _subtitle(FiatCode fiat) {
    final name = t.fiat_names[fiat.code] ?? fiat.fullName;
    return fiat.hasExchangeSource ? '$name · ${_priceSourceLabel(fiat)}' : name;
  }

  String? _sectionTitle(FiatCode fiat) {
    final isFirstOfGroup =
        fiat.index == 0 || FiatCode.values[fiat.index - 1].hasExchangeSource != fiat.hasExchangeSource;
    if (!isFirstOfGroup) return null;
    return fiat.hasExchangeSource ? t.fiat_bottom_sheet.exchange_section : t.fiat_bottom_sheet.coingecko_price;
  }

  String _priceSourceLabel(FiatCode fiat) {
    return switch (fiat) {
      FiatCode.KRW => t.fiat_bottom_sheet.krw_price,
      FiatCode.USD => t.fiat_bottom_sheet.usd_price,
      FiatCode.JPY => t.fiat_bottom_sheet.jpy_price,
      FiatCode.EUR => t.fiat_bottom_sheet.eur_price,
      _ => t.fiat_bottom_sheet.coingecko_price,
    };
  }

  Future<void> _onFiatSelected(BuildContext context, FiatCode fiatCode) async {
    final onSelected = this.onSelected;
    if (onSelected != null) {
      onSelected(fiatCode);
    } else {
      await context.read<PreferenceProvider>().changeFiat(fiatCode);
    }
    if (closeOnSelect && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
