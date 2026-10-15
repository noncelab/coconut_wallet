import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/ccos/ccos_feature_runtime.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([SharedPreferences])
import 'ccos_feature_runtime_test.mocks.dart';

CcosFeatureListing _listing({required CcosListingPriceType priceType, String id = 'test-feature'}) {
  return CcosFeatureListing(
    id: id,
    category: CcosFeatureCategory.theme,
    title: 'Test Feature',
    description: 'A test feature',
    author: 'Test Author',
    authorBio: 'Test bio',
    authorIntent: 'Test intent',
    whyItBelongs: 'Test rationale',
    featureHelp: 'Test help',
    priceType: priceType,
    linkedVariant: CoconutThemeVariant.dark,
  );
}

void main() {
  group('CcosFeatureAvailabilityResolver', () {
    const resolver = CcosFeatureAvailabilityResolver();

    test('무료 기능은 entitlement 기록이 없어도 항상 사용 권한이 있다', () {
      final listing = _listing(priceType: CcosListingPriceType.free);

      final notActivated = resolver.resolve(listing: listing, activatedFeatureIds: const {}, entitlements: const {});
      expect(notActivated.isActivated, isFalse);
      expect(notActivated.isEntitled, isTrue);
      expect(notActivated.isAvailable, isFalse); // not activated yet
      expect(notActivated.isVisible, isFalse);

      final activated = resolver.resolve(listing: listing, activatedFeatureIds: {listing.id}, entitlements: const {});
      expect(activated.isActivated, isTrue);
      expect(activated.isEntitled, isTrue);
      expect(activated.isAvailable, isTrue);
      expect(activated.isVisible, isTrue);
    });

    test('1회 구매 기능은 일치하는 entitlement가 있어야 사용 가능하다', () {
      final listing = _listing(priceType: CcosListingPriceType.oneTimePurchase);

      final activatedWithoutEntitlement = resolver.resolve(
        listing: listing,
        activatedFeatureIds: {listing.id},
        entitlements: const {},
      );
      expect(activatedWithoutEntitlement.isEntitled, isFalse);
      expect(activatedWithoutEntitlement.isAvailable, isFalse);

      final entitlement = CcosFeatureEntitlement(
        featureId: listing.id,
        isEntitled: true,
        source: CcosFeatureEntitlementSource.appStore,
        updatedAt: DateTime(2026),
      );
      final activatedWithEntitlement = resolver.resolve(
        listing: listing,
        activatedFeatureIds: {listing.id},
        entitlements: {listing.id: entitlement},
      );
      expect(activatedWithEntitlement.isEntitled, isTrue);
      expect(activatedWithEntitlement.isAvailable, isTrue);
    });

    test('구독 기능은 entitlement이 취소되면 사용 가능 상태를 잃는다', () {
      final listing = _listing(priceType: CcosListingPriceType.subscription);
      final revoked = CcosFeatureEntitlement(
        featureId: listing.id,
        isEntitled: false,
        source: CcosFeatureEntitlementSource.playStore,
        updatedAt: DateTime(2026),
      );

      final result = resolver.resolve(
        listing: listing,
        activatedFeatureIds: {listing.id},
        entitlements: {listing.id: revoked},
      );

      expect(result.isEntitled, isFalse);
      expect(result.isAvailable, isFalse);
    });

    test('다른 기능 id로 기록된 entitlement는 무시된다', () {
      final listing = _listing(priceType: CcosListingPriceType.oneTimePurchase, id: 'feature-a');
      final entitlement = CcosFeatureEntitlement(
        featureId: 'feature-b',
        isEntitled: true,
        source: CcosFeatureEntitlementSource.localSnapshot,
        updatedAt: DateTime(2026),
      );

      final result = resolver.resolve(
        listing: listing,
        activatedFeatureIds: {listing.id},
        entitlements: {'feature-b': entitlement},
      );

      expect(result.isEntitled, isFalse);
      expect(result.isAvailable, isFalse);
    });
  });

  group('SharedPrefsCcosFeatureActivationStore', () {
    late SharedPrefsRepository sharedPrefs;
    late MockSharedPreferences mockPrefs;
    late SharedPrefsCcosFeatureActivationStore store;

    setUp(() {
      mockPrefs = MockSharedPreferences();
      sharedPrefs = SharedPrefsRepository();
      sharedPrefs.setSharedPreferencesForTest(mockPrefs);
      store = SharedPrefsCcosFeatureActivationStore(sharedPrefs);
    });

    test('저장된 값이 없으면 빈 Set을 반환한다', () async {
      when(mockPrefs.getString(SharedPrefKeys.kCcosActivatedFeatureIds)).thenReturn(null);

      final result = await store.loadActivatedFeatureIds();

      expect(result, isEmpty);
    });

    test('저장된 값이 손상되어 있으면 빈 Set으로 대체한다', () async {
      when(mockPrefs.getString(SharedPrefKeys.kCcosActivatedFeatureIds)).thenReturn('not-json');

      final result = await store.loadActivatedFeatureIds();

      expect(result, isEmpty);
    });

    test('setActivated(true)는 저장된 Set에 기능 id를 추가한다', () async {
      when(mockPrefs.getString(SharedPrefKeys.kCcosActivatedFeatureIds)).thenReturn(null);
      when(mockPrefs.setString(SharedPrefKeys.kCcosActivatedFeatureIds, any)).thenAnswer((_) async => true);

      await store.setActivated('coconut_pulp', true);

      final captured =
          verify(mockPrefs.setString(SharedPrefKeys.kCcosActivatedFeatureIds, captureAny)).captured.single as String;
      expect(captured, contains('coconut_pulp'));
    });

    test('setActivated(false)는 저장된 Set에서 기능 id를 제거한다', () async {
      when(mockPrefs.getString(SharedPrefKeys.kCcosActivatedFeatureIds)).thenReturn('["coconut_pulp","other"]');
      when(mockPrefs.setString(SharedPrefKeys.kCcosActivatedFeatureIds, any)).thenAnswer((_) async => true);

      await store.setActivated('coconut_pulp', false);

      final captured =
          verify(mockPrefs.setString(SharedPrefKeys.kCcosActivatedFeatureIds, captureAny)).captured.single as String;
      expect(captured, isNot(contains('coconut_pulp')));
      expect(captured, contains('other'));
    });
  });

  group('SharedPrefsCcosFeatureEntitlementStore', () {
    late SharedPrefsRepository sharedPrefs;
    late MockSharedPreferences mockPrefs;
    late SharedPrefsCcosFeatureEntitlementStore store;

    setUp(() {
      mockPrefs = MockSharedPreferences();
      sharedPrefs = SharedPrefsRepository();
      sharedPrefs.setSharedPreferencesForTest(mockPrefs);
      store = SharedPrefsCcosFeatureEntitlementStore(sharedPrefs);
    });

    test('저장된 값이 없으면 빈 Map을 반환한다', () async {
      when(mockPrefs.getString(SharedPrefKeys.kCcosEntitlementSnapshots)).thenReturn(null);

      final result = await store.loadEntitlements();

      expect(result, isEmpty);
    });

    test('저장된 값이 손상되어 있으면 빈 Map으로 대체한다', () async {
      when(mockPrefs.getString(SharedPrefKeys.kCcosEntitlementSnapshots)).thenReturn('not-json');

      final result = await store.loadEntitlements();

      expect(result, isEmpty);
    });

    test('saveEntitlements로 저장한 값을 loadEntitlements로 그대로 복원할 수 있다', () async {
      final entitlement = CcosFeatureEntitlement(
        featureId: 'coconut_pulp',
        isEntitled: true,
        source: CcosFeatureEntitlementSource.appStore,
        updatedAt: DateTime(2026, 8, 12),
      );

      String? savedJson;
      when(mockPrefs.setString(SharedPrefKeys.kCcosEntitlementSnapshots, any)).thenAnswer((invocation) async {
        savedJson = invocation.positionalArguments[1] as String;
        return true;
      });

      await store.saveEntitlements([entitlement]);

      when(mockPrefs.getString(SharedPrefKeys.kCcosEntitlementSnapshots)).thenReturn(savedJson);
      final loaded = await store.loadEntitlements();

      expect(loaded, hasLength(1));
      expect(loaded['coconut_pulp']?.isEntitled, isTrue);
      expect(loaded['coconut_pulp']?.source, CcosFeatureEntitlementSource.appStore);
    });
  });
}
