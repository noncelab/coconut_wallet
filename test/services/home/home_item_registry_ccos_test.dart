import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/ccos/ccos_home_entry.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/services/home/home_item_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Widget extends HomeItemDefinition {
  _Widget({super.ccosFeatureId})
    : super(
        id: 'ccos_test_widget',
        kind: HomeItemKind.widget,
        supportedSpans: const [HomeSpan.small],
        category: HomeItemCategory.wallets,
      );

  @override
  Widget build(BuildContext context, HomeItem item) => const SizedBox();
}

CcosFeatureListing _listing(CcosHomeWidget widget) => CcosFeatureListing(
  id: 'ccos-test',
  category: CcosFeatureCategory.tool,
  title: '',
  description: '',
  author: '',
  authorBio: '',
  authorIntent: '',
  whyItBelongs: '',
  featureHelp: '',
  priceType: CcosListingPriceType.free,
  subtitle: '',
  iconPath: '',
  creatorStory: const CcosCreatorStory(paragraphs: [], belief: ''),
  homeWidget: widget,
);

void main() {
  test('a feature widget must belong to its feature', () {
    final registry = HomeItemRegistry();

    expect(() => registry.registerCcosEntries([_listing(CcosHomeWidget(definition: _Widget.new))]), throwsStateError);
  });

  test('a feature widget that names its feature registers', () {
    final registry =
        HomeItemRegistry()
          ..registerCcosEntries([_listing(CcosHomeWidget(definition: () => _Widget(ccosFeatureId: 'ccos-test')))]);

    expect(registry.byId('ccos_test_widget')?.ccosFeatureId, 'ccos-test');
  });
}
