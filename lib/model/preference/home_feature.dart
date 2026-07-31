import 'package:coconut_wallet/constants/icon_path.dart';

// 내용 변경시 RealmHomeFeature도 수정 필요
class HomeFeature {
  final String homeFeatureTypeString;
  final bool isEnabled;
  const HomeFeature({required this.homeFeatureTypeString, required this.isEnabled});

  Map<String, dynamic> toJson() => {'homeFeatureTypeString': homeFeatureTypeString, 'isEnabled': isEnabled};

  factory HomeFeature.fromJson(Map<String, dynamic> json) =>
      HomeFeature(homeFeatureTypeString: json['homeFeatureTypeString'], isEnabled: json['isEnabled']);
}

// RealmHomeFeature 수정 불필요
enum HomeFeatureType {
  totalBalance,
  walletList,
  recentTransaction,
  analysis;

  String get assetPath {
    switch (this) {
      case HomeFeatureType.totalBalance:
        return FeatureWalletIconPath.piggyBank;
      case HomeFeatureType.walletList:
        return FeatureWalletIconPath.wallet;
      case HomeFeatureType.recentTransaction:
        return FeatureTransactionIconPath.transaction;
      case HomeFeatureType.analysis:
        return FeatureSettingsIconPath.analysis;
    }
  }
}
