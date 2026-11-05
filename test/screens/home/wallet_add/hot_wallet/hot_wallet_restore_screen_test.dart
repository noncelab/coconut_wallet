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
import 'package:coconut_wallet/services/analytics_service.dart';

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

  Future<void> openRestore(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          InheritedProvider<WalletProvider>.value(value: _FakeWalletProvider()),
          InheritedProvider<PreferenceProvider>.value(value: _FakePreferenceProvider()),
          Provider<AnalyticsService>.value(value: AnalyticsService(null, true)),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(),
          home: Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => Navigator.of(
                        context,
                      ).push(MaterialPageRoute<void>(builder: (_) => const HotWalletRestoreScreen())),
                  child: const Text('open restore'),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open restore'));
    await tester.pumpAndSettle();
  }

  testWidgets('system Back closes an empty restore form when the keyboard is closed', (tester) async {
    await openRestore(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HotWalletRestoreScreen), findsNothing);
    expect(find.text('open restore'), findsOneWidget);
  });

  testWidgets('repeated system Back closes restore only once', (tester) async {
    await openRestore(tester);
    await tester.binding.handlePopRoute();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HotWalletRestoreScreen), findsNothing);
    expect(find.text('open restore'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system Back with a keyboard keeps the restore form until the next Back', (tester) async {
    await openRestore(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HotWalletRestoreScreen), findsOneWidget);
    expect(
      tester.widgetList<EditableText>(find.byType(EditableText)).any((field) => field.focusNode.hasFocus),
      isFalse,
    );
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HotWalletRestoreScreen), findsNothing);
  });

  testWidgets('system Back preserves entered words until exit is confirmed', (tester) async {
    await openRestore(tester);
    await tester.enterText(find.byType(EditableText).first, 'abandon');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(t.wallet_home_screen.hot_wallet_restore.stop_restore_title), findsOneWidget);
    await tester.tap(find.text(t.no));
    await tester.pumpAndSettle();
    expect(find.byType(HotWalletRestoreScreen), findsOneWidget);
    expect(find.text('abandon'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.yes));
    await tester.pumpAndSettle();
    expect(find.byType(HotWalletRestoreScreen), findsNothing);
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
          Provider<AnalyticsService>.value(value: AnalyticsService(null, true)),
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
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(HotWalletRestoreScreen), findsOneWidget);
    expect(find.text(t.wallet_home_screen.hot_wallet_restore.stop_restore_title), findsNothing);
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
