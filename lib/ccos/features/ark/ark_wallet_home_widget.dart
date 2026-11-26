import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_feature.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_feature_copy.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_server_config.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 아크 지갑 잔액. 지갑이 없으면 만들기 안내, 학습용 빌드는 메인넷 전용
class ArkWalletHomeWidget extends HomeItemDefinition {
  ArkWalletHomeWidget()
    : super(
        id: 'ark_wallet',
        kind: HomeItemKind.widget,
        supportedSpans: const [HomeSpan.small, HomeSpan.wide],
        category: HomeItemCategory.wallets,
        ccosFeatureId: ArkFeature.id,
      );

  @override
  String displayName() => ArkFeatureCopySource.current.title;

  @override
  Widget build(BuildContext context, HomeItem item) {
    final colors = context.coconutColors;
    final wallet = context.watch<ArkWalletProvider>();
    final unit = context.select<ArkWalletProvider, BitcoinUnit>((wallet) => wallet.unit);
    return HomeWidgetCard(
      key: const ValueKey('ark-wallet-home-widget'),
      onPressed: () => ArkFeature.openWallet(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeWidgetHeader(
            iconPath: FeatureArkIconPath.boat,
            title: displayName(),
            style: CoconutTypography.body1_16_Bold,
          ),
          const Spacer(),
          Text(
            wallet.hasWallet
                ? unit.displayBitcoinAmount(wallet.balance.total, withUnit: true)
                : ArkServerConfig.isMainnetOnlyPreview
                ? t.ccos.store.mainnet_only
                : t.ark_wallet.widget_create,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                wallet.hasWallet
                    ? CoconutTypography.heading4_18_Bold.setColor(colors.primaryText)
                    : CoconutTypography.body2_14.setColor(colors.secondaryText),
          ),
        ],
      ),
    );
  }
}
