import 'dart:async';

import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ark/ark_receive_view_model.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_receive_screen.dart';
import 'package:coconut_wallet/widgets/common/buttons/copy_text_container.dart';
import 'package:coconut_wallet/widgets/features/qr/qrcode_info.dart';
import 'package:coconut_wallet/widgets/features/ccos/ark/ark_received_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../ccos/ccos_store_test_fakes.dart';
import '../../../ccos/features/ark/ark_test_fakes.dart';

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  Future<ArkWalletProvider> pump(
    WidgetTester tester, {
    FakeArkBackend? backend,
    Size size = const Size(430, 932),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final wallet = await fakeArkWalletProvider(backend: backend);
    await wallet.createNew();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PreferenceProvider>.value(value: FakeStorePreferences()),
          ChangeNotifierProvider<ArkWalletProvider>.value(value: wallet),
          ...fakeArkPriceProviders(),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
          home: const ArkReceivedToast(child: ArkReceiveScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return wallet;
  }

  testWidgets('it opens on the Ark address', (tester) async {
    await pump(tester);

    expect(find.byKey(const ValueKey('ark-receive-qr-arkAddress')), findsOneWidget);
    expect(find.text(t.ark_wallet.format_ark_caption), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('with a Lightning invoice it asks to keep the screen open', (tester) async {
    await pump(tester);
    expect(find.text(t.ark_wallet.receive_keep_open), findsNothing);

    final viewModel = Provider.of<ArkReceiveViewModel>(tester.element(find.byType(QrCodeInfo)), listen: false);
    await viewModel.setAmount(2100);
    await tester.pumpAndSettle();

    expect(find.text(t.ark_wallet.receive_keep_open), findsOneWidget);
  });

  testWidgets('while an invoice is being made, the amount and share buttons are hidden', (tester) async {
    final backend = FakeArkBackend()..invoiceGate = Completer<void>();
    await pump(tester, backend: backend);
    expect(find.text(t.address_list_screen.share), findsOneWidget);

    final viewModel = Provider.of<ArkReceiveViewModel>(tester.element(find.byType(QrCodeInfo)), listen: false);
    final making = viewModel.setAmount(2100);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(t.ark_wallet.invoice_creating), findsOneWidget);
    expect(find.text(t.address_list_screen.share), findsNothing);
    expect(find.text(t.address_list_screen.set_amount), findsNothing);

    backend.invoiceGate!.complete();
    await making;
    await tester.pumpAndSettle();
    expect(find.text(t.address_list_screen.share), findsOneWidget);
  });

  testWidgets('when the invoice on screen is paid, the screen shows what was received', (tester) async {
    final backend = FakeArkBackend();
    final wallet = await pump(tester, backend: backend);
    final viewModel = Provider.of<ArkReceiveViewModel>(tester.element(find.byType(QrCodeInfo)), listen: false);
    await viewModel.setAmount(2100);
    await tester.pumpAndSettle();

    backend.movements = [
      ArkMovement.fromBark(
        bark.Movement(
          id: 1,
          status: 'successful',
          subsystemName: 'bark.lightning_receive',
          subsystemKind: 'receive',
          metadataJson: '{}',
          intendedBalanceSats: 2100,
          effectiveBalanceSats: 2100,
          offchainFeeSats: 0,
          sentToAddresses: const [],
          receivedOnAddresses: const [],
          inputVtxoIds: const [],
          outputVtxoIds: const [],
          exitedVtxoIds: const [],
          createdAt: '2026-11-25T10:00:00Z',
          updatedAt: '2026-11-25T10:00:00Z',
          paymentHash: 'hash-2100',
        ),
      ),
    ];
    await wallet.syncNow();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ark-receive-received')), findsOneWidget);
    expect(find.text(t.ark_wallet.result_received), findsOneWidget);
    expect(find.byType(QrCodeInfo), findsNothing);
    expect(find.byWidgetPredicate((w) => w is Text && (w.data?.endsWith(' 받았어요') ?? false)), findsNothing);
  });

  testWidgets('without an amount the invoice ways are dimmed', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('ark-receive-ways')));
    await tester.pumpAndSettle();

    expect(find.text(t.ark_wallet.format_lightning_needs_amount), findsNWidgets(2));
    expect(find.byKey(const ValueKey('ark-receive-way-arkAddress')), findsOneWidget);
  });

  testWidgets('a long payment request stays clear of the bottom buttons and the ways sheet fits', (tester) async {
    final backend = FakeArkBackend()..invoiceBody = 'q' * 300;
    await pump(tester, backend: backend, size: const Size(402, 874));
    final viewModel = Provider.of<ArkReceiveViewModel>(tester.element(find.byType(QrCodeInfo)), listen: false);
    await viewModel.setAmount(2100);
    await tester.pumpAndSettle();

    final box = tester.getRect(find.byType(CopyTextContainer));
    expect(box.bottom, lessThan(tester.getTopLeft(find.text(t.address_list_screen.set_amount)).dy));

    await tester.tap(find.byKey(const Key('ark-receive-ways')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the amount sheet shows the Ark wallet unit like the other amount fields', (tester) async {
    final wallet = await pump(tester);
    final field = find.byKey(const Key('ark-move-amount'));

    await tester.tap(find.text(t.address_list_screen.set_amount));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: field, matching: find.byType(EditableText)), '2000');
    await tester.pump();
    final editable = tester.state<EditableTextState>(find.descendant(of: field, matching: find.byType(EditableText)));
    expect(editable.buildTextSpan().toPlainText(), '2,000 sats');
    expect(find.descendant(of: field, matching: find.text(t.max)), findsNothing);

    await wallet.toggleUnit();
    await tester.pump();
    expect(find.descendant(of: field, matching: find.text('₿')), findsOneWidget);
  });
}
