import 'package:coconut_wallet/ccos/features/ark/ark_feature.dart';
import 'package:coconut_wallet/ccos/features/coconut_theme/coconut_theme_feature.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ccos_store_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../ccos/ccos_store_test_fakes.dart';

void main() {
  late FakeStorePreferences preferences;
  late FakeStoreArk ark;
  late CcosStoreViewModel viewModel;

  setUp(() {
    preferences = FakeStorePreferences();
    ark = FakeStoreArk();
    viewModel = CcosStoreViewModel(preferences, arkProvider: ark);
  });

  tearDown(() => viewModel.dispose());

  test('a feature never added is notAdded', () {
    expect(viewModel.stateOf(ArkFeature.id), CcosStoreItemState.notAdded);
    expect(viewModel.stateOf(CoconutThemeFeature.id), CcosStoreItemState.notAdded);
  });

  test('an active theme that is the current theme is applied', () {
    preferences.activated.add(CoconutThemeFeature.id);
    preferences.variant = CoconutThemeVariant.coconutTheme;

    expect(viewModel.stateOf(CoconutThemeFeature.id), CcosStoreItemState.applied);
  });

  test('an active theme not in use is added', () {
    preferences.activated.add(CoconutThemeFeature.id);

    expect(viewModel.stateOf(CoconutThemeFeature.id), CcosStoreItemState.added);
  });

  test('ark is applied when a wallet uses it and cannot be removed', () async {
    preferences.activated.add(ArkFeature.id);
    ark.inUse = true;

    expect(viewModel.stateOf(ArkFeature.id), CcosStoreItemState.applied);
    expect(viewModel.removeBlockOf(ArkFeature.id), CcosRemoveBlock.arkInUse);
    expect(await viewModel.remove(ArkFeature.id), isFalse);
    expect(preferences.activated, contains(ArkFeature.id));
  });

  test('ark not used by any wallet can be removed', () async {
    await viewModel.add(ArkFeature.id);

    expect(viewModel.stateOf(ArkFeature.id), CcosStoreItemState.added);
    expect(viewModel.removeBlockOf(ArkFeature.id), isNull);
    expect(await viewModel.remove(ArkFeature.id), isTrue);
    expect(viewModel.stateOf(ArkFeature.id), CcosStoreItemState.notAdded);
  });

  test('removing an applied theme switches to dark first', () async {
    preferences.activated.add(CoconutThemeFeature.id);
    preferences.variant = CoconutThemeVariant.coconutTheme;

    expect(viewModel.needsRemoveConfirm(CoconutThemeFeature.id), isTrue);
    expect(await viewModel.remove(CoconutThemeFeature.id), isTrue);
    expect(preferences.variant, CoconutThemeVariant.dark);
    expect(preferences.activated, isNot(contains(CoconutThemeFeature.id)));
  });

  test('provider changes notify the store', () async {
    var notified = 0;
    viewModel.addListener(() => notified++);

    await preferences.activateCcosFeature(ArkFeature.id);
    ark.notifyListeners();

    expect(notified, 2);
  });

  test('ark cannot be removed until the ark wallets are checked', () async {
    preferences.activated.add(ArkFeature.id);
    ark.listed = false;

    expect(viewModel.removeBlockOf(ArkFeature.id), CcosRemoveBlock.arkChecking);
    expect(await viewModel.remove(ArkFeature.id), isFalse);
    expect(preferences.activated, contains(ArkFeature.id));
  });

  test('ark used by a wallet is applied even if the feature was never added', () {
    ark.inUse = true;

    expect(viewModel.stateOf(ArkFeature.id), CcosStoreItemState.applied);
  });
}
