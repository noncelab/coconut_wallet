import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class UnitBottomSheet extends StatefulWidget {
  const UnitBottomSheet({super.key});

  @override
  State<UnitBottomSheet> createState() => _UnitBottomSheetState();
}

class _UnitBottomSheetState extends State<UnitBottomSheet> {
  @override
  Widget build(BuildContext context) {
    return Selector<PreferenceProvider, bool>(
        selector: (_, viewModel) => viewModel.isBtcUnit,
        builder: (context, isBtcUnit, child) {
          return Scaffold(
              backgroundColor: CoconutColors.black,
              appBar: CoconutAppBar.build(
                title: t.unit_bottom_sheet.basic_unit,
                context: context,
                onBackPressed: null,
                isBottom: true,
              ),
              body: Padding(
                  padding: const EdgeInsets.only(left: Sizes.size16, right: Sizes.size16),
                  child: Column(children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: Sizes.size8),
                        child: Text(t.unit_bottom_sheet.header_text,
                            style: CoconutTypography.body3_12_Number.setColor(CoconutColors.white)),
                      ),
                    ),
                    _buildUnitItem(t.bitcoin_en, t.btc, isBtcUnit, () {
                      context.read<PreferenceProvider>().changeIsBtcUnit(true);
                    }),
                    Divider(
                      color: CoconutColors.white.withOpacity(0.12),
                      height: 1,
                    ),
                    _buildUnitItem(t.satoshi, t.sats, !isBtcUnit, () {
                      context.read<PreferenceProvider>().changeIsBtcUnit(false);
                    }),
                  ])));
        });
  }

  Widget _buildUnitItem(String title, String subtitle, bool isChecked, VoidCallback onPress) {
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
