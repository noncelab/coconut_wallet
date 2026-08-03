import 'dart:convert';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';

enum CcosFeatureEntitlementSource {
  localSnapshot,
  appStore,
  playStore,
  unknown,
}

class CcosFeatureEntitlement {
  const CcosFeatureEntitlement({
    required this.featureId,
    required this.isEntitled,
    required this.source,
    required this.updatedAt,
  });

  final String featureId;
  final bool isEntitled;
  final CcosFeatureEntitlementSource source;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'featureId': featureId,
    'isEntitled': isEntitled,
    'source': source.name,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CcosFeatureEntitlement.fromJson(Map<String, dynamic> json) {
    return CcosFeatureEntitlement(
      featureId: json['featureId'] as String,
      isEntitled: json['isEntitled'] as bool? ?? false,
      source: CcosFeatureEntitlementSource.values.firstWhere(
        (value) => value.name == json['source'],
        orElse: () => CcosFeatureEntitlementSource.unknown,
      ),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class CcosFeatureAvailability {
  const CcosFeatureAvailability({
    required this.featureId,
    required this.isVisible,
    required this.isActivated,
    required this.isEntitled,
    required this.isAvailable,
  });

  final String featureId;
  final bool isVisible;
  final bool isActivated;
  final bool isEntitled;
  final bool isAvailable;
}

abstract interface class CcosFeatureActivationStore {
  Future<Set<String>> loadActivatedFeatureIds();

  Future<void> setActivated(String featureId, bool isActivated);
}

abstract interface class CcosFeatureEntitlementStore {
  Future<Map<String, CcosFeatureEntitlement>> loadEntitlements();

  Future<void> saveEntitlements(Iterable<CcosFeatureEntitlement> entitlements);
}

class SharedPrefsCcosFeatureActivationStore
    implements CcosFeatureActivationStore {
  SharedPrefsCcosFeatureActivationStore(this._sharedPrefsRepository);

  final SharedPrefsRepository _sharedPrefsRepository;

  @override
  Future<Set<String>> loadActivatedFeatureIds() async {
    final encoded = _sharedPrefsRepository.getStringOrNull(
      SharedPrefKeys.kCcosActivatedFeatureIds,
    );
    if (encoded == null || encoded.isEmpty) return <String>{};
    try {
      final decoded = json.decode(encoded);
      if (decoded is! List) return <String>{};
      return decoded.whereType<String>().toSet();
    } catch (_) {
      return <String>{};
    }
  }

  @override
  Future<void> setActivated(String featureId, bool isActivated) async {
    final activated = await loadActivatedFeatureIds();
    if (isActivated) {
      activated.add(featureId);
    } else {
      activated.remove(featureId);
    }
    await _sharedPrefsRepository.setString(
      SharedPrefKeys.kCcosActivatedFeatureIds,
      json.encode(activated.toList()..sort()),
    );
  }
}

class SharedPrefsCcosFeatureEntitlementStore
    implements CcosFeatureEntitlementStore {
  SharedPrefsCcosFeatureEntitlementStore(this._sharedPrefsRepository);

  final SharedPrefsRepository _sharedPrefsRepository;

  @override
  Future<Map<String, CcosFeatureEntitlement>> loadEntitlements() async {
    final encoded = _sharedPrefsRepository.getStringOrNull(
      SharedPrefKeys.kCcosEntitlementSnapshots,
    );
    if (encoded == null || encoded.isEmpty) {
      return <String, CcosFeatureEntitlement>{};
    }
    try {
      final decoded = json.decode(encoded);
      if (decoded is! Map<String, dynamic>) {
        return <String, CcosFeatureEntitlement>{};
      }
      return decoded.map(
        (key, value) => MapEntry(
          key,
          CcosFeatureEntitlement.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        ),
      );
    } catch (_) {
      return <String, CcosFeatureEntitlement>{};
    }
  }

  @override
  Future<void> saveEntitlements(
    Iterable<CcosFeatureEntitlement> entitlements,
  ) async {
    final payload = {
      for (final entitlement in entitlements)
        entitlement.featureId: entitlement.toJson(),
    };
    await _sharedPrefsRepository.setString(
      SharedPrefKeys.kCcosEntitlementSnapshots,
      json.encode(payload),
    );
  }
}

class CcosFeatureAvailabilityResolver {
  const CcosFeatureAvailabilityResolver();

  CcosFeatureAvailability resolve({
    required CcosFeatureListing listing,
    required Set<String> activatedFeatureIds,
    required Map<String, CcosFeatureEntitlement> entitlements,
  }) {
    final isActivated = activatedFeatureIds.contains(listing.id);
    final entitlement = entitlements[listing.id];
    final isEntitled = switch (listing.priceType) {
      CcosListingPriceType.free => true,
      CcosListingPriceType.oneTimePurchase => entitlement?.isEntitled ?? false,
      CcosListingPriceType.subscription => entitlement?.isEntitled ?? false,
    };

    return CcosFeatureAvailability(
      featureId: listing.id,
      isVisible: true,
      isActivated: isActivated,
      isEntitled: isEntitled,
      isAvailable: isActivated && isEntitled,
    );
  }
}
