import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/ccos/ccos_feature_status.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:flutter/foundation.dart';

enum CcosStoreItemState { notAdded, added, applied }

class CcosStoreRemoval {
  const CcosStoreRemoval({required this.removed, this.toast});

  final bool removed;
  final String? toast;
}

/// 오픈 스토어의 기능 목록과 추가·사용 중·제거 상태
class CcosStoreViewModel extends ChangeNotifier {
  CcosStoreViewModel(this._preferences, this._statuses) {
    _preferences.addListener(notifyListeners);
    _statuses.addListener(notifyListeners);
  }

  final PreferenceProvider _preferences;
  final CcosFeatureStatusRegistry _statuses;

  List<CcosFeatureListing> get listings => CcosFeatureRegistrySource.allListings;

  CcosFeatureListing? listingOf(String featureId) => CcosFeatureRegistrySource.findListingById(featureId);

  bool _isActivated(String featureId) => _preferences.getCcosFeatureAvailability(featureId).isActivated;

  CcosFeatureStatus _statusOf(String featureId) => _statuses.statusOf(featureId, isActivated: _isActivated(featureId));

  CcosStoreItemState stateOf(String featureId) {
    if (_statusOf(featureId).inUse) return CcosStoreItemState.applied;
    return _isActivated(featureId) ? CcosStoreItemState.added : CcosStoreItemState.notAdded;
  }

  String? removeBlockedReasonOf(String featureId) => _statusOf(featureId).removeBlockedReason;

  bool needsRemoveConfirm(String featureId) => _statusOf(featureId).beforeRemove != null;

  String _nameOf(String featureId) => listingOf(featureId)?.title ?? featureId;

  /// 추가한 뒤 보여 줄 알림을 돌려준다
  Future<String> add(String featureId) async {
    _statuses.homeEntries.takeAdded(featureId);
    await _preferences.activateCcosFeature(featureId);
    final shortcut = _statuses.homeEntries.takeAdded(featureId);
    if (shortcut != null) return t.ccos.store.shortcut_added(name: shortcut);
    return listingOf(featureId)?.addedToast ?? t.ccos.store.added_toast(name: _nameOf(featureId));
  }

  Future<CcosStoreRemoval> remove(String featureId) async {
    final status = _statusOf(featureId);
    if (!status.canRemove) return const CcosStoreRemoval(removed: false);
    await status.beforeRemove?.call();
    _statuses.homeEntries.takeRemoved(featureId);
    await _preferences.deactivateCcosFeature(featureId);
    final shortcut = _statuses.homeEntries.takeRemoved(featureId);
    final toast =
        shortcut != null
            ? t.ccos.store.shortcut_removed(name: shortcut)
            : listingOf(featureId)?.removedToast ?? t.ccos.store.removed_toast(name: _nameOf(featureId));
    return CcosStoreRemoval(removed: true, toast: toast);
  }

  @override
  void dispose() {
    _preferences.removeListener(notifyListeners);
    _statuses.removeListener(notifyListeners);
    super.dispose();
  }
}
