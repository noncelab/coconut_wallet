import 'dart:async';
import 'dart:typed_data';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/core/exceptions/wallet_name_conflict_exception.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_add/hot_wallet_create_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:coconut_wallet/screens/home/wallet_add/hot_wallet/hot_wallet_create_screen.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
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

class _NoopSecretRepository extends Fake implements HotWalletSecretRepository {}

class _ControlledCreateViewModel extends HotWalletCreateViewModel {
  _ControlledCreateViewModel({this.result, this.error})
    : super(_FakeWalletProvider(), secretRepository: _NoopSecretRepository());

  HotWalletCreateResult? result;
  Object? error;
  Completer<HotWalletCreateResult>? gate;
  int createCallCount = 0;
  bool committed = false;
  bool _creating = false;

  @override
  bool get isCreating => _creating;

  void setCreating(bool value) {
    _creating = value;
    notifyListeners();
  }

  @override
  Future<HotWalletCreateResult> createWallet({
    required String walletName,
    required int colorIndex,
    required int iconIndex,
    required int mnemonicWordCount,
    required String passphrase,
    required bool enterPassphraseWhenSigning,
  }) async {
    if (_creating) throw StateError('already creating');
    createCallCount++;
    setCreating(true);
    try {
      if (gate != null) return await gate!.future;
      if (error != null) throw error!;
      committed = true;
      return result!;
    } finally {
      setCreating(false);
    }
  }
}

