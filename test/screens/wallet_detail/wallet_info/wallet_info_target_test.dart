import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:coconut_wallet/analytics/analytics_event_names.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/feature/feature_navigation_target.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_info_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/common/single_text_field_bottom_sheet.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Test the installed plugin's actual optimistic cache against platform write failures.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _ControlledStore extends InMemorySharedPreferencesStore {
  _ControlledStore(super.data) : super.withData();

  String? rejectedKey;
  bool throwOnWrite = false;
  bool rejectAfterApplying = false;
  Completer<void>? gate;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    await gate?.future;
    if (key == rejectedKey) {
      if (rejectAfterApplying) {
        await super.setValue(valueType, key, value);
        rejectedKey = null;
      }
      if (throwOnWrite) throw StateError('Storage unavailable');
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}

class _WalletProvider extends ChangeNotifier implements WalletProvider {
  final wallet = SinglesigWalletItem(
    id: 1,
    name: 'Test wallet',
    colorIndex: 0,
    iconIndex: 0,
    descriptor:
        "wpkh([D45AA182/84'/1'/0']vpub5YtEovN9MqeUZxWqdpUKngsiaLCPFY34KpWGQVk9Tjq8G5SYcRFj9s5aCKeAQYGunG7LrFkA5obtH8kPJiv92JtWHfRvnir6PDvhd4p93Pp/<0;1>/*)#rcn2hj6y",
  );

  @override
  List<WalletItemBase> get walletItemList => [wallet];
  @override
  WalletItemBase getWalletById(int id) => wallet;
  @override
  int getWatchedAddressCount(int id) => 0;
  @override
  List<TransactionRecord> getTransactionRecordList(int walletId) => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthProvider extends Fake implements AuthProvider {}

class _NodeProvider extends Fake implements NodeProvider {
  _NodeProvider({this.updates = const Stream.empty()});

  final Stream<WalletUpdateInfo> updates;
  @override
  Stream<WalletUpdateInfo> getWalletStateStream(int id) => updates;
}

class _PreferenceProvider extends Fake implements PreferenceProvider {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.btc;
}

class _UtxoTagProvider extends Fake implements UtxoTagProvider {
  @override
  List<UtxoTag> getUtxoTagList(int id) => [];
}

class _Analytics extends AnalyticsService {
  _Analytics() : super(null, true);

  final events = <(String, Map<String, Object>?)>[];

