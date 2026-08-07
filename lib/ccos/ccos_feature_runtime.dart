import 'dart:convert';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';

/// 실제 결제 연동 전까지는 [localSnapshot]만 쓰인다.
///
/// `appStore`/`playStore`는 유의미한 유료 기능 PR이 실제로 merge된 뒤,
/// 배포 시점에 코코넛 개발팀이 In-App Purchase를 연동하면서 채워질 자리다
/// (`docs/ccos/foundation/monetization_guide.md` 참고).
///
/// **이 연동은 외부 기여자의 역할이 아니다.**
/// 기여자는 `priceType`으로 무료 / 1회 구매 / 구독 후보를 제안할 뿐이고,
/// 실제 entitlement 연동(구매 버튼, 결제 파이프라인, 영수증 검증,
/// `markCcosFeaturePurchased`/`purchaseAndActivateCcosFeature`를 실제로 호출하는 코드)은
/// 계약 체결 후 코코넛 개발팀(리뷰어 또는 배포 담당자)이 담당한다
/// (`docs/ccos/foundation/architecture.md` 6.2절 참고).
///
/// 실제 연동 시 필요한 것:
/// - App Store Connect / Play Console에 상품(feature id 기준) 등록
/// - 영수증 검증은 클라이언트에서 끝내지 않고 서버(또는 서버리스 함수)에서 수행
/// - [CcosFeatureEntitlementStore]는 그 검증 결과의 로컬 캐시로만 남기고,
///   entitlement의 최종 근거(source of truth)는 서버 쪽에 둔다.
enum CcosFeatureEntitlementSource { localSnapshot, appStore, playStore, unknown }

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
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
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

class SharedPrefsCcosFeatureActivationStore implements CcosFeatureActivationStore {
  SharedPrefsCcosFeatureActivationStore(this._sharedPrefsRepository);

  final SharedPrefsRepository _sharedPrefsRepository;

  @override
  Future<Set<String>> loadActivatedFeatureIds() async {
    final encoded = _sharedPrefsRepository.getStringOrNull(SharedPrefKeys.kCcosActivatedFeatureIds);
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

class SharedPrefsCcosFeatureEntitlementStore implements CcosFeatureEntitlementStore {
  SharedPrefsCcosFeatureEntitlementStore(this._sharedPrefsRepository);

  final SharedPrefsRepository _sharedPrefsRepository;

  @override
  Future<Map<String, CcosFeatureEntitlement>> loadEntitlements() async {
    final encoded = _sharedPrefsRepository.getStringOrNull(SharedPrefKeys.kCcosEntitlementSnapshots);
    if (encoded == null || encoded.isEmpty) {
      return <String, CcosFeatureEntitlement>{};
    }
    try {
      final decoded = json.decode(encoded);
      if (decoded is! Map<String, dynamic>) {
        return <String, CcosFeatureEntitlement>{};
      }
      return decoded.map(
        (key, value) => MapEntry(key, CcosFeatureEntitlement.fromJson(Map<String, dynamic>.from(value as Map))),
      );
    } catch (_) {
      return <String, CcosFeatureEntitlement>{};
    }
  }

  @override
  Future<void> saveEntitlements(Iterable<CcosFeatureEntitlement> entitlements) async {
    final payload = {for (final entitlement in entitlements) entitlement.featureId: entitlement.toJson()};
    await _sharedPrefsRepository.setString(SharedPrefKeys.kCcosEntitlementSnapshots, json.encode(payload));
  }
}

class CcosFeatureAvailabilityResolver {
  const CcosFeatureAvailabilityResolver();

  /// 실제 프로세스: 스토어(예: `coconut_open_store_intro_screen.dart`)에서
  /// 사용자가 기능을 활성화하면 — 유료 기능이면 먼저 구매(entitlement 발급)를
  /// 거친 뒤 — [CcosFeatureActivationStore]에 activated로 기록된다. 진입점
  /// (host surface, 예: `theme_bottom_sheet.dart`)은 이 [isActivated] 여부만
  /// 보고 실제로 사용 가능한 옵션으로 노출할지 정한다. `isVisible`은 그
  /// 진입점 노출 상태를 그대로 나타내며, 별도의 "스토어에서 숨기기" 같은
  /// 독립적인 설정은 없다 — 앱 진입 시 [activatedFeatureIds]를 다시 읽어
  /// 계산되므로, 마지막 활성화 상태가 항상 반영된다.
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
      isVisible: isActivated,
      isActivated: isActivated,
      isEntitled: isEntitled,
      isAvailable: isActivated && isEntitled,
    );
  }
}
