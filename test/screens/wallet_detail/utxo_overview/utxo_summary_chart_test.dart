import 'dart:io';
import 'package:coconut_wallet/utils/result.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_overview_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/legacy_utxo_overview_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_bucket_card_row.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_bucket_scroll_rail.dart';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_bucket.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_summary_chart.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_tag_chart.dart';
import 'package:coconut_wallet/utils/utxo_tier_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  UtxoTierTheme get utxoTierTheme => UtxoTierThemes.pastelWallet;
  @override
  UtxoOrder get utxoSortOrder => UtxoOrder.byAmountDesc;
  @override
  String get language => 'ko';
}

class _Wallet extends Fake implements WalletItemBase {
  @override
  int get id => 7;
  @override
  WalletType get walletType => WalletType.singleSignature;
}

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  final utxos =
      [1000000, 100000, 10000]
          .asMap()
          .entries
          .map(
            (entry) => UtxoState(
              transactionHash: '11' * 32,
              index: entry.key,
              amount: entry.value,
              derivationPath: 'm/0/${entry.key}',
              blockHeight: 1,
              to: 'reused-fixture',
              timestamp: DateTime(2026),
            ),
          )
          .toList();
  @override
  WalletItemBase getWalletById(int id) => _Wallet();
  @override
  Balance getWalletBalance(int walletId) => Balance(1110000, 0);
  @override
  List<UtxoState> getUtxoList(int walletId) => utxos;
  @override
  bool isUtxoSuspicious(UtxoState utxo, TransactionRecord? txRecord) => false;
}

class _Transactions extends Fake with ChangeNotifier implements TransactionProvider {
  @override
  TransactionRecord? getTransaction(int walletId, String txHash, {String? utxoTo}) => null;
}

class _Tags extends Fake with ChangeNotifier implements UtxoTagProvider {
  final List<UtxoTag> tags;
  _Tags([this.tags = const []]);
  @override
  List<UtxoTag> getUtxoTagList(int walletId) => tags;
}

class _Connectivity extends Fake with ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isInternetOn => true;
}

class _Prices extends Fake with ChangeNotifier implements PriceProvider {
  @override
  int? get bitcoinPriceKrw => null;
  @override
  String getFiatPrice(int sats, {FiatCode? fiatCode, bool showCurrencySymbol = true}) => '0';
}

class _Nodes extends Fake with ChangeNotifier implements NodeProvider {
  @override
  Stream<WalletUpdateInfo> getWalletStateStream(int walletId) => const Stream.empty();
  @override
  Future<Result<bool>> syncDormantAddresses(WalletItemBase walletItem) async => Result.success(true);
  @override
  Future<Result<bool>> reconnectIfNeeded() async => Result.success(true);
}

const _captureKey = ValueKey('summary-capture');