  @override
  Future<void> logEvent({required String eventName, Map<String, Object>? parameters}) async {
    events.add((eventName, parameters));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _ControlledStore store;
  late SharedPrefsRepository preferences;
  late _WalletProvider walletProvider;

  Future<void> initialize({int? target, bool disabled = false}) async {
    final values = <String, Object>{
      if (target != null) SharedPrefKeys.kWalletTargetSatsMap: jsonEncode({'1': target, '2': 7}),
      SharedPrefKeys.walletTargetDisabled(1): disabled,
    };
    SharedPreferences.setMockInitialValues(values);
    store = _ControlledStore(values.map((key, value) => MapEntry('flutter.$key', value)));
    SharedPreferencesStorePlatform.instance = store;
    preferences = SharedPrefsRepository();
    await preferences.init();
  }

  WalletInfoViewModel viewModel() =>
      WalletInfoViewModel(1, _AuthProvider(), walletProvider, _NodeProvider(), WalletType.singleSignature);

  setUp(() async {
    walletProvider = _WalletProvider();
    LocaleSettings.setLocaleSync(AppLocale.ko);
    await initialize();
  });

  tearDown(() => walletProvider.dispose());

  for (final throwOnWrite in [false, true]) {
    test('target persistence failure restores cached value (throws=$throwOnWrite)', () async {
      await initialize(target: 10);
      store.rejectedKey = 'flutter.${SharedPrefKeys.kWalletTargetSatsMap}';
      store.throwOnWrite = throwOnWrite;
      final model = viewModel();
      addTearDown(model.dispose);

      await expectLater(model.setTargetSats(20), throwsStateError);

      expect(model.targetSats, 10);
      expect(preferences.getWalletTargetSats(2), 7);
    });
  }

  test('a failed enable restores the previous target and disabled state', () async {
    await initialize(target: 10, disabled: true);
    store.rejectedKey = 'flutter.${SharedPrefKeys.walletTargetDisabled(1)}';
    final model = viewModel();
    addTearDown(model.dispose);

    await expectLater(model.setTargetSats(20), throwsStateError);

    expect(model.targetSats, 10);
    expect(model.isTargetDisabled, isTrue);
    expect(preferences.getWalletTargetSats(2), 7);
  });

  test('a failed enable also restores a flag already applied by the platform', () async {
    await initialize(target: 10, disabled: true);
    store.rejectedKey = 'flutter.${SharedPrefKeys.walletTargetDisabled(1)}';
    store.rejectAfterApplying = true;
    final model = viewModel();
    addTearDown(model.dispose);

    await expectLater(model.setTargetSats(20), throwsStateError);
    expect(model.targetSats, 10);
    expect(model.isTargetDisabled, isTrue);
  });

  test('completion after leaving the screen does not notify a disposed view model', () async {
    final model = viewModel();
    store.gate = Completer<void>();
    final saving = model.setTargetSats(20);
    model.dispose();
    store.gate!.complete();

    await saving;
    expect(preferences.getWalletTargetSats(1), 20);
  });

  test('wallet updates do not leave subscriptions after the screen is disposed', () async {
    final updates = StreamController<WalletUpdateInfo>.broadcast();
    final model = WalletInfoViewModel(
      1,
      _AuthProvider(),
      walletProvider,
      _NodeProvider(updates: updates.stream),
      WalletType.singleSignature,
    );
    walletProvider.notifyListeners();
    walletProvider.notifyListeners();
    model.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(updates.hasListener, isFalse);
    await updates.close();
  });

  test('simultaneous target saves preserve the first accepted request', () async {
    final model = viewModel();
    addTearDown(model.dispose);
    store.gate = Completer<void>();
    final saving = model.setTargetSats(20);

    expect(await model.setTargetSats(30), isFalse);
    await model.removeTargetSats();
    store.gate!.complete();
    expect(await saving, isTrue);
    expect(model.targetSats, 20);
  });

  test('a failed disable restores a removed target', () async {
    await initialize(target: 10);
    store.rejectedKey = 'flutter.${SharedPrefKeys.walletTargetDisabled(1)}';
    final model = viewModel();
    addTearDown(model.dispose);

    await expectLater(model.removeTargetSats(), throwsStateError);
    expect(model.targetSats, 10);
    expect(model.isTargetDisabled, isFalse);
    expect(preferences.getWalletTargetSats(2), 7);
  });

  test('a non-positive target is rejected without changing storage', () async {
    final model = viewModel();
    addTearDown(model.dispose);

    await expectLater(model.setTargetSats(0), throwsArgumentError);
    await expectLater(model.setTargetSats(-1), throwsArgumentError);
    expect(model.targetSats, isNull);
  });

  const captureKey = ValueKey('wallet-info-capture');

  Future<_Analytics> openTargetSheet(
    WidgetTester tester, {
    WalletInfoTarget? focus,
    Size viewport = const Size(430, 932),
    double bottomInset = 0,
    double textScale = 1,
  }) async {
    final analytics = _Analytics();
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          InheritedProvider<AuthProvider>.value(value: _AuthProvider()),
          InheritedProvider<WalletProvider>.value(value: walletProvider),
          InheritedProvider<NodeProvider>.value(value: _NodeProvider()),
          InheritedProvider<PreferenceProvider>.value(value: _PreferenceProvider()),
          InheritedProvider<UtxoTagProvider>.value(value: _UtxoTagProvider()),
          Provider<AnalyticsService>.value(value: analytics),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(),
          scrollBehavior: const CupertinoScrollBehavior(),
          builder:
              (context, child) => RepaintBoundary(
                key: captureKey,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    padding: EdgeInsets.only(bottom: bottomInset),
                    viewPadding: EdgeInsets.only(bottom: bottomInset),
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: child!,
                ),
              ),
          home: LoaderOverlay(
            child: WalletInfoScreen(
              id: 1,
              walletType: WalletType.singleSignature,
              showTargetSetting: focus == null,
              initialTarget: focus,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.byType(SingleTextFieldBottomSheet), focus == null ? findsOneWidget : findsNothing);
    return analytics;
  }

  for (final viewport in [const Size(360, 640), const Size(430, 932)]) {
    for (final bottomInset in [0.0, 24.0, 34.0]) {
      testWidgets('wallet info last row remains above bottom inset $bottomInset in $viewport', (tester) async {
        final analytics = await openTargetSheet(
          tester,
          focus: WalletInfoTarget.appearance,
          viewport: viewport,
          bottomInset: bottomInset,
          textScale: 1.3,
        );
        final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
        for (var attempt = 0; attempt < 12; attempt++) {
          await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
          await tester.pumpAndSettle();
          if ((scrollable.position.pixels - scrollable.position.maxScrollExtent).abs() < 0.1) break;
        }
        expect(scrollable.position.pixels, closeTo(scrollable.position.maxScrollExtent, 0.1));
        final lastRow = tester.getRect(
          find.ancestor(
            of: find.text(t.wallet_info_screen.delete_wallet),
            matching: find.byType(ShrinkAnimationButton),
          ),
        );
        expect(lastRow.top, greaterThanOrEqualTo(0));
        expect(lastRow.height, greaterThan(0));
        expect(lastRow.bottom, lessThanOrEqualTo(viewport.height - bottomInset));
        expect(find.byType(AlertDialog), findsNothing);
        expect(analytics.events, isEmpty);
        expect(walletProvider.walletItemList, hasLength(1));
      });
    }
  }

  for (final focus in [WalletInfoTarget.extendedPublicKey, WalletInfoTarget.delete]) {
    testWidgets('search reveals $focus without invoking its sensitive action', (tester) async {
      final analytics = await openTargetSheet(tester, focus: focus);
      final target = find.byKey(ValueKey('wallet-info-focus-${focus.name}'));
      expect(target, findsOneWidget);
      final rect = tester.getRect(target);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(932));
      expect(find.byType(AlertDialog), findsNothing);
      expect(analytics.events, isEmpty);
      expect(walletProvider.walletItemList, hasLength(1));
    });
  }

