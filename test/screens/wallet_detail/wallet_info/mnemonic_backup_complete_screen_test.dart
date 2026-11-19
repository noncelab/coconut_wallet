import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/mnemonic_backup_complete_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Auth extends Fake with ChangeNotifier implements AuthProvider {
  @override
  bool get isAuthEnabled => false;
}

void main() {
  testWidgets('the check and title sit in the upper part of the screen, not sagging below the middle', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _Auth(),
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
          home: const MnemonicBackupCompleteScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final title = find.text(t.wallet_home_screen.hot_wallet_setup.backup_complete_title);
    expect(tester.getCenter(title).dy, lessThan(874 * 0.4));
  });
}
