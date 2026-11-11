import 'package:coconut_wallet/services/feature/feature_launcher.dart';
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
    // 홈 바로가기와 모든 기능이 같은 기능을 쓴다. 이 기능만 연 곳을 나눠 남긴다(T5-03, 리드 결정)
    launch:
        (context, _) => WalletHealthScreen.open(
          context,
          startCheck: true,
          source:
              FeatureLauncher.launchingSurface == FeatureSurface.allFeatures
                  ? WalletHealthEntry.allFeatures
                  : WalletHealthEntry.homeShortcut,
        ),
  ),
];
