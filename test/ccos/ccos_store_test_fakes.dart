import 'package:coconut_wallet/ccos/ccos_feature_runtime.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/providers/ark_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:flutter/foundation.dart';

class FakeStorePreferences extends ChangeNotifier implements PreferenceProvider {
  final Set<String> activated = {};
  CoconutThemeVariant variant = CoconutThemeVariant.dark;

  @override
  CoconutThemeVariant get themeVariant => variant;

  @override
  String get language => 'ko';

  @override
  bool get shouldShowOpenStoreIntroCard => false;

  @override
  CcosFeatureAvailability getCcosFeatureAvailability(String featureId) {
    final on = activated.contains(featureId);
    return CcosFeatureAvailability(
      featureId: featureId,
      isVisible: on,
      isActivated: on,
      isEntitled: true,
      isAvailable: on,
    );
  }

  @override
  Future<void> activateCcosFeature(String featureId) async {
    activated.add(featureId);
    notifyListeners();
  }

  @override
  Future<void> deactivateCcosFeature(String featureId) async {
    activated.remove(featureId);
    notifyListeners();
  }

  @override
  Future<void> changeThemeVariant(CoconutThemeVariant variant) async {
    this.variant = variant;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStoreArk extends ChangeNotifier implements ArkProvider {
  bool inUse = false;

  @override
  bool get hasArkOnWallet => inUse;

  bool enabled = true;

  bool listed = true;

  @override
  bool get arkWalletsListed => listed;

  @override
  bool get isEnabled => enabled;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
