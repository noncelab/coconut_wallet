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

  /// host surface에 기능을 보여줄지 여부.
  /// 지금은 [isActivated]를 그대로 따른다
  /// 즉, "활성화는 했지만 UI에서는 숨김" 같은 별도 상태는 아직 없다.
  ///
  /// [isActivated]와 분리해 둔 이유:
  /// 나중에 특정 CCOS 스토어 리스팅의 노출만 서버/설정값으로 개별 중단해야 하는 상황
  /// (예: 리스팅 정책 위반, 표기 오류)이 생기면 이 필드의 계산식만 바꾸면 되고,
  /// 이 값을 읽는 host surface 쪽 코드는 손댈 필요가 없다.
  /// 지갑의 서명·키 관리·트랜잭션 구성 등 핵심 동작에는 전혀 관여하지 않는,
  /// CCOS 스토어 리스팅 노출 범위에만 한정된 확장점이다.
  final bool isVisible;

  /// 사용자가 스토어에서 이 기능을 켰는지(선택/활성화 여부)
  /// `CcosFeatureActivationStore`에 저장된 activatedFeatureIds 로컬 상태로 결정된다.
  final bool isActivated;

  /// 사용자가 이 기능을 쓸 권한(결제 상태)이 있는지
  /// free는 항상 true, oneTimePurchase/subscription은 저장된 entitlement 기록을 따른다.
  final bool isEntitled;

  /// 지금 이 순간 실제로 사용 가능한지에 대한 최종 판정: `isActivated && isEntitled`.
  /// 활성화했지만 결제(entitlement)가 안 된 상태라면 false가 된다.
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
