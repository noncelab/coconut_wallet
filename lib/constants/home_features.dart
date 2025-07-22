import 'package:coconut_wallet/model/preference/home_feature.dart';

const kHomeFeatures = [
  // ** 추가시 homeFeatureTypeString 을 [HomeFeatureType]과 동일시해야함 **
  HomeFeature(
      homeFeatureTypeString: 'recentTransaction',
      assetPath: 'assets/svg/transaction.svg',
      isEnabled: true),
  HomeFeature(
      homeFeatureTypeString: 'analysis', assetPath: 'assets/svg/analysis.svg', isEnabled: true),
];
