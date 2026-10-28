import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/screens/common/tag_edit_bottom_sheet.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_tag_crud_screen.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _screenSize = Size(414, 896);
const _keyboardHeight = 300.0;
const _existingTag = UtxoTag(id: 'qa-tag', walletId: 1, name: 'Existing tag', colorIndex: 0);

class _TagProvider extends Fake with ChangeNotifier implements UtxoTagProvider {
  final List<UtxoTag> tags = [_existingTag];
  UtxoTag? savedTag;

  @override
  List<UtxoTag> getUtxoTagList(int walletId) => List.of(tags);

  @override
  bool addUtxoTag(int walletId, UtxoTag tag) {
    savedTag = tag;
    tags.add(tag);
    return true;
  }

  @override
  bool updateUtxoTag(int walletId, UtxoTag tag) {
    savedTag = tag;
    tags[tags.indexWhere((existing) => existing.id == tag.id)] = tag;
    return true;
  }
}

void _setBottomInsets(
  WidgetTester tester,
  double safeArea, {
  required bool keyboardOpen,
  double keyboardHeight = _keyboardHeight,
}) {
  final inset = keyboardOpen ? keyboardHeight : 0.0;
  tester.view.viewPadding = FakeViewPadding(bottom: safeArea);
  tester.view.padding = FakeViewPadding(bottom: (safeArea - inset).clamp(0.0, safeArea));
  tester.view.viewInsets = FakeViewPadding(bottom: inset);
}

Future<_TagProvider> _openTagSheet(
  WidgetTester tester, {
  required TargetPlatform platform,
  required double safeArea,
  required bool edit,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _screenSize;
  _setBottomInsets(tester, safeArea, keyboardOpen: false);
  addTearDown(tester.view.reset);
  final provider = _TagProvider();
  addTearDown(provider.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<UtxoTagProvider>.value(
      value: provider,
      child: MaterialApp(
        theme: buildCoconutThemeData().copyWith(platform: platform),
        home: const UtxoTagCrudScreen(id: 1),
      ),
    ),
  );

  if (edit) {
    await tester.tap(find.text('#${_existingTag.name}'));
    await tester.pump();
    await tester.tap(find.text(t.edit));
  } else {
    await tester.tap(find.byIcon(Icons.add_rounded));
  }
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
  expect(find.byType(TagEditBottomSheet), findsOneWidget);
  expect(tester.widget<InlineActionButton>(find.byType(InlineActionButton)).isActive, isFalse);
  expect(tester.takeException(), isNull);
  return provider;
}

void main() {
  final configurations = [
    (name: 'Android three-button navigation', platform: TargetPlatform.android, safeArea: 48.0),
    (name: 'Android gesture navigation', platform: TargetPlatform.android, safeArea: 24.0),
    (name: 'iPhone home indicator', platform: TargetPlatform.iOS, safeArea: 34.0),
    (name: 'no bottom system inset', platform: TargetPlatform.android, safeArea: 0.0),
  ];

  for (final configuration in configurations) {
    for (final edit in [false, true]) {
      testWidgets('${configuration.name}: ${edit ? 'edit' : 'add'} keeps Done above the keyboard and system area', (
        tester,
      ) async {
        final provider = await _openTagSheet(
          tester,
          platform: configuration.platform,
          safeArea: configuration.safeArea,
          edit: edit,
        );
        final button = find.byType(InlineActionButton);
        final editable = find.byType(EditableText);
        final enteredName = edit ? 'Updated tag' : 'New tag';
        await tester.enterText(editable, enteredName);
        _setBottomInsets(tester, configuration.safeArea, keyboardOpen: true);
        await tester.pumpAndSettle();

        final keyboardOpenButton = tester.getRect(button);
        final keyboardOpenInput = tester.getRect(editable);
        expect(keyboardOpenButton.bottom, closeTo(_screenSize.height - _keyboardHeight - 20, 0.01));
        expect(keyboardOpenButton.left, 16);
        expect(keyboardOpenButton.right, _screenSize.width - 16);

        for (var cycle = 0; cycle < 2; cycle++) {
          if (configuration.safeArea > 0) {
            _setBottomInsets(
              tester,
              configuration.safeArea,
              keyboardOpen: true,
              keyboardHeight: configuration.safeArea / 2,
            );
            await tester.pumpAndSettle();
            expect(
              tester.getRect(button).bottom,
              closeTo(_screenSize.height - configuration.safeArea - 20, 0.01),
              reason: 'A partially closed keyboard must still respect the unoccluded system padding.',
            );
          }

          // Android Back hides the IME without popping the sheet. Model the
          // resulting window metrics; a host widget test has no native IME.
          tester.testTextInput.hide();
          _setBottomInsets(tester, configuration.safeArea, keyboardOpen: false);
          await tester.pumpAndSettle();

          final closedButton = tester.getRect(button);
          final closedInput = tester.getRect(editable);
          expect(closedButton.bottom, closeTo(_screenSize.height - configuration.safeArea - 20, 0.01));
          expect(closedButton.bottom, lessThanOrEqualTo(_screenSize.height - configuration.safeArea));
          expect(closedButton.size, keyboardOpenButton.size);
          expect(closedInput.size, keyboardOpenInput.size);
          expect(
            closedButton.top - closedInput.bottom,
            closeTo(keyboardOpenButton.top - keyboardOpenInput.bottom, 0.01),
          );
          expect(tester.widget<EditableText>(editable).controller.text, enteredName);
          expect(tester.widget<InlineActionButton>(button).isActive, isTrue);
          expect(tester.takeException(), isNull);

          if (cycle == 0) {
            await tester.showKeyboard(editable);
            _setBottomInsets(tester, configuration.safeArea, keyboardOpen: true);
            await tester.pumpAndSettle();
            expect(tester.getRect(button), keyboardOpenButton);
          }
        }

        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(TagEditBottomSheet), findsNothing);
        expect(provider.savedTag?.name, enteredName);
        expect(provider.savedTag?.walletId, 1);
        if (edit) expect(provider.savedTag?.id, _existingTag.id);
        expect(find.text('#$enteredName'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
