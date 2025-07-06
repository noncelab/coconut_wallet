import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class CurrencyBottomSheet extends StatefulWidget {
  const CurrencyBottomSheet({super.key});

  @override
  State<CurrencyBottomSheet> createState() => _CurrencyBottomSheetState();
}

class _CurrencyBottomSheetState extends State<CurrencyBottomSheet> {
  @override
  Widget build(BuildContext context) {
    return Selector<PreferenceProvider, FiatCode>(
        selector: (_, viewModel) => viewModel.selectedFiat,
        builder: (context, selectedFiat, child) {
          return Scaffold(
              backgroundColor: CoconutColors.black,
              appBar: CoconutAppBar.build(
                title: t.fiat.fiat,
                context: context,
                onBackPressed: null,
                isBottom: true,
              ),
              body: Padding(
                  padding: const EdgeInsets.only(left: Sizes.size16, right: Sizes.size16),
                  child: Column(children: [
                    _buildFiatItem(t.fiat.krw_code, t.fiat.krw_title, selectedFiat == FiatCode.KRW,
                        () async {
                      await context.read<PreferenceProvider>().changeFiat(FiatCode.KRW);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    }),
                    Divider(
                      color: CoconutColors.white.withOpacity(0.12),
                      height: 1,
                    ),
                    _buildFiatItem(t.fiat.usd_code, t.fiat.usd_title, selectedFiat == FiatCode.USD,
                        () async {
                      await context.read<PreferenceProvider>().changeFiat(FiatCode.USD);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    }),
                  ])));
        });
  }

  Widget _buildFiatItem(String title, String subtitle, bool isChecked, VoidCallback onPress) {
    return GestureDetector(
      onTap: onPress,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: Sizes.size20),
        child: Row(
          children: [
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white)),
                Text(subtitle,
                    style: CoconutTypography.body3_12_Number.setColor(CoconutColors.white)),
              ],
            )),
            if (isChecked)
              Padding(
                padding: const EdgeInsets.only(right: Sizes.size8),
                child: SvgPicture.asset('assets/svg/check.svg'),
              ),
          ],
        ),
      ),
    );
  }
}
