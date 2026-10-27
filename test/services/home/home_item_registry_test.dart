import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/model/feature/feature_item.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/services/home/home_item_registry.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Def extends HomeItemDefinition {
  _Def(String id)
    : super(
        id: id,
        kind: HomeItemKind.widget,
        supportedSpans: const [HomeSpan.small],
        category: HomeItemCategory.wallets,
      );

  @override
  Widget build(BuildContext context, HomeItem item) => const SizedBox();
}

void main() {
  test('a registered definition can be looked up by id', () {
    final registry = HomeItemRegistry()..register(_Def('x'));

    expect(registry.byId('x'), isNotNull);
    expect(registry.byId('y'), isNull);
  });

  test('registering the same id twice is an error', () {
    final registry = HomeItemRegistry()..register(_Def('x'));

    expect(() => registry.register(_Def('x')), throwsStateError);
  });

  test('shortcut definitions are generated from every shortcut-eligible feature', () {
    final features = FeatureRegistry.builtin();
    final registry = HomeItemRegistry()..registerShortcuts(features);

    final shortcuts = registry.all.where((d) => d.kind == HomeItemKind.shortcut).toList();
    expect(shortcuts, hasLength(features.shortcutEligible.length));
    expect(shortcuts.every((d) => d.supportedSpans.single == HomeSpan.shortcut), isTrue);
    for (final definition in shortcuts.cast<ShortcutDefinition>()) {
      expect(definition.requiresWalletContext, definition.feature.context == FeatureContext.wallet);
    }
  });

  testWidgets('a shortcut shows its icon and label on a filled background', (tester) async {
    final features = FeatureRegistry.builtin();
    final registry = HomeItemRegistry()..registerShortcuts(features);
    final definition = registry.byId(HomeItemIds.shortcut(FeatureIds.calculator))!;
    final item = HomeItem(
      id: 's',
      definitionId: definition.id,
      kind: HomeItemKind.shortcut,
      order: 0,
      span: HomeSpan.shortcut,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Center(child: SizedBox(width: 80, height: 80, child: Builder(builder: (c) => definition.build(c, item)))),
      ),
    );

    expect(find.byKey(const ValueKey('shortcut-icon-${FeatureIds.calculator}')), findsOneWidget);
    final background = find.byKey(const ValueKey('shortcut-background-${FeatureIds.calculator}'));
    expect(tester.getSize(background), const Size(80, 80));
    expect((tester.widget<DecoratedBox>(background).decoration as BoxDecoration).color, isNotNull);
    expect(find.text(features.byId(FeatureIds.calculator)!.label()), findsOneWidget);
  });
  testWidgets('a shortcut fills its 1×1 cell', (tester) async {
    final features = FeatureRegistry.builtin();
    final registry = HomeItemRegistry()..registerShortcuts(features);
    final definition = registry.all.firstWhere((d) => d.kind == HomeItemKind.shortcut);
    const item = HomeItem(id: 's', definitionId: 'x', kind: HomeItemKind.shortcut, order: 0, span: HomeSpan.shortcut);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Center(child: SizedBox(width: 80, height: 80, child: Builder(builder: (c) => definition.build(c, item)))),
      ),
    );

    expect(tester.getSize(find.byType(CupertinoButton)), const Size(80, 80));
  });

  testWidgets('a shortcut uses the short label while the full label stays for lists', (tester) async {
    final features = FeatureRegistry.builtin();
    final registry = HomeItemRegistry()..registerShortcuts(features);
    final definition = registry.byId(HomeItemIds.shortcut(FeatureIds.transactionDraft))!;
    final feature = features.byId(FeatureIds.transactionDraft)!;
    final item = HomeItem(
      id: 'd',
      definitionId: definition.id,
      kind: HomeItemKind.shortcut,
      order: 0,
      span: HomeSpan.shortcut,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Center(child: SizedBox(width: 80, height: 80, child: Builder(builder: (c) => definition.build(c, item)))),
      ),
    );

    expect(find.text(feature.shortLabel!()), findsOneWidget);
    expect(find.text(feature.label()), findsNothing);
    expect(definition.displayName(), feature.label());
  });
}
