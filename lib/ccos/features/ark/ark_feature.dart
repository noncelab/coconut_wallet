import 'package:coconut_wallet/app/router/feature_entry_routes.dart';
import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/ccos/ccos_feature_status.dart';
import 'package:coconut_wallet/ccos/ccos_home_entry.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_feature_copy.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_server_config.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_home_widget.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_wallet_home_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_wallet_entrance.dart';
import 'package:flutter/material.dart';

class ArkFeature {
  static const String id = 'ccos-feature-ark';

  static const _screenshotNames = ['1_toggle', '2_receive', '3_swap', '4_vtxo', '5_wallet_info'];

  static CcosFeatureListing get listing {
    final copy = ArkFeatureCopySource.current;
    return CcosFeatureListing(
      id: id,
      category: CcosFeatureCategory.layer2,
      title: copy.title,
      description: copy.description,
      author: copy.author,
      authorBio: copy.authorBio,
      authorIntent: copy.authorIntent,
      whyItBelongs: copy.whyItBelongs,
      featureHelp: copy.featureHelp,
      priceType: CcosListingPriceType.free,
      tags: copy.tags,
      subtitle: copy.subtitle,
      iconPath: FeatureArkIconPath.boat,
      screenshots: [
        for (var i = 0; i < _screenshotNames.length; i++)
          CcosFeatureScreenshot(
            koAssetPath: 'assets/images/ccos/ark/ko/${_screenshotNames[i]}.png',
            enAssetPath: 'assets/images/ccos/ark/en/${_screenshotNames[i]}.png',
            caption: copy.screenshotCaptions[i],
          ),
      ],
      creatorStory: CcosCreatorStory(paragraphs: copy.creatorParagraphs, belief: copy.belief),
      isListed: () => ArkServerConfig.isConfigured,
      thumbnailImagePath: 'assets/images/ccos/ark_illustration.png',
      homeShortcut: CcosHomeShortcut(
        id: 'ark_wallet',
        label: () => ArkFeatureCopySource.current.title,
        iconPath: FeatureArkIconPath.boat,
        launch: openWallet,
        addToHomeOnActivate: true,
      ),
      homeWidget: CcosHomeWidget(definition: ArkWalletHomeWidget.new),
    );
  }

  static CcosFeatureStatus status(ArkWalletProvider wallet, {required bool isActivated}) =>
      wallet.hasWallet
          ? CcosFeatureStatus(inUse: true, removeBlockedReason: t.ark_wallet.remove_blocked)
          : const CcosFeatureStatus();

  static void openWallet(BuildContext context) {
    final navigator = Navigator.of(context);
    FeatureEntryRoutes.instance.launching(() => navigator.push(ArkWalletEntrance.route(const ArkWalletHomeScreen())));
  }
}
