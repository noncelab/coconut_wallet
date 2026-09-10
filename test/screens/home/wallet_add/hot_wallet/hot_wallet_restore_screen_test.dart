import 'dart:async';

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_add/hot_wallet/hot_wallet_restore_screen.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/overlays/coconut_loading_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeWalletProvider extends Fake implements WalletProvider {
  @override
  List<WalletItemBase> get walletItemList => const [];
}

class _FakePreferenceProvider extends Fake implements PreferenceProvider {
  @override
  String get language => 'ko';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.ko);
  });

  testWidgets('복구 진입점은 첫 await 전부터 연속 제출을 차단하고 실패 후 guard를 해제한다', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          InheritedProvider<WalletProvider>.value(value: _FakeWalletProvider()),
          InheritedProvider<PreferenceProvider>.value(value: _FakePreferenceProvider()),
        ],
        child: MaterialApp(theme: buildCoconutThemeData(), home: const HotWalletRestoreScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    var hideCallCount = 0;
    final firstHideGate = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.textInput,
      (call) async {
        if (call.method == 'TextInput.hide') {
          hideCallCount++;
          await firstHideGate.future;
        }
        return null;
      },
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        null,
      ),
    );

    final button = tester.widget<FixedBottomButton>(find.byType(FixedBottomButton));
    final firstSubmission = button.onButtonClicked() as Future<void>;
    await tester.pump();
    final hideCallsAfterFirstSubmission = hideCallCount;
    final duplicateSubmission = button.onButtonClicked() as Future<void>;
    await duplicateSubmission;
    await tester.pump();

    expect(hideCallsAfterFirstSubmission, greaterThan(0));
    expect(hideCallCount, hideCallsAfterFirstSubmission);
    expect(tester.widget<FixedBottomButton>(find.byType(FixedBottomButton)).isActive, isFalse);

    firstHideGate.complete();
    await tester.pumpAndSettle();
    expect(find.text(t.wallet_home_screen.hot_wallet_restore.restore_failed), findsOneWidget);
    Navigator.of(tester.element(find.text(t.wallet_home_screen.hot_wallet_restore.restore_failed))).pop();
    await tester.pumpAndSettle();
    await firstSubmission;

    expect(find.byType(CoconutLoadingOverlay), findsNothing);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.textInput,
      (call) async {
        if (call.method == 'TextInput.hide') hideCallCount++;
        return null;
      },
    );
    final nextSubmission =
        tester.widget<FixedBottomButton>(find.byType(FixedBottomButton)).onButtonClicked() as Future<void>;
    await tester.pumpAndSettle();
    expect(hideCallCount, greaterThan(hideCallsAfterFirstSubmission));
    Navigator.of(tester.element(find.text(t.wallet_home_screen.hot_wallet_restore.restore_failed))).pop();
    await tester.pumpAndSettle();
    await nextSubmission;
  });
}