HotWalletCreateResult _result({bool enterPassphraseWhenSigning = false}) => HotWalletCreateResult(
  walletId: 77,
  walletName: '테스트 핫월렛',
  descriptor: 'wpkh([12345678/84h/1h/0h]tpub-test/<0;1>/*)',
  mnemonic: Uint8List.fromList('abandon about'.codeUnits),
  passphrase: Uint8List.fromList('secret'.codeUnits),
  enterPassphraseWhenSigning: enterPassphraseWhenSigning,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.ko);
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    _ControlledCreateViewModel viewModel, {
    RouteFactory? onGenerateRoute,
  }) async {
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
        child: MaterialApp(
          theme: buildCoconutThemeData(),
          onGenerateRoute:
              onGenerateRoute ??
              (settings) {
                if (settings.name == '/hot-wallet-mnemonic-backup-guide') {
                  return MaterialPageRoute<void>(settings: settings, builder: (_) => const SizedBox());
                }
                return null;
              },
          home: HotWalletCreateScreen(viewModel: viewModel),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  FixedBottomButton createButton(WidgetTester tester) =>
      tester.widget<FixedBottomButton>(find.byKey(const ValueKey('hot-wallet-create-button')));

  Future<void> enablePassphrase(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('hot-wallet-advanced-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hot-wallet-use-passphrase')));
    await tester.pumpAndSettle();
  }

  testWidgets('passphrase와 확인 값이 모두 일치할 때만 생성 버튼이 활성화된다', (tester) async {
    final viewModel = _ControlledCreateViewModel(result: _result());
    await pumpScreen(tester, viewModel);
    await enablePassphrase(tester);

    expect(createButton(tester).isActive, isFalse);
    final passphraseField = find.descendant(
      of: find.byKey(const ValueKey('hot-wallet-passphrase')),
      matching: find.byType(EditableText),
    );
    final confirmationField = find.descendant(
      of: find.byKey(const ValueKey('hot-wallet-passphrase-confirm')),
      matching: find.byType(EditableText),
    );
    await tester.enterText(passphraseField, 'secret');
    await tester.pump();
    expect(createButton(tester).isActive, isFalse);
    await tester.enterText(confirmationField, 'different');
    await tester.pump();
    expect(createButton(tester).isActive, isFalse);
    await tester.enterText(confirmationField, 'secret');
    await tester.pump();
    expect(createButton(tester).isActive, isTrue);
  });

  testWidgets('빠른 중복 탭에도 생성 요청은 한 번만 실행된다', (tester) async {
    final viewModel = _ControlledCreateViewModel(result: _result())..gate = Completer<HotWalletCreateResult>();
    await pumpScreen(tester, viewModel);

    await tester.tap(find.byKey(const ValueKey('hot-wallet-create-button-target')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('hot-wallet-create-button-target')), warnIfMissed: false);
    await tester.pump();

    expect(viewModel.createCallCount, 1);
    viewModel.gate!.complete(_result());
    await tester.pump();
  });

  testWidgets('생성 중에는 시스템 Back을 차단한다', (tester) async {
    final viewModel = _ControlledCreateViewModel(result: _result())..setCreating(true);
    await pumpScreen(tester, viewModel);

    expect(tester.widget<PopScope<dynamic>>(find.byType(PopScope)).canPop, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(HotWalletCreateScreen), findsOneWidget);
  });

  testWidgets('중복 이름 오류 다이얼로그를 표시한다', (tester) async {
    final viewModel = _ControlledCreateViewModel(error: const WalletNameConflictException());
    await pumpScreen(tester, viewModel);

    await tester.tap(find.byKey(const ValueKey('hot-wallet-create-button-target')));
    await tester.pumpAndSettle();

    expect(find.text(t.wallet_home_screen.hot_wallet_create.duplicate_name_title), findsOneWidget);
    expect(find.text(t.wallet_home_screen.hot_wallet_create.duplicate_name_description), findsOneWidget);
  });

  testWidgets('일반 생성 실패 다이얼로그를 표시한다', (tester) async {
    final viewModel = _ControlledCreateViewModel(error: StateError('creation failed'));
    await pumpScreen(tester, viewModel);

    await tester.tap(find.byKey(const ValueKey('hot-wallet-create-button-target')));
    await tester.pumpAndSettle();

    expect(find.text(t.alert.error_occurs), findsOneWidget);
    expect(find.text(t.wallet_home_screen.hot_wallet_create.creation_failed), findsOneWidget);
  });

  testWidgets('백업 화면에 wallet ID, descriptor, 니모닉, passphrase를 전달한다', (tester) async {
    Object? routeArguments;
    final result = _result();
    final viewModel = _ControlledCreateViewModel(result: result);
    await pumpScreen(
      tester,
      viewModel,
      onGenerateRoute: (settings) {
        if (settings.name == '/hot-wallet-mnemonic-backup-guide') {
          routeArguments = settings.arguments;
          return MaterialPageRoute<void>(settings: settings, builder: (_) => const SizedBox());
        }
        return null;
      },
    );

    await tester.tap(find.byKey(const ValueKey('hot-wallet-create-button-target')));
    await tester.pumpAndSettle();

    final arguments = routeArguments! as Map<String, dynamic>;
    expect(arguments['walletId'], 77);
    expect(arguments['descriptor'], result.descriptor);
    expect(arguments['mnemonic'], result.mnemonic);
    expect(arguments['passphrase'], result.passphrase);
    expect(arguments['enterPassphraseWhenSigning'], isFalse);
  });

  testWidgets('백업 화면 navigation 실패가 성공한 생성 요청을 다시 실행하지 않는다', (tester) async {
    final viewModel = _ControlledCreateViewModel(result: _result());
    await pumpScreen(
      tester,
      viewModel,
      onGenerateRoute: (settings) {
        if (settings.name == '/hot-wallet-mnemonic-backup-guide') {
          throw StateError('navigation failed');
        }
        return null;
      },
    );

    await tester.tap(find.byKey(const ValueKey('hot-wallet-create-button-target')));
    await tester.pumpAndSettle();

    expect(viewModel.createCallCount, 1);
    expect(viewModel.committed, isTrue);
    expect(find.byType(HotWalletCreateScreen), findsOneWidget);
    expect(find.text(t.wallet_home_screen.hot_wallet_create.creation_failed), findsOneWidget);
  });

  testWidgets('서명 시 입력 옵션은 저장하지 않는다는 안내 후 선택된다', (tester) async {
    final viewModel = _ControlledCreateViewModel(result: _result(enterPassphraseWhenSigning: true));
    await pumpScreen(tester, viewModel);
    await enablePassphrase(tester);

    await tester.ensureVisible(find.byKey(const ValueKey('hot-wallet-enter-passphrase-when-signing')));
    await tester.tap(find.byKey(const ValueKey('hot-wallet-enter-passphrase-when-signing')));
    await tester.pumpAndSettle();

    expect(find.text(t.wallet_home_screen.hot_wallet_create.passphrase_not_stored_title), findsOneWidget);
    expect(find.text(t.wallet_home_screen.hot_wallet_create.passphrase_not_stored_description), findsOneWidget);
    expect(find.text(t.wallet_home_screen.hot_wallet_create.passphrase_not_stored_confirm), findsOneWidget);
    await tester.tap(find.text(t.wallet_home_screen.hot_wallet_create.passphrase_not_stored_confirm));
    await tester.pumpAndSettle();

    expect(find.text(t.wallet_home_screen.hot_wallet_create.passphrase_not_stored_title), findsNothing);
    expect(tester.widget<CoconutCheckbox>(find.byType(CoconutCheckbox)).isSelected, isTrue);
  });
}
