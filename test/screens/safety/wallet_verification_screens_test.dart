import 'dart:async';
import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/rescue_ready_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/safety/bsms_verification_screen.dart';
import 'package:coconut_wallet/screens/safety/watch_only_verification_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart';
import 'package:coconut_wallet/services/safety/wallet_verification.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:coconut_wallet/widgets/features/qr/qr_scanner_view.dart';
import 'package:coconut_wallet/widgets/features/wallet/icon/wallet_icon_small.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ur/cbor_lite.dart';
import 'package:ur/fountain_encoder.dart';
import 'package:ur/fountain_utils.dart';
import 'package:ur/ur.dart';
import 'package:ur/ur_encoder.dart';

/// 글자 찾기. 앱은 한국어 단어가 중간에서 끊기지 않게 글자 사이에 U+2060을 넣으므로(safetyKoText) 그 문자를 빼고 비교한다
Finder _text(String text) =>
    find.byWidgetPredicate((w) => w is Text && (w.data ?? w.textSpan?.toPlainText())?.replaceAll('\u2060', '') == text);

class _Wallets extends ChangeNotifier implements WalletProvider {
  _Wallets(this.walletItemList);
  @override
  final List<WalletItemBase> walletItemList;
  @override
  WalletItemBase getWalletById(int id) => walletItemList.firstWhere((wallet) => wallet.id == id);
  @override
  int getWatchedAddressCount(int id) => 0;
  void removeAll() {
    walletItemList.clear();
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends Fake implements AuthProvider {}

class _Node extends Fake implements NodeProvider {
  @override
  Stream<WalletUpdateInfo> getWalletStateStream(int id) => const Stream.empty();
}

class _Preferences extends Fake implements PreferenceProvider {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.btc;
}

class _Tags extends Fake implements UtxoTagProvider {
  @override
  List<UtxoTag> getUtxoTagList(int id) => [];
}

class _Rescue extends ChangeNotifier implements RescueReadyProvider {
  String? label;
  @override
  String? destinationLabel(int walletId) => label;
  @override
  RescueDestination? destinationOf(int walletId) =>
      label == null ? null : RescueDestination(walletId: 2, setAt: DateTime(2026));
  void rename(String? value) {
    label = value;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Safety extends SafetyProvider {
  _Safety() : super.fixed(null);
  final watch = <({int id, VerificationMethod method, VerificationResult result, int? index})>[];
  final bsms = <({int id, bool matched, String hash})>[];
  bool failSave = false;
  Completer<void>? saveGate;

  @override
  Future<void> recordWatchOnlyVerification(
    int walletId, {
    required VerificationMethod method,
    required VerificationResult result,
    int? matchedIndex,
  }) async {
    if (failSave) throw StateError('Save failed');
    await saveGate?.future;
    watch.add((id: walletId, method: method, result: result, index: matchedIndex));
  }

  @override
  Future<void> recordBsmsVerification(int walletId, {required bool matched, required String configHash}) async {
    if (failSave) throw StateError('Save failed');
    bsms.add((id: walletId, matched: matched, hash: configHash));
  }
}

class _Camera extends MobileScannerPlatform {
  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const SizedBox.expand();
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async => const MobileScannerViewAttributes(
    cameraDirection: CameraFacing.back,
    currentTorchMode: TorchState.off,
    numberOfCameras: 1,
    initialDeviceOrientation: DeviceOrientation.portraitUp,
    size: Size(640, 480),
  );
  @override
  Future<void> stop() async {}
  @override
  Future<void> updateScanWindow(Rect? window) async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  late SinglesigWalletItem single;
  late MultisigWalletItem multi;
  late _Wallets wallets;
  late _Safety safety;
  late NetworkType previousNetwork;

  setUpAll(() {
    previousNetwork = NetworkType.currentNetworkType;
    NetworkType.setNetworkType(NetworkType.regtest);
    final seeds = List.generate(3, (i) => Seed.fromEntropy(Uint8List.fromList(List.filled(16, i + 1))));
    single = SinglesigWalletItem(
      id: 1,
      name: 'Watch wallet',
      colorIndex: 0,
      iconIndex: 0,
      descriptor: SingleSignatureVault.fromSeed(seeds.first).descriptor,
    );
    multi = MultisigWalletItem(
      id: 2,
      name: 'Multisig wallet',
      colorIndex: 0,
      iconIndex: 0,
      descriptor:
          Descriptor.parse(
            MultisignatureVault.fromSeedList(seeds, 2).descriptor.replaceAll("'", 'h'),
            ignoreChecksum: true,
          ).serialize(),
      signers: [],
      requiredSignatureCount: 2,
    );
    multi.signers = [
      for (final (index, signer) in multi.signerBsmsList.indexed)
        MultisigSigner(name: 'Signer ${index + 1}', colorIndex: index, iconIndex: index)
          ..signerBsms = signer.getSignerBsms(),
    ];
  });
  tearDownAll(() => NetworkType.setNetworkType(previousNetwork));

  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    wallets = _Wallets([single, multi]);
    safety = _Safety();
    final previousCamera = MobileScannerPlatform.instance;
    MobileScannerPlatform.instance = _Camera();
    addTearDown(() => MobileScannerPlatform.instance = previousCamera);
    addTearDown(wallets.dispose);
    addTearDown(safety.dispose);
  });

  Future<void> mount(
    WidgetTester tester,
    CoconutThemeVariant theme,
    Widget screen, {
    bool provider = true,
    Size viewport = const Size(320, 844),
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WalletProvider>.value(value: wallets),
          if (provider) ChangeNotifierProvider<SafetyProvider>.value(value: safety),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: theme),
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: true, textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
          home: LoaderOverlay(child: screen),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> startScan(WidgetTester tester, String text) async {
    await tester.tap(_text(text));
    await tester.pumpAndSettle();
    expect(find.byType(QrScannerView), findsOneWidget);
  }

  Future<void> capture(WidgetTester tester, String payload) async {
    tester
        .widget<QrScannerView>(find.byType(QrScannerView))
        .onDetect(BarcodeCapture(barcodes: [Barcode(rawValue: payload)]));
    await tester.pumpAndSettle();
  }

  for (final locale in [AppLocale.ko, AppLocale.en]) {
    for (final theme in CoconutThemeVariant.values) {
      group('${locale.name} ${theme.name} at 320 dp', () {
        setUp(() => LocaleSettings.setLocaleSync(locale));
        testWidgets('watch-only shows the comparison heading and description', (tester) async {
          final copy = t.wallet_health.watch_only_verify;
          await mount(tester, theme, const WatchOnlyVerificationScreen(walletId: 1));
          expect(_text(copy.heading), findsOneWidget);
          expect(_text(copy.description), findsOneWidget);
          expect(find.byType(SafetyStatusBanner), findsNothing);
          expect(safety.watch, isEmpty);
          // C31: 4글자씩 묶어 보이지만 고를 수 있는 글(복사 내용)은 원래 주소 그대로
          final address = tester.widget<SelectableText>(find.byType(SelectableText)).textSpan!;
          expect(address.toPlainText(), single.walletBase.getAddress(0));
          expect(address.children!.length, greaterThan(2));
          expect(tester.takeException(), isNull);
        });

        testWidgets('missing fingerprint shows a neutral guide until a result replaces it', (tester) async {
          final copy = t.wallet_health.watch_only_verify;
          wallets.walletItemList.add(
            SinglesigWalletItem(
              id: 3,
              name: 'Wallet without fingerprint',
              colorIndex: 0,
              iconIndex: 0,
              descriptor:
                  Descriptor.parse(
                    single.descriptor
                        .split('#')
                        .first
                        .replaceFirst(
                          RegExp(r'\[[A-Fa-f0-9]{8}/'),
                          '[${WalletAddService.masterFingerprintPlaceholder}/',
                        ),
                    ignoreChecksum: true,
                  ).serialize(),
            ),
          );
          await mount(tester, theme, const WatchOnlyVerificationScreen(walletId: 3));
          expect(_text(copy.no_mfp_title), findsOneWidget);
          expect(_text(copy.no_mfp), findsOneWidget);
          await tester.ensureVisible(find.byType(SafetyStatusBanner));
          await tester.pumpAndSettle();
          final banner = tester.widget<SafetyStatusBanner>(find.byType(SafetyStatusBanner));
          final colors = resolveCoconutThemeExtension(variant: theme).colors;
          expect(banner.background, colors.surface);
          expect(banner.iconPath, CommonStateIconPath.circleInfo);
          expect(banner.iconColor, colors.iconSecondary);
          expect(safety.watch, isEmpty);
          await tester.tap(_text(copy.compared_manually));
          await tester.pumpAndSettle();
          await tester.tap(_text(copy.confirm_match));
          await tester.pumpAndSettle();
          expect(safety.watch.single.id, 3);
          expect(safety.watch.single.method, VerificationMethod.user);
          expect(safety.watch.single.result, VerificationResult.match);
          expect(_text(copy.no_mfp_title), findsNothing);
          expect(_text(copy.user_confirmed_title), findsOneWidget);
          expect(find.byType(SafetyStatusBanner), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('watch-only QR match records receive index 19 and success tokens', (tester) async {
          await mount(tester, theme, const WatchOnlyVerificationScreen(walletId: 1));
          await startScan(tester, t.wallet_health.watch_only_verify.scan);
          await capture(tester, single.walletBase.getAddress(19));
          expect(safety.watch.single.result, VerificationResult.match);
          expect(safety.watch.single.method, VerificationMethod.qr);
          expect(safety.watch.single.index, 19);
          expect(_text(t.wallet_health.watch_only_verify.match_at_index(index: 19)), findsOneWidget);
          final banner = tester.widget<SafetyStatusBanner>(find.byType(SafetyStatusBanner));
          expect(banner.background, resolveCoconutThemeExtension(variant: theme).colors.successSurface);
          expect(tester.takeException(), isNull);
        });

        testWidgets('mismatch retries and requires explicit confirmation before critical', (tester) async {
          final copy = t.wallet_health.watch_only_verify;
          await mount(tester, theme, const WatchOnlyVerificationScreen(walletId: 1));
          await startScan(tester, copy.scan);
          await capture(tester, single.walletBase.getAddress(20));
          expect(safety.watch.single.result, VerificationResult.mismatch);
          expect(
            tester.widget<SafetyStatusBanner>(find.byType(SafetyStatusBanner)).background,
            resolveCoconutThemeExtension(variant: theme).colors.warningSurface,
          );
          await startScan(tester, copy.scan_again);
          await capture(tester, single.walletBase.getAddress(0, isChange: true));
          expect(safety.watch.length, 2);
          await tester.tap(_text(copy.confirm_device));
          await tester.pumpAndSettle();
          await tester.tap(_text(t.cancel));
          await tester.pumpAndSettle();
          expect(safety.watch.length, 2);
          await tester.tap(_text(copy.confirm_device));
          await tester.pumpAndSettle();
          await tester.tap(_text(copy.confirm_device_yes));
          await tester.pumpAndSettle();
          expect(safety.watch.last.result, VerificationResult.confirmedMismatch);
          expect(safety.watch.last.index, isNull);
          expect(
            tester.widget<SafetyStatusBanner>(find.byType(SafetyStatusBanner)).background,
            resolveCoconutThemeExtension(variant: theme).colors.dangerSurface,
          );
          expect(tester.takeException(), isNull);
        });

        testWidgets('manual comparison is confirmed and uses neutral result tokens', (tester) async {
          final copy = t.wallet_health.watch_only_verify;
          await mount(tester, theme, const WatchOnlyVerificationScreen(walletId: 1));
          await tester.tap(_text(copy.compared_manually));
          await tester.pumpAndSettle();
          expect(safety.watch, isEmpty);
          await tester.tap(_text(copy.confirm_match));
          await tester.pumpAndSettle();
          expect(safety.watch.single.method, VerificationMethod.user);
          expect(safety.watch.single.result, VerificationResult.match);
          final banner = tester.widget<SafetyStatusBanner>(find.byType(SafetyStatusBanner));
          expect(banner.background, resolveCoconutThemeExtension(variant: theme).colors.surface);
          expect(_text(copy.user_confirmed_title), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('invalid QR and cancelled scan do not record a mismatch', (tester) async {
          final copy = t.wallet_health.watch_only_verify;
          await mount(tester, theme, const WatchOnlyVerificationScreen(walletId: 1));
          await startScan(tester, copy.scan);
          await capture(tester, 'invalid QR');
          expect(safety.watch, isEmpty);
          expect(_text(copy.error_not_address), findsOneWidget);
          await startScan(tester, copy.scan);
          Navigator.pop(tester.element(find.byType(QrScannerView)));
          await tester.pumpAndSettle();
          expect(safety.watch, isEmpty);
        });

        testWidgets('mixed-case Bech32 is malformed and never records a mismatch', (tester) async {
          final copy = t.wallet_health.watch_only_verify;
          await mount(tester, theme, const WatchOnlyVerificationScreen(walletId: 1));
          await startScan(tester, copy.scan);
          final address = single.walletBase.getAddress(0);
          await capture(tester, ' BITCOIN:B${address.substring(1)}?amount=1 ');
          expect(safety.watch, isEmpty);
          expect(_text(copy.error_not_address), findsOneWidget);
          expect(find.byType(SafetyStatusBanner), findsNothing);
        });

        testWidgets('watch-only storage failure does not claim success', (tester) async {
          safety.failSave = true;
          await mount(tester, theme, const WatchOnlyVerificationScreen(walletId: 1));
          await startScan(tester, t.wallet_health.watch_only_verify.scan);
          await capture(tester, single.walletBase.getAddress(0));
          expect(_text(t.wallet_health.save_failed), findsOneWidget);
          expect(find.byType(SafetyStatusBanner), findsNothing);
          expect(safety.watch, isEmpty);
        });

        testWidgets('BSMS single UR export verifies all fields and stores current config hash', (tester) async {
          await mount(tester, theme, const BsmsVerificationScreen(walletId: 2));
          await startScan(tester, t.wallet_health.bsms_verify.scan);
          final encoder = CBOREncoder()..encodeBytes(Uint8List.fromList(utf8.encode('BSMS 1.0\n${multi.descriptor}')));
          await capture(tester, UREncoder(UR('bytes', encoder.getBytes()), 2000).nextPart());
          expect(safety.bsms.single.matched, isTrue);
          expect(safety.bsms.single.hash == WalletVerification.descriptorHash(multi.descriptor), isTrue);
          expect(_text(t.wallet_health.bsms_verify.verified_title), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('BSMS header shows the shared wallet icon with the signer gradient (C10)', (tester) async {
          await mount(tester, theme, const BsmsVerificationScreen(walletId: 2));
          // C11: 짧은 제목 + 설명(설명 전체가 큰 제목이 아니다)
          expect(_text(t.wallet_health.bsms_verify.heading), findsOneWidget);
          expect(tester.widget<Text>(_text(t.wallet_health.bsms_verify.description)).style!.fontSize, 14);
          expect(tester.widget<WalletIconSmall>(find.byType(WalletIconSmall).first).gradientColors, isNotNull);
        });

        testWidgets('BSMS mismatch can be retried and corrected', (tester) async {
          final copy = t.wallet_health.bsms_verify;
          await mount(tester, theme, const BsmsVerificationScreen(walletId: 2));
          await startScan(tester, copy.scan);
          await capture(
            tester,
            'BSMS 1.0\n${multi.descriptor.split('#').first.replaceFirst('sortedmulti(2,', 'sortedmulti(1,')}',
          );
          expect(safety.bsms.single.matched, isFalse);
          expect(_text(copy.mismatch_title), findsOneWidget);
          await startScan(tester, copy.scan);
          await capture(tester, 'BSMS 1.0\n${multi.descriptor}');
          expect(safety.bsms.length, 2);
          expect(safety.bsms.last.matched, isTrue);
          expect(_text(copy.verified_title), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('BSMS malformed backup and save failure do not claim verification', (tester) async {
          final copy = t.wallet_health.bsms_verify;
          await mount(tester, theme, const BsmsVerificationScreen(walletId: 2));
          await startScan(tester, copy.scan);
          await capture(tester, 'invalid backup');
          expect(safety.bsms, isEmpty);
          expect(_text(copy.error_parse), findsOneWidget);
          safety.failSave = true;
          await startScan(tester, copy.scan);
          await capture(tester, 'BSMS 1.0\n${multi.descriptor}');
          expect(safety.bsms, isEmpty);
          expect(_text(t.wallet_health.save_failed), findsOneWidget);
          expect(find.byType(SafetyStatusBanner), findsNothing);
        });

        testWidgets('both screens render nothing without SafetyProvider', (tester) async {
          await mount(tester, theme, const WatchOnlyVerificationScreen(walletId: 1), provider: false);
          expect(find.byKey(const Key('watch-only-verification-screen')), findsNothing);
          await mount(tester, theme, const BsmsVerificationScreen(walletId: 2), provider: false);
          expect(find.byKey(const Key('bsms-verification-screen')), findsNothing);
          expect(tester.takeException(), isNull);
        });

        testWidgets('wallet removal while scanning cannot record a result', (tester) async {
          await mount(tester, theme, const WatchOnlyVerificationScreen(walletId: 1));
          await startScan(tester, t.wallet_health.watch_only_verify.scan);
          wallets.removeAll();
          await capture(tester, single.walletBase.getAddress(0));
          expect(safety.watch, isEmpty);
          expect(tester.takeException(), isNull);
        });
      });
    }
  }

  for (final header in [
    (name: 'excessive sequence count', count: 1025, length: 1025),
    (name: 'excessive declared message length', count: 2, length: 65546),
    (name: 'inconsistent fragment allocation', count: 2, length: 100),
  ]) {
    testWidgets('BSMS rejects a tiny UR frame with ${header.name} before assembly', (tester) async {
      await mount(tester, CoconutThemeVariant.light, const BsmsVerificationScreen(walletId: 2));
      await startScan(tester, t.wallet_health.bsms_verify.scan);
      final part = FountainEncoderPart(1, header.count, header.length, 0, Uint8List.fromList([0]));
      await capture(tester, UREncoder.encodePart('bytes', part));
      expect(safety.bsms, isEmpty);
      expect(_text(t.wallet_health.bsms_verify.error_parse), findsOneWidget);
      expect(find.byType(QrScannerView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('X1: the watch-only footer fade starts above its link line and grows with the text (R4)', (tester) async {
    await mount(tester, CoconutThemeVariant.light, const WatchOnlyVerificationScreen(walletId: 1));
    final footer = find.byType(FixedBottomButton);
    final button = tester.widget<FixedBottomButton>(footer);
    expect(button.subWidget, isNotNull);
    final clearance = safetyFooterClearance(tester.element(footer), hasSubWidget: true);
    expect(clearance, greaterThan(184)); // 1.3배
    expect(button.surroundingsPadding, EdgeInsets.fromLTRB(16, clearance, 16, 40));
  });

  testWidgets('BSMS bounds accumulated unique UR bytes and resets for a valid backup', (tester) async {
    await mount(tester, CoconutThemeVariant.light, const BsmsVerificationScreen(walletId: 2));
    await startScan(tester, t.wallet_health.bsms_verify.scan);
    final data = Uint8List(30000);
    var sent = 0;
    for (var sequence = 3; sent < 9; sequence++) {
      if (chooseFragments(sequence, 2, 0).length != 2) continue;
      final part = FountainEncoderPart(sequence, 2, 60000, 0, data);
      final frame = UREncoder.encodePart('bytes', part);
      await capture(tester, frame);
      sent++;
      if (sent == 1) {
        for (var repeat = 0; repeat < 10; repeat++) {
          await capture(tester, frame);
        }
        expect(_text(t.wallet_health.bsms_verify.error_parse), findsNothing);
      }
    }
    expect(safety.bsms, isEmpty);
    expect(_text(t.wallet_health.bsms_verify.error_parse), findsOneWidget);
    // C21: 실패는 팝업으로 알리고(그동안 들어온 프레임은 버린다), 닫으면 조립을 처음부터 다시 한다
    final popup = find.byKey(const Key('bsms-verification-scan-error'));
    expect(popup, findsOneWidget);
    await capture(tester, 'BSMS 1.0\n${multi.descriptor}');
    expect(safety.bsms, isEmpty);
    await tester.tap(find.descendant(of: popup, matching: _text(t.OK)));
    await tester.pumpAndSettle();
    expect(popup, findsNothing);
    await capture(tester, 'BSMS 1.0\n${multi.descriptor}');
    expect(safety.bsms.single.matched, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final type in [WalletType.singleSignature, WalletType.multiSignature]) {
    for (final provider in [false, true]) {
      testWidgets('wallet info ${type.name} verification menu requires SafetyProvider=$provider', (tester) async {
        SharedPreferences.setMockInitialValues({});
        await SharedPrefsRepository().init();
        await mount(
          tester,
          CoconutThemeVariant.light,
          MultiProvider(
            providers: [
              InheritedProvider<AuthProvider>.value(value: _Auth()),
              InheritedProvider<NodeProvider>.value(value: _Node()),
              InheritedProvider<PreferenceProvider>.value(value: _Preferences()),
              InheritedProvider<UtxoTagProvider>.value(value: _Tags()),
            ],
            child: WalletInfoScreen(
              id: type == WalletType.singleSignature ? 1 : 2,
              walletType: type,
              entryPoint: '/wallet-home',
            ),
          ),
          provider: provider,
          // 기존 signer 카드의 320 dp 오버플로는 별도 추적한다.
          viewport: type == WalletType.multiSignature ? const Size(430, 932) : const Size(320, 844),
        );
        final label =
            type == WalletType.singleSignature
                ? t.wallet_health.watch_only_verify.title
                : t.wallet_health.bsms_verify.title;
        expect(_text(label), provider ? findsOneWidget : findsNothing);
        if (provider) {
          final lastMenu = _text(
            type == WalletType.singleSignature
                ? t.wallet_info_screen.extended_public_key
                : t.wallet_info_screen.view_wallet_backup_data,
          );
          final safetyRow = find.byKey(const Key('wallet-safety-status-row'));
          expect(tester.getTopLeft(safetyRow).dy, greaterThan(tester.getBottomLeft(lastMenu).dy));
          expect(
            tester.getBottomLeft(safetyRow).dy,
            lessThan(tester.getTopLeft(_text(t.wallet_info_screen.target_quantity)).dy),
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('wallet info Premium destination follows entitlement and provider updates below safety', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsRepository().init();
    final entitlement = FakeEntitlementService();
    final rescue = _Rescue();
    addTearDown(entitlement.dispose);
    addTearDown(rescue.dispose);
    await mount(
      tester,
      CoconutThemeVariant.light,
      MultiProvider(
        providers: [
          InheritedProvider<AuthProvider>.value(value: _Auth()),
          InheritedProvider<NodeProvider>.value(value: _Node()),
          InheritedProvider<PreferenceProvider>.value(value: _Preferences()),
          InheritedProvider<UtxoTagProvider>.value(value: _Tags()),
          Provider<EntitlementService>.value(value: entitlement),
          ChangeNotifierProvider<RescueReadyProvider>.value(value: rescue),
        ],
        child: const WalletInfoScreen(id: 1, walletType: WalletType.singleSignature, entryPoint: '/wallet-home'),
      ),
    );
    final row = find.byKey(const Key('wallet-rescue-destination-row'));
    expect(row, findsOneWidget); // C36: 무료에게도 자리를 보인다("정하지 않음" + Premium 칩)
    entitlement.emit(const PremiumState(PremiumStatus.active));
    await tester.pumpAndSettle();
    expect(row, findsOneWidget);
    expect(_text(t.premium.rescue.destination), findsOneWidget);
    expect(_text(t.premium.rescue.not_set), findsOneWidget);
    expect(tester.getTopLeft(row).dy, tester.getBottomLeft(find.byKey(const Key('wallet-safety-status-row'))).dy);
    rescue.rename('Emergency wallet');
    await tester.pumpAndSettle();
    expect(_text('Emergency wallet'), findsOneWidget);
    for (final status in [PremiumStatus.verifying, PremiumStatus.pending, PremiumStatus.expired, PremiumStatus.none]) {
      entitlement.emit(PremiumState(status));
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);
    }
    rescue.rename(null);
    await tester.pumpAndSettle();
    expect(row, findsOneWidget); // 목적지를 지워도 자리는 남는다(C36)
    expect(_text(t.premium.rescue.not_set), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('animated BSMS fragments use the existing scanner decoder', (tester) async {
    await mount(tester, CoconutThemeVariant.light, const BsmsVerificationScreen(walletId: 2));
    await startScan(tester, t.wallet_health.bsms_verify.scan);
    final encoder = CBOREncoder()..encodeBytes(Uint8List.fromList(utf8.encode('BSMS 1.0\n${multi.descriptor}')));
    final ur = UREncoder(UR('bytes', encoder.getBytes()), 100);
    for (var i = 0; i < 50 && safety.bsms.isEmpty; i++) {
      await capture(tester, ur.nextPart());
    }
    expect(safety.bsms.single.matched, isTrue);
  });
}
