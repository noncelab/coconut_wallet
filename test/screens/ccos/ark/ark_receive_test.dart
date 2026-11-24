import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ark/ark_receive_view_model.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_receive_screen.dart';
import 'package:coconut_wallet/widgets/common/buttons/copy_text_container.dart';
import 'package:coconut_wallet/widgets/features/qr/qrcode_info.dart';
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
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
          home: const ArkReceiveScreen(),
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
