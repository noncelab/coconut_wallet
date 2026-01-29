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
        return 'assets/svg/piggy-bank.svg';
      case HomeFeatureType.walletList:
        return 'assets/svg/wallet.svg';
      case HomeFeatureType.recentTransaction:
        return 'assets/svg/transaction.svg';
      case HomeFeatureType.analysis:
        return 'assets/svg/analysis.svg';
    }
  }
}