Future<void> _pumpSummary(
  WidgetTester tester, {
  required CoconutThemeVariant variant,
  required double scale,
  required bool populated,
  bool warning = false,
  bool legacyHeader = false,
}) async {
  tester.view.physicalSize = const Size(390, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final preferences = _Preferences();
  addTearDown(preferences.dispose);
  final locale = LocaleSettings.currentLocale;
  LocaleSettings.setLocaleSync(AppLocale.ko);
  addTearDown(() => LocaleSettings.setLocaleSync(locale));
  final utxo = UtxoState(
    transactionHash: '11' * 32,
    index: 0,
    amount: 10000,
    derivationPath: 'm/0/0',
    blockHeight: 1,
    to: 'fixture',
    timestamp: DateTime(2026),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<PreferenceProvider>.value(
      value: preferences,
      child: MaterialApp(
        theme: buildCoconutThemeData(variant: variant),
        builder:
            (context, child) =>
                MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
        home: Scaffold(
          body: RepaintBoundary(
            key: _captureKey,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: UtxoSummaryChart(
                    height: legacyHeader ? null : UtxoSummaryChart.estimatedHeight,
                    buckets:
                        populated
                            ? [
                              UtxoBucket(label: 'tiny', minSats: 547, maxSats: 10000, utxos: [utxo]),
                            ]
                            : [],
                    totalSats: populated ? 10000 : 0,
                    coinCount: populated ? 1 : 0,
                    availableCount: populated ? 1 : 0,
                    availableSats: populated ? 10000 : 0,
                    lockedCount: 0,
                    lockedSats: 0,
                    currentUnit: BitcoinUnit.btc,
                    dustThreshold: 546,
                    showBalanceHeader: legacyHeader,
                    hasReusedAddresses: warning,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 56, child: Center(child: Text('FOLLOWING CONTENT')))),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<Map<String, double>> _captureSummary(WidgetTester tester, String name) async {
  final summary = tester.getRect(find.byType(UtxoSummaryChart));
  final labels = find.textContaining('coins');
  final chip = tester.getRect(find.ancestor(of: labels.first, matching: find.byType(Container)).first);
  final metrics = <String, double>{
    'summaryHeight': summary.height,
    'chipHeight': chip.height,
    'chipTop': chip.top - summary.top,
    'chipBottom': chip.bottom - summary.top,
    'followingTop': tester.getRect(find.text('FOLLOWING CONTENT')).top,
  };
  debugPrint('SUMMARY_METRICS $name ${jsonEncode(metrics)}');
  const output = String.fromEnvironment('UTXO_SUMMARY_ARTIFACT_DIR');
  if (output.isNotEmpty) {
    await tester.runAsync(() async {
      final directory = Directory(output)..createSync(recursive: true);
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_captureKey));
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File('${directory.path}/$name.png').writeAsBytes(bytes.buffer.asUint8List());
      await File('${directory.path}/$name.json').writeAsString(jsonEncode(metrics));
      image.dispose();
    });
  }
  return metrics;
}

Future<void> _captureScreenPixels(WidgetTester tester, GlobalKey key, String name) async {
  final chartFinder = name.startsWith('tags-') ? find.byType(UtxoTagChart) : find.byType(UtxoSummaryChart);
  final summary = tester.getRect(chartFinder);
  final context = tester.element(chartFinder);
  final expectedBackground = context.coconutColors.background.toARGB32();
  final expectedDivider = context.coconutColors.divider.toARGB32();
  final expectedChipSurface = context.coconutColors.utxoOverviewAvailabilitySurface.toARGB32();
  final chipRects =
      name.startsWith('tags-')
          ? <Rect>[]
          : find
              .descendant(
                of: chartFinder,
                matching: find.byWidgetPredicate(
                  (widget) => widget is Container && widget.padding == const EdgeInsets.all(12),
                ),
              )
              .evaluate()
              .map((element) => tester.getRect(find.byWidget(element.widget)))
              .toList();
  final data = await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final raw = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      int pixel(int x, int y) {
        final i = (y * image.width + x) * 4;
        return (raw.getUint8(i + 3) << 24) | (raw.getUint8(i) << 16) | (raw.getUint8(i + 1) << 8) | raw.getUint8(i + 2);
      }

      final points = <String, int>{
        'summaryTop': (summary.top + 2).round(),
        'summaryBottom': (summary.bottom - 2).round(),
        'chipBottomPadding': (summary.bottom - 12).round(),
        'afterSummary': (summary.bottom + 2).round(),
        'aboveNativeInset': image.height - 56,
        'insideNativeInset': image.height - 2,
      };
      final colors = <String, int>{};
      for (final entry in points.entries) {
        if (entry.value >= 0 && entry.value < image.height) {
          final x = entry.key == 'chipBottomPadding' ? image.width ~/ 2 : image.width - 3;
          colors[entry.key] = pixel(x, entry.value);
        }
      }
      final chipEdges = [for (final rect in chipRects) pixel(rect.center.dx.round(), rect.top.ceil())];
      final result = <String, Object>{
        'name': name,
        'summaryTopY': summary.top,
        'summaryBottomY': summary.bottom,
        'expectedBackground': expectedBackground,
        'expectedDivider': expectedDivider,
        'expectedChipSurface': expectedChipSurface,
        'chipRects': [
          for (final rect in chipRects) [rect.left, rect.top, rect.width, rect.height],
        ],
        'chipEdges': chipEdges,
        'sampleY': points,
        'pixels': colors,
      };
      const directory = String.fromEnvironment('UTXO_SCREEN_ARTIFACT_DIR');
      if (directory.isNotEmpty) {
        await Directory(directory).create(recursive: true);
        final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File('$directory/$name.png').writeAsBytes(png.buffer.asUint8List());
        await File('$directory/$name.json').writeAsString(jsonEncode(result));
      }
      return result;
    } finally {
      image.dispose();
    }
  });
  debugPrint('COINS_SURFACE_PIXELS ${jsonEncode(data)}');
  final pixels = data!['pixels']! as Map<String, int>;
  if (!name.startsWith('tags-')) {
    expect(chipRects, hasLength(2));
    expect(
      data['chipEdges'],
      everyElement(expectedChipSurface),
      reason: 'Both cards use a flat fill without an outline',
    );
    expect(expectedChipSurface, isNot(expectedBackground), reason: 'Card fill must distinguish it from the page');
  }
  for (final sample in ['aboveNativeInset', 'insideNativeInset']) {
    expect(pixels[sample], expectedBackground);
  }
  if (pixels.containsKey('afterSummary')) expect(pixels['afterSummary'], expectedBackground);
  for (final sample in ['chipBottomPadding', 'summaryBottom']) {
    if (pixels.containsKey(sample)) {
      expect(pixels[sample], expectedBackground, reason: 'Flat summary must not end in a divider-colored band');
    }
  }
}

void main() {
  setUpAll(() async {
    for (final family in ['Pretendard', 'SpaceGrotesk']) {
      final loader = FontLoader(family);
      for (final weight in ['Regular', 'Bold']) {
        loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$family-$weight.ttf').readAsBytesSync())));
      }
      await loader.load();
    }
  });

  for (final legacy in [false, true]) {
    for (final variant in CoconutThemeVariant.values) {
      for (final populated in [false, true]) {
        for (final scale in [1.0, 2.0]) {
          final name =
              '${legacy ? 'legacy' : 'current'}-${variant.name}-${populated ? 'populated' : 'empty'}-${scale}x';
          testWidgets('actual screen surface pixels $name', (tester) async {
            tester.view.physicalSize = const Size(344.38, 746.21);
            tester.view.devicePixelRatio = 1;
            tester.view.padding = const FakeViewPadding(top: 24, bottom: 54);
            tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 54);
            addTearDown(tester.view.reset);
            final locale = LocaleSettings.currentLocale;
            LocaleSettings.setLocaleSync(AppLocale.ko);
            addTearDown(() => LocaleSettings.setLocaleSync(locale));
            final boundary = GlobalKey();
            final wallets = _Wallets();
            if (!populated) wallets.utxos.clear();
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<PreferenceProvider>(create: (_) => _Preferences()),
                  ChangeNotifierProvider<WalletProvider>(create: (_) => wallets),
                  ChangeNotifierProvider<TransactionProvider>(create: (_) => _Transactions()),
                  ChangeNotifierProvider<UtxoTagProvider>(create: (_) => _Tags()),
                  ChangeNotifierProvider<ConnectivityProvider>(create: (_) => _Connectivity()),
                  ChangeNotifierProvider<PriceProvider>(create: (_) => _Prices()),
                  ChangeNotifierProvider<NodeProvider>(create: (_) => _Nodes()),
                ],
                child: RepaintBoundary(
                  key: boundary,
                  child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: buildCoconutThemeData(variant: variant).copyWith(platform: TargetPlatform.android),
                    builder:
                        (context, child) => MediaQuery(
                          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                          child: child!,
                        ),
                    home: legacy ? const LegacyUtxoOverviewScreen(id: 7) : const UtxoOverviewScreen(id: 7),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await _captureScreenPixels(tester, boundary, name);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          });
        }
      }
    }
  }

  for (final legacy in [false, true]) {
    for (final variant in CoconutThemeVariant.values) {
      for (final populated in [false, true]) {
        for (final scale in [1.0, 2.0]) {
          final name =
              'tags-${legacy ? 'legacy' : 'current'}-${variant.name}-${populated ? 'populated' : 'empty'}-${scale}x';
          testWidgets('actual screen surface pixels $name', (tester) async {
            tester.view.physicalSize = const Size(344.38, 746.21);
            tester.view.devicePixelRatio = 1;
            tester.view.padding = const FakeViewPadding(top: 24, bottom: 54);
            tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 54);
            addTearDown(tester.view.reset);
            final locale = LocaleSettings.currentLocale;
            LocaleSettings.setLocaleSync(AppLocale.ko);
            addTearDown(() => LocaleSettings.setLocaleSync(locale));
            final boundary = GlobalKey();
            final wallets = _Wallets();
            if (!populated) wallets.utxos.clear();
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<PreferenceProvider>(create: (_) => _Preferences()),
                  ChangeNotifierProvider<WalletProvider>(create: (_) => wallets),
                  ChangeNotifierProvider<TransactionProvider>(create: (_) => _Transactions()),
                  ChangeNotifierProvider<UtxoTagProvider>(
                    create:
                        (_) => _Tags([
                          UtxoTag(
                            id: 'fixture-tag',
                            walletId: 7,
                            name: '저축',
                            colorIndex: 0,
                            utxoIdList: wallets.utxos.map((utxo) => utxo.utxoId).toList(),
                          ),
                        ]),
                  ),
                  ChangeNotifierProvider<ConnectivityProvider>(create: (_) => _Connectivity()),
                  ChangeNotifierProvider<PriceProvider>(create: (_) => _Prices()),
                  ChangeNotifierProvider<NodeProvider>(create: (_) => _Nodes()),
                ],
                child: RepaintBoundary(
                  key: boundary,
                  child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: buildCoconutThemeData(variant: variant).copyWith(platform: TargetPlatform.android),
                    builder:
                        (context, child) => MediaQuery(
                          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                          child: child!,
                        ),
                    home: legacy ? const LegacyUtxoOverviewScreen(id: 7) : const UtxoOverviewScreen(id: 7),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text(t.utxo_overview_screen.by_tag));
            await tester.pumpAndSettle();
            expect(find.byType(UtxoTagChart), findsOneWidget);
            await _captureScreenPixels(tester, boundary, name);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          });
        }
      }
    }
  }

  for (final legacy in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('actual ${legacy ? 'legacy' : 'current'} caller tracks 3 buckets and restores at ${scale}x with warning', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        LocaleSettings.setLocaleSync(AppLocale.ko);
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<PreferenceProvider>(create: (_) => _Preferences()),
              ChangeNotifierProvider<WalletProvider>(create: (_) => _Wallets()),
              ChangeNotifierProvider<TransactionProvider>(create: (_) => _Transactions()),
              ChangeNotifierProvider<UtxoTagProvider>(create: (_) => _Tags()),
              ChangeNotifierProvider<ConnectivityProvider>(create: (_) => _Connectivity()),
              ChangeNotifierProvider<PriceProvider>(create: (_) => _Prices()),
              ChangeNotifierProvider<NodeProvider>(create: (_) => _Nodes()),
            ],
            child: MaterialApp(
              navigatorKey: navigator,
              theme: buildCoconutThemeData(variant: CoconutThemeVariant.light),
              builder:
                  (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
              onGenerateRoute:
                  (_) => MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('detail fixture'))),
              home: legacy ? const LegacyUtxoOverviewScreen(id: 7) : const UtxoOverviewScreen(id: 7),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final idleRows = tester.widgetList<UtxoBucketCardRow>(find.byType(UtxoBucketCardRow)).toList();
        expect(idleRows, isNotEmpty);
        final idleRail = tester.widget<UtxoBucketScrollRail>(find.byType(UtxoBucketScrollRail));
        final idleRow = idleRows.firstWhere((row) => row.index == idleRail.activeIndexListenable.value);
        final idleCenter = tester.getRect(find.byWidget(idleRow)).center.dy;
        final idleRailTop = tester.getRect(find.byType(UtxoBucketScrollRail)).top;
        expect(idleRailTop + idleRail.activeBucketY.value, closeTo(idleCenter, 0.01));
        if (!legacy) {
          final header = tester.widget<NestedScrollView>(find.byType(NestedScrollView)).controller!;
          header.jumpTo(header.position.maxScrollExtent);
          await tester.pumpAndSettle();
        }
        final summaryHeight = tester.getSize(find.byType(UtxoSummaryChart)).height;
        final rail = tester.widget<UtxoBucketScrollRail>(find.byType(UtxoBucketScrollRail));
        final controller = rail.scrollController;
        const filterHeight = 58.0;
        const rowHeight = UtxoBucketCardRow.rowHeight + 20;
        final target =
            summaryHeight +
            filterHeight +
            rowHeight -
            (controller.position.viewportDimension - filterHeight) / 2 +
            rowHeight / 2;
        controller.jumpTo(
          target.clamp(controller.position.minScrollExtent + 2, controller.position.maxScrollExtent - 2),
        );
        await tester.pumpAndSettle();
        debugPrint(
          'CALLER_POSITION legacy=$legacy scale=$scale summary=$summaryHeight target=$target offset=${controller.offset} max=${controller.position.maxScrollExtent} viewport=${controller.position.viewportDimension} active=${rail.activeIndexListenable.value}',
        );
        expect(rail.activeIndexListenable.value, 1);
        final row = tester
            .widgetList<UtxoBucketCardRow>(find.byType(UtxoBucketCardRow))
            .singleWhere((row) => row.index == 1);
        final rowCenter = tester.getRect(find.byWidget(row)).center.dy;
        final railTop = tester.getRect(find.byType(UtxoBucketScrollRail)).top;
        expect(railTop + rail.activeBucketY.value, closeTo(rowCenter, 0.01));
        debugPrint(
          'RENDERED_ALIGNMENT legacy=$legacy scale=$scale rowCenter=$rowCenter railTop=$railTop indicator=${rail.activeBucketY.value}',
        );
        final before = controller.offset;
        row.onTapUtxo(row.bucket.utxos.first);
        await tester.pumpAndSettle();
        expect(find.text('detail fixture'), findsOneWidget);
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 400));
        expect(controller.offset, closeTo(before, 0.01));
        expect(rail.activeIndexListenable.value, 1);
        debugPrint(
          'CALLER_GEOMETRY legacy=$legacy scale=$scale summary=$summaryHeight restoredOffset=${controller.offset} active=${rail.activeIndexListenable.value}',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  for (final variant in CoconutThemeVariant.values) {
    for (final scale in [1.0, 2.0]) {
      for (final populated in [false, true]) {
        final name = '${variant.name}-${populated ? 'populated' : 'empty'}-${scale}x';
        testWidgets('$name keeps only the space required by its content', (tester) async {
          await _pumpSummary(tester, variant: variant, scale: scale, populated: populated);
          final metrics = await _captureSummary(tester, name);
          expect(tester.takeException(), isNull);
          expect(find.textContaining('coins'), findsNWidgets(2));
          expect(find.byIcon(Icons.info_outline_rounded), populated ? findsOneWidget : findsNothing);
          if (populated) {
            expect(metrics['summaryHeight'], UtxoSummaryChart.estimatedHeight);
          } else {
            expect(metrics['chipTop'], 20);
            expect(metrics['summaryHeight']! - metrics['chipBottom']!, 24);
            expect(metrics['summaryHeight'], lessThan(UtxoSummaryChart.estimatedHeight));
          }
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
  for (final variant in CoconutThemeVariant.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$variant populated warning fits at ${scale}x without clipping', (tester) async {
        await _pumpSummary(tester, variant: variant, scale: scale, populated: true, warning: true);
        await _captureSummary(tester, '${variant.name}-populated-warning-${scale}x');
        expect(tester.takeException(), isNull);
        final summary = tester.getRect(find.byType(UtxoSummaryChart));
        if (scale == 1) expect(summary.height, UtxoSummaryChart.estimatedHeight);
        for (final text in find.descendant(of: find.byType(UtxoSummaryChart), matching: find.byType(Text)).evaluate()) {
          final rect = tester.getRect(find.byWidget(text.widget));
          expect(rect.top, greaterThanOrEqualTo(summary.top));
          expect(rect.bottom, lessThanOrEqualTo(summary.bottom));
          expect(rect.right, lessThanOrEqualTo(summary.right));
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  for (final legacyHeader in [false, true]) {
    testWidgets('empty summary retains warning at 2x with legacyHeader=$legacyHeader', (tester) async {
      await _pumpSummary(
        tester,
        variant: CoconutThemeVariant.light,
        scale: 2,
        populated: false,
        warning: true,
        legacyHeader: legacyHeader,
      );
      await _captureSummary(tester, 'empty-warning-legacy$legacyHeader-2x');
      expect(tester.takeException(), isNull);
      final summary = tester.getRect(find.byType(UtxoSummaryChart));
      for (final text in find.descendant(of: find.byType(UtxoSummaryChart), matching: find.byType(Text)).evaluate()) {
        final rect = tester.getRect(find.byWidget(text.widget));
        expect(rect.top, greaterThanOrEqualTo(summary.top));
        expect(rect.bottom, lessThanOrEqualTo(summary.bottom));
        expect(rect.right, lessThanOrEqualTo(summary.right));
      }
      expect(find.text(t.utxo_list_screen.reused_address), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final scale in [1.3, 2.0]) {
    testWidgets('interval names and unchanged ranges fit 320px at scale $scale', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final locale = LocaleSettings.currentLocale;
      LocaleSettings.setLocaleSync(AppLocale.en);
      addTearDown(() => LocaleSettings.setLocaleSync(locale));
      final preferences = _Preferences();
      addTearDown(preferences.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<PreferenceProvider>.value(
          value: preferences,
          child: MaterialApp(
            theme: buildCoconutThemeData(),
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
            home: const Scaffold(
              body: UtxoSummaryChart(
                buckets: [UtxoBucket(label: 'dust', minSats: 0, maxSats: 546, utxos: [])],
                totalSats: 0,
                coinCount: 0,
                availableCount: 0,
                availableSats: 0,
                lockedCount: 0,
                lockedSats: 0,
                currentUnit: BitcoinUnit.btc,
                dustThreshold: 546,
                showBalanceHeader: false,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('meduim'), findsNothing);
      const expected = [
        ('whale', 1000000000, 2100000000000000),
        ('whole', 100000000, 999999999),
        ('huge', 10000000, 99999999),
        ('large', 1000001, 9999999),
        ('medium', 100001, 1000000),
        ('small', 10001, 100000),
        ('tiny', 547, 10000),
        ('dust', 0, 546),
      ];
      expect(getUtxoBucketRanges(dustThreshold: 546).map((r) => (r.label, r.min, r.max)), expected);
      final sheet = find.byType(BottomSheet);
      final texts = find.descendant(of: sheet, matching: find.byType(Text));
      for (final (label, _, _) in expected) {
        final name = find.descendant(of: sheet, matching: find.text(label));
        expect(name, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(name);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(paragraph.size.width, greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity) - 0.01));
        final group = find.ancestor(of: name, matching: find.byType(Column)).first;
        final labels = find.descendant(of: group, matching: find.byType(Text));
        expect(labels, findsNWidgets(2));
        final range = labels.at(1);
        expect(tester.getRect(range).top, greaterThanOrEqualTo(tester.getRect(name).bottom));
      }
      for (final element in texts.evaluate()) {
        final rect = tester.getRect(find.byWidget(element.widget));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
      }
      final dust = find.descendant(of: sheet, matching: find.text('dust'));
      await tester.ensureVisible(dust);
      await tester.pumpAndSettle();
      final dustRange = find.descendant(of: sheet, matching: find.text('0 ~ 546 sats'));
      expect(dustRange, findsOneWidget);
      await tester.ensureVisible(dustRange);
      await tester.pumpAndSettle();
      expect(tester.getRect(dustRange).bottom, lessThanOrEqualTo(800));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('coins', skipOffstage: false), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
