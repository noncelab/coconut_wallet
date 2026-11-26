import 'package:coconut_wallet/ccos/ccos_feature_status.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_feature.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_server_config.dart';
import 'package:coconut_wallet/ccos/features/coconut_theme/coconut_theme_feature.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ccos_store_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../ccos/ccos_store_test_fakes.dart';

void main() {
  late FakeStorePreferences preferences;
  late CcosFeatureStatusRegistry statuses;
  late CcosStoreViewModel viewModel;

  setUp(() {
    preferences = FakeStorePreferences();
    statuses = storeStatusRegistry(preferences);
    viewModel = CcosStoreViewModel(preferences, statuses);
  });

  tearDown(() => viewModel.dispose());

  test('a feature never added is notAdded', () {
    expect(viewModel.stateOf(CoconutThemeFeature.id), CcosStoreItemState.notAdded);
  });

  test('ark in a regtest build without a server is mainnet only with a notice', () {
    ArkServerConfig.isConfiguredOverride = false;
    ArkServerConfig.isRegtestOverride = true;
    addTearDown(() {
      ArkServerConfig.isConfiguredOverride = null;
      ArkServerConfig.isRegtestOverride = null;
    });

    expect(viewModel.stateOf(ArkFeature.id), CcosStoreItemState.unavailable);
    expect(viewModel.unavailableNoticeOf(ArkFeature.id), t.ark_wallet.store_mainnet_only);
    expect(viewModel.unavailableNoticeOf(CoconutThemeFeature.id), isNull);
  });

  test('an added feature the registry reports in use is applied', () {
    preferences.activated.add(CoconutThemeFeature.id);
    preferences.variant = CoconutThemeVariant.coconutTheme;

    expect(viewModel.stateOf(CoconutThemeFeature.id), CcosStoreItemState.applied);
  });

  test('an added feature not in use is added', () {
    preferences.activated.add(CoconutThemeFeature.id);

    expect(viewModel.stateOf(CoconutThemeFeature.id), CcosStoreItemState.added);
  });

  test('a blocked feature cannot be removed and keeps its reason', () async {
    statuses.register('blocked', ({required isActivated}) => const CcosFeatureStatus(removeBlockedReason: '막힘'));
    preferences.activated.add('blocked');

    expect(viewModel.removeBlockedReasonOf('blocked'), '막힘');
    expect((await viewModel.remove('blocked')).removed, isFalse);
    expect(preferences.activated, contains('blocked'));
  });

  test('using the coconut theme, removing switches to dark first', () async {
    preferences.activated.add(CoconutThemeFeature.id);
    preferences.variant = CoconutThemeVariant.coconutTheme;

    expect(viewModel.needsRemoveConfirm(CoconutThemeFeature.id), isTrue);
    expect((await viewModel.remove(CoconutThemeFeature.id)).removed, isTrue);
    expect(preferences.variant, CoconutThemeVariant.dark);
    expect(preferences.activated, isNot(contains(CoconutThemeFeature.id)));
  });

  test('an added theme not in use is removed without confirm', () async {
    await viewModel.add(CoconutThemeFeature.id);

    expect(viewModel.needsRemoveConfirm(CoconutThemeFeature.id), isFalse);
    expect((await viewModel.remove(CoconutThemeFeature.id)).removed, isTrue);
    expect(viewModel.stateOf(CoconutThemeFeature.id), CcosStoreItemState.notAdded);
  });

  test('status changes notify the store', () {
    var notified = 0;
    viewModel.addListener(() => notified++);

    statuses.notifyListeners();

    expect(notified, 1);
  });

  group('toast', () {
    void recordOnChange(String featureId) {
      preferences.addListener(() {
        preferences.activated.contains(featureId)
            ? statuses.homeEntries.shortcutAdded(featureId, '이름')
            : statuses.homeEntries.shortcutRemoved(featureId, '이름');
      });
    }

    test('adding names the shortcut home added', () async {
      recordOnChange('x');

      expect(await viewModel.add('x'), t.ccos.store.shortcut_added(name: '이름'));
    });

    test('a stale shortcut record is not used', () async {
      statuses.homeEntries.shortcutAdded('x', '예전');

      expect(await viewModel.add('x'), t.ccos.store.added_toast(name: 'x'));
    });

    test('removing names the shortcut home removed', () async {
      preferences.activated.add('x');
      recordOnChange('x');

      expect((await viewModel.remove('x')).toast, t.ccos.store.shortcut_removed(name: '이름'));
    });

    test('the coconut theme says where it shows up', () async {
      final listing = CoconutThemeFeature.listing;

      expect(await viewModel.add(CoconutThemeFeature.id), listing.addedToast);
      expect((await viewModel.remove(CoconutThemeFeature.id)).toast, listing.removedToast);
      expect(listing.addedToast, isNotNull);
      expect(listing.removedToast, isNotNull);
    });

    test('other features fall back to their name', () async {
      preferences.activated.add('x');

      expect((await viewModel.remove('x')).toast, t.ccos.store.removed_toast(name: 'x'));
    });
  });
}
