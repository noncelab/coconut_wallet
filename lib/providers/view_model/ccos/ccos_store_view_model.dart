import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_feature.dart';
import 'package:coconut_wallet/ccos/features/coconut_theme/coconut_theme_feature.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/providers/ark_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:flutter/foundation.dart';

enum CcosStoreItemState { notAdded, added, applied }

enum CcosRemoveBlock { arkInUse, arkChecking }

/// 오픈 스토어의 기능 목록과 추가·적용·제거 상태
class CcosStoreViewModel extends ChangeNotifier {
  CcosStoreViewModel(this._preferences, {ArkProvider? arkProvider}) : _arkProvider = arkProvider {
    _preferences.addListener(notifyListeners);
    _arkProvider?.addListener(notifyListeners);
  }

  final PreferenceProvider _preferences;
  final ArkProvider? _arkProvider;

  List<CcosFeatureListing> get listings => CcosFeatureRegistrySource.allListings;

  CcosFeatureListing? listingOf(String featureId) => CcosFeatureRegistrySource.findListingById(featureId);

  CcosStoreItemState stateOf(String featureId) {
    final isActivated = _preferences.getCcosFeatureAvailability(featureId).isActivated;
    final usage = CcosFeatureUsage(
      isActivated: isActivated,
      themeVariant: _preferences.themeVariant,
      hasArkOnWallet: _arkProvider?.hasArkOnWallet ?? false,
    );
    if (listingOf(featureId)?.isApplied(usage) ?? false) return CcosStoreItemState.applied;
    return isActivated ? CcosStoreItemState.added : CcosStoreItemState.notAdded;
  }

  CcosRemoveBlock? removeBlockOf(String featureId) {
    if (featureId != ArkFeature.id) return null;
    if (stateOf(featureId) == CcosStoreItemState.applied) return CcosRemoveBlock.arkInUse;
    if (_arkProvider != null && !_arkProvider.arkWalletsListed) return CcosRemoveBlock.arkChecking;
    return null;
  }

  bool needsRemoveConfirm(String featureId) =>
      featureId == CoconutThemeFeature.id && stateOf(featureId) == CcosStoreItemState.applied;

  Future<void> add(String featureId) => _preferences.activateCcosFeature(featureId);

  /// 막혀 있으면 false. 적용 중인 테마는 다크 테마로 바꾼 뒤 제거
  Future<bool> remove(String featureId) async {
    if (removeBlockOf(featureId) != null) return false;
    if (needsRemoveConfirm(featureId)) await _preferences.changeThemeVariant(CoconutThemeVariant.dark);
    await _preferences.deactivateCcosFeature(featureId);
    return true;
  }

  @override
  void dispose() {
    _preferences.removeListener(notifyListeners);
    _arkProvider?.removeListener(notifyListeners);
    super.dispose();
  }
}
