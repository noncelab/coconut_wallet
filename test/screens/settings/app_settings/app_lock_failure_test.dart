import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/settings/app_settings/app_settings_screen.dart';
import 'package:coconut_wallet/services/security/pin_auth_service.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart' as overlays;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Auth extends Fake with ChangeNotifier implements AuthProvider {
  final PinAuthError error;
  int deletions = 0;
  _Auth(this.error);
  @override
  bool get isSetPin => true;
  @override
  bool get canCheckBiometrics => false;
  @override
  Future<bool> isBiometricsAuthValid() async => true;
  @override
  Future<void> deletePin() async {
    deletions++;
    throw PinAuthException(error);
  }
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.btc;
  @override
  FiatCode get selectedFiat => FiatCode.USD;
  @override
  String get language => 'ko';
  @override
  bool get isManualUtxoSelectionMode => false;
  @override
  CoconutThemeVariant get themeVariant => CoconutThemeVariant.dark;
}

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  @override
  bool get hasHotWalletWithBalance => false;
}

void main() {
  for (final error in [PinAuthError.unavailable, PinAuthError.unauthorized, PinAuthError.stateUncertain]) {
    testWidgets('lock disable failure $error shows actionable message and allows retry', (tester) async {
      NetworkType.setNetworkType(NetworkType.regtest);
      LocaleSettings.setLocaleSync(AppLocale.ko);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = _Auth(error);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<PreferenceProvider>.value(value: _Preferences()),
            ChangeNotifierProvider<WalletProvider>.value(value: _Wallets()),
          ],
          child: MaterialApp(theme: buildCoconutThemeData(), home: const AppSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      tester.widget<CoconutSwitch>(find.byType(CoconutSwitch).first).onChanged(false);
      await tester.pumpAndSettle();
      final popup = tester.widget<overlays.CoconutPopup>(find.byType(overlays.CoconutPopup));
      final expected = switch (error) {
        PinAuthError.unauthorized => t.errors.pin_setting_error.authentication_required,
        PinAuthError.stateUncertain => t.errors.pin_setting_error.state_uncertain,
        _ => t.errors.pin_setting_error.process_failed,
      };
      expect(popup.description, expected);
      expect(tester.takeException(), isNull);
      popup.onTapRight();
      await tester.pumpAndSettle();
      tester.widget<CoconutSwitch>(find.byType(CoconutSwitch).first).onChanged(false);
      await tester.pumpAndSettle();
      expect(auth.deletions, 2);
      expect(find.byType(overlays.CoconutPopup), findsOneWidget);
      expect(auth.isSetPin, isTrue);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
