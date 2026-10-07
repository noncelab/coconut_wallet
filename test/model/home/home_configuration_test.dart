import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/model/home/shortcut_wallet_context.dart';
import 'package:coconut_wallet/services/home/home_item_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Def extends HomeItemDefinition {
  _Def(String id, List<HomeSpan> spans)
    : super(id: id, kind: HomeItemKind.widget, supportedSpans: spans, category: 'test');

  @override
  Widget build(BuildContext context, HomeItem item) => const SizedBox();
}

HomeItem _widget(String id, String definitionId, int order, HomeSpan span) {
  return HomeItem(id: id, definitionId: definitionId, kind: HomeItemKind.widget, order: order, span: span);
}

void main() {
  test('HomeConfiguration survives a JSON round trip', () {
    final config = HomeConfiguration(
      items: [
        _widget('a', HomeItemIds.hotWalletStack, 0, HomeSpan.small),
        const HomeItem(
          id: 'b',
          definitionId: 'shortcut:receive',
          kind: HomeItemKind.shortcut,
          order: 1,
          span: HomeSpan.shortcut,
          configuration: {'k': 'v'},
        ),
      ],
      shortcutWalletContext: const ShortcutWalletContext.wallet(7),
    );

    expect(HomeConfiguration.fromJson(config.toJson()), config);
  });

  test('normalize replaces a span the definition does not allow with its first allowed span', () {
    final registry = HomeItemRegistry()..register(_Def('w', [HomeSpan.wide]));
    final config = HomeConfiguration(items: [_widget('a', 'w', 0, HomeSpan.small)]);

    expect(config.normalize(registry.byId).items.single.span, HomeSpan.wide);
  });

  test('normalize keeps only the first item of a duplicated definition', () {
    final registry = HomeItemRegistry()..register(_Def('w', [HomeSpan.small]));
    final config = HomeConfiguration(
      items: [_widget('a', 'w', 0, HomeSpan.small), _widget('b', 'w', 1, HomeSpan.small)],
    );

    expect(config.normalize(registry.byId).items.map((i) => i.id), ['a']);
  });

  test('Hot and Watch-only wallet stacks are different definitions and can coexist', () {
    final registry =
        HomeItemRegistry()
          ..register(_Def(HomeItemIds.hotWalletStack, [HomeSpan.small, HomeSpan.wide]))
          ..register(_Def(HomeItemIds.watchOnlyWalletStack, [HomeSpan.small, HomeSpan.wide]));
    final config = HomeConfiguration(
      items: [
        _widget('a', HomeItemIds.hotWalletStack, 0, HomeSpan.small),
        _widget('b', HomeItemIds.watchOnlyWalletStack, 1, HomeSpan.small),
      ],
    );

    expect(config.normalize(registry.byId).items, hasLength(2));
  });

  test('normalize keeps items whose definition is not registered yet', () {
    final config = HomeConfiguration(items: [_widget('a', HomeItemIds.safetyStatus, 0, HomeSpan.wide)]);

    expect(config.normalize(HomeItemRegistry().byId).items, hasLength(1));
  });
  test('a definition that allows multiple instances is not de-duplicated', () {
    final registry = HomeItemRegistry()..register(_MultiDef());
    final config = HomeConfiguration(
      items: [_widget('a', 'multi', 0, HomeSpan.small), _widget('b', 'multi', 1, HomeSpan.wide)],
    );

    expect(config.normalize(registry.byId).items.map((i) => i.id), ['a', 'b']);
  });

  test('saved legacy empty-space items are dropped when loading', () {
    final config = HomeConfiguration.fromJson({
      'version': 1,
      'items': [
        {'id': 'a', 'definitionId': 'w', 'kind': 'widget', 'order': 0, 'span': '2x2'},
        {'id': 's', 'definitionId': 'spacer', 'kind': 'spacer', 'order': 1, 'span': '1x1'},
      ],
    });

    expect(config!.items.map((i) => i.id), ['a']);
  });

  group('editing', () {
    HomeConfiguration three() => HomeConfiguration(
      items: [
        _widget('a', 'w1', 0, HomeSpan.small),
        _widget('b', 'w2', 1, HomeSpan.small),
        _widget('c', 'w3', 2, HomeSpan.small),
      ],
    );

    test('addItem appends the item at the end', () {
      final next = three().addItem(_widget('d', 'w4', 0, HomeSpan.wide));

      expect(next.items.map((i) => i.id), ['a', 'b', 'c', 'd']);
      expect(next.items.map((i) => i.order), [0, 1, 2, 3]);
    });

    test('moveItem moves an item to the given index and renumbers the order', () {
      final next = three().moveItem('c', 0);

      expect(next.items.map((i) => i.id), ['c', 'a', 'b']);
      expect(next.items.map((i) => i.order), [0, 1, 2]);
    });

    test('moveItem clamps an out-of-range index and ignores an unknown id', () {
      expect(three().moveItem('a', 99).items.map((i) => i.id), ['b', 'c', 'a']);
      expect(three().moveItem('a', -5).items.map((i) => i.id), ['a', 'b', 'c']);
      expect(three().moveItem('zzz', 0), three());
    });

    test('removeItem removes the item and renumbers the order', () {
      final next = three().removeItem('b');

      expect(next.items.map((i) => i.id), ['a', 'c']);
      expect(next.items.map((i) => i.order), [0, 1]);
    });

    test('editing keeps the shared shortcut wallet', () {
      final config = HomeConfiguration(
        items: [_widget('a', 'w1', 0, HomeSpan.small)],
        shortcutWalletContext: const ShortcutWalletContext.wallet(7),
      );

      expect(config.addItem(_widget('b', 'w2', 0, HomeSpan.small)).shortcutWalletContext, config.shortcutWalletContext);
      expect(config.removeItem('a').shortcutWalletContext, config.shortcutWalletContext);
    });
  });
}

class _MultiDef extends HomeItemDefinition {
  _MultiDef()
    : super(
        id: 'multi',
        kind: HomeItemKind.widget,
        supportedSpans: const [HomeSpan.small, HomeSpan.wide],
        category: 'test',
        allowsMultipleInstances: true,
      );

  @override
  Widget build(BuildContext context, HomeItem item) => const SizedBox();
}
