import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/feature/feature_item.dart';
import 'package:coconut_wallet/screens/safety/wallet_health_screen.dart';

abstract final class SafetyFeatureIds {
  static const safetyCheck = 'safety_check';
}

/// 번역 파일의 쉼표로 구분한 검색어
List<String> _keywords(String text) => [
  for (final keyword in text.split(','))
    if (keyword.trim().isNotEmpty) keyword.trim(),
];

/// 모든 기능·바로가기의 안전 점검(v2: 항목 하나). 조건 없이 늘 후보로 둔다(빼면 저장된 바로가기가 지워진다).
List<FeatureItem> safetyFeatures() => [
  FeatureItem(
    id: SafetyFeatureIds.safetyCheck,
    category: FeatureCategory.safety,
    label: () => t.wallet_health.safety_check,
    shortLabel: () => t.wallet_health.feature.safety_check_short,
    iconPath: FeatureWalletHealthIconPath.walletCheck,
    shortcutEligible: true,
    localizedKeywords: () => _keywords(t.wallet_health.feature.safety_check_search),
    launch: (context, _) => WalletHealthScreen.open(context, startCheck: true),
  ),
];