  testWidgets('rename search highlight stays inside the rounded edit button', (tester) async {
    await openTargetSheet(tester, focus: WalletInfoTarget.appearance);
    Future<ByteData> pixels() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(captureKey));
      return (await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        } finally {
          image.dispose();
        }
      }))!;
    }

    final target = find.byKey(const ValueKey('wallet-info-focus-appearance'));
    final opacity = find.descendant(of: target, matching: find.byType(AnimatedOpacity));
    expect(tester.widget<AnimatedOpacity>(opacity).opacity, 1);
    final button = find.byKey(const Key('wallet-info-appearance-edit'));
    final cardShape = BorderRadius.circular(20).toRRect(tester.getRect(button));
    final targetRect = tester.getRect(target);
    final highlighted = await pixels();

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.widget<AnimatedOpacity>(opacity).opacity, 0);
    expect(tester.getRect(target), targetRect);
    final normal = await pixels();
    final width = tester.view.physicalSize.width.toInt();
    var outsideSamples = 0;
    var changedOutside = 0;
    var changedInside = 0;
    for (var y = targetRect.top.ceil(); y < targetRect.bottom.floor(); y++) {
      for (var x = targetRect.left.ceil(); x < targetRect.right.floor(); x++) {
        final point = Offset(x + 0.5, y + 0.5);
        final changed = highlighted.getUint32((y * width + x) * 4) != normal.getUint32((y * width + x) * 4);
        // Exclude the button's antialiased edge, not the highlight's own shape.
        if (!cardShape.inflate(1).contains(point)) {
          outsideSamples++;
          if (changed) changedOutside++;
        } else if (cardShape.deflate(2).contains(point) && changed) {
          changedInside++;
        }
      }
    }
    expect(outsideSamples, greaterThan(20));
    expect(changedOutside, 0, reason: 'Highlight must not paint outside the rounded button corners.');
    expect(changedInside, greaterThan(100), reason: 'The button must actually be highlighted.');
  });

  testWidgets('saved event follows persistence and contains no amount', (tester) async {
    final analytics = await openTargetSheet(tester);
    store.gate = Completer<void>();
    final sheet = tester.widget<SingleTextFieldBottomSheet>(find.byType(SingleTextFieldBottomSheet));
    sheet.onComplete('1');
    await tester.pump();
    expect(analytics.events, isEmpty);

    store.gate!.complete();
    await tester.pumpAndSettle();
    expect(analytics.events, [(AnalyticsEventNames.targetAmountSaved, null)]);
    expect(preferences.getWalletTargetSats(1), 100000000);
  });

  testWidgets('storage failure reports failure and never reports success', (tester) async {
    final analytics = await openTargetSheet(tester);
    store.rejectedKey = 'flutter.${SharedPrefKeys.kWalletTargetSatsMap}';
    final sheet = tester.widget<SingleTextFieldBottomSheet>(find.byType(SingleTextFieldBottomSheet));
    sheet.onComplete('1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(analytics.events, isEmpty);
    expect(preferences.getWalletTargetSats(1), isNull);
    expect(find.text(t.errors.storage_write_error), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('invalid input and disabling are not saved events', (tester) async {
    final analytics = await openTargetSheet(tester);
    final sheet = tester.widget<SingleTextFieldBottomSheet>(find.byType(SingleTextFieldBottomSheet));
    sheet.onComplete('0');
    await tester.pump();
    sheet.onComplete('');
    await tester.pump();

    expect(analytics.events, isEmpty);
    expect(preferences.getWalletTargetSats(1), isNull);
    expect(preferences.isWalletTargetDisabled(1), isTrue);
    await tester.pump(const Duration(seconds: 4));
  });
}
