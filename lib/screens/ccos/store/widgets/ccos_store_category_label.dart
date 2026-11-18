import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/localization/strings.g.dart';

extension CcosStoreCategoryLabel on CcosFeatureCategory {
  String get label => switch (this) {
    CcosFeatureCategory.theme => t.ccos.store.category.theme,
    CcosFeatureCategory.layer2 => t.ccos.store.category.layer2,
    CcosFeatureCategory.analysis => t.ccos.store.category.analysis,
    CcosFeatureCategory.tool => t.ccos.store.category.tool,
    CcosFeatureCategory.widget => t.ccos.store.category.widget,
  };
}
