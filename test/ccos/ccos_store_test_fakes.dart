import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/ccos/ccos_feature_runtime.dart';
import 'package:coconut_wallet/ccos/ccos_feature_status.dart';
import 'package:coconut_wallet/ccos/features/coconut_theme/coconut_theme_feature.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:flutter/foundation.dart';

class FakeStorePreferences extends ChangeNotifier implements PreferenceProvider {
  final Set<String> activated = {};
  CoconutThemeVariant variant = CoconutThemeVariant.dark;

  @override
  CoconutThemeVariant get themeVariant => variant;

  @override
  BitcoinUnit get currentUnit => BitcoinUnit.sats;

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

CcosFeatureStatusRegistry storeStatusRegistry(FakeStorePreferences preferences) =>
    CcosFeatureStatusRegistry()..register(
      CoconutThemeFeature.id,
      ({required isActivated}) => CoconutThemeFeature.status(preferences, isActivated: isActivated),
      changes: preferences,
    );

const blockedReasonForTest = '사용 중인 지갑이 있어 제거할 수 없어요';

CcosFeatureStatusRegistry storeStatusRegistryWith(FakeStorePreferences preferences, {Set<String> inUse = const {}}) {
  final registry = storeStatusRegistry(preferences);
  for (final id in inUse) {
    registry.register(
      id,
      ({required isActivated}) => const CcosFeatureStatus(inUse: true, removeBlockedReason: blockedReasonForTest),
    );
  }
  return registry;
}
