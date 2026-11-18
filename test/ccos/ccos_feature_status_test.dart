import 'package:coconut_wallet/ccos/ccos_feature_status.dart';
import 'package:coconut_wallet/ccos/features/coconut_theme/coconut_theme_feature.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  _Preferences(this.variant);

  CoconutThemeVariant variant;

  @override
  CoconutThemeVariant get themeVariant => variant;
}

void main() {
  test('unregistered feature is not in use and removable', () {
    final registry = CcosFeatureStatusRegistry();

    final status = registry.statusOf('x', isActivated: true);

    expect(status.inUse, isFalse);
    expect(status.canRemove, isTrue);
  });

  test('registered reporter decides the status', () {
    final registry =
        CcosFeatureStatusRegistry()..register(
          'f',
          ({required isActivated}) => CcosFeatureStatus(inUse: isActivated, removeBlockedReason: 'busy'),
        );

    final status = registry.statusOf('f', isActivated: true);

    expect(status.inUse, isTrue);
    expect(status.canRemove, isFalse);
  });

  test('registry notifies when a source changes', () {
    final source = ValueNotifier(0);
    final registry =
        CcosFeatureStatusRegistry()
          ..register('f', ({required isActivated}) => const CcosFeatureStatus(), changes: source);
    var notified = 0;
    registry.addListener(() => notified++);

    source.value = 1;

    expect(notified, 1);
  });

  test('theme is in use only when added and selected', () {
    final preferences = _Preferences(CoconutThemeVariant.coconutTheme);

    final selected = CoconutThemeFeature.status(preferences, isActivated: true);
    expect(selected.inUse, isTrue);
    expect(selected.beforeRemove, isNotNull);
    expect(CoconutThemeFeature.status(preferences, isActivated: false).inUse, isFalse);

    preferences.variant = CoconutThemeVariant.dark;
    final other = CoconutThemeFeature.status(preferences, isActivated: true);
    expect(other.inUse, isFalse);
    expect(other.beforeRemove, isNull);
  });
}
