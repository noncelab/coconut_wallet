import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_feature_copy.dart';
import 'package:coconut_wallet/constants/icon_path.dart';

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
      iconPath: CcosFeatureIconPath.ark,
      screenshots: [
        for (var i = 0; i < _screenshotNames.length; i++)
          CcosFeatureScreenshot(
            koAssetPath: 'assets/images/ccos/ark/ko/${_screenshotNames[i]}.png',
            enAssetPath: 'assets/images/ccos/ark/en/${_screenshotNames[i]}.png',
            caption: copy.screenshotCaptions[i],
          ),
      ],
      creatorStory: CcosCreatorStory(paragraphs: copy.creatorParagraphs, belief: copy.belief),
      isApplied: isApplied,
    );
  }

  /// 아크를 켠 지갑이 있으면 기능을 추가했는지와 상관없이 적용 중
  static bool isApplied(CcosFeatureUsage usage) => usage.hasArkOnWallet;
}
