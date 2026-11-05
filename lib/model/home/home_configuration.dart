import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/shortcut_wallet_context.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:collection/collection.dart';

/// 사용자의 새 홈 화면 구성
/// 화면이 읽어서 그리는 데이터이며, 화면 자체는 아니다.
///
/// - 새 홈 화면은 [items]를 순서대로 그리기만 한다.
/// - Edit Home 화면과 길게 누르기 메뉴가 이 데이터를 고친다(추가, 제거, 순서, 크기, 위젯별 설정).
/// - SharedPreferences에 JSON 하나로 저장한다. Realm은 사용하지 않는다.
/// - 처음 새 홈을 켤 때 기존 설정을 읽어 첫 구성을 만든다(요구사항 23.6).
class HomeConfiguration {
  /// 저장 형식 버전. 저장된 값이 이보다 높으면 이 앱이 읽을 수 없는 구성으로 보고 무시한다.
  static const currentVersion = 1;

  final int version;

  /// 홈에 놓인 위젯·바로가기·빈 공간. 생성 시 [HomeItem.order] 순으로 정렬된다.
  final List<HomeItem> items;

  /// 지갑이 필요한 바로가기들이 함께 쓰는 공통 지갑. 바로가기마다 따로 저장하지 않는다(요구사항 16.1).
  final ShortcutWalletContext shortcutWalletContext;

  HomeConfiguration({
    this.version = currentVersion,
    required List<HomeItem> items,
    this.shortcutWalletContext = const ShortcutWalletContext.askEveryTime(),
  }) : items = List.unmodifiable([...items]..sort((a, b) => a.order.compareTo(b.order)));

  static HomeConfiguration? fromJson(Object? json) {
    if (json is! Map) return null;
    final version = json['version'];
    if (version is! int || version > currentVersion) return null;
    final rawItems = json['items'];
    if (rawItems is! List) return null;
    final rawContext = json['shortcutWalletContext'];
    return HomeConfiguration(
      version: version,
      items: rawItems.map(HomeItem.fromJson).whereType<HomeItem>().toList(),
      shortcutWalletContext:
          rawContext is Map
              ? ShortcutWalletContext.fromJson(Map<String, Object?>.from(rawContext))
              : const ShortcutWalletContext.askEveryTime(),
    );
  }

  Map<String, Object?> toJson() => {
    'version': version,
    'items': items.map((item) => item.toJson()).toList(),
    'shortcutWalletContext': shortcutWalletContext.toJson(),
  };

  /// 저장된 구성을 현재 앱의 위젯 정의에 맞게 정리한다.
  ///
  /// - 같은 정의의 위젯·바로가기가 여러 개면 첫 항목만 남긴다. 여러 개를 허용하는 정의는 예외다.
  /// - 정의가 허용하지 않는 크기는 정의의 첫 허용 크기로 바꾼다.
  /// - 아직 등록되지 않은 정의의 항목은 지우지 않고 그대로 둔다. 해당 에픽이 출시되기 전에도 저장값을 잃지 않기 위해서다.
  HomeConfiguration normalize(HomeItemDefinition? Function(String definitionId) definitionOf) {
    final seen = <String>{};
    final normalized = <HomeItem>[];
    for (final item in items) {
      final definition = definitionOf(item.definitionId);
      final repeatable = definition?.allowsMultipleInstances ?? false;
      if (!repeatable && !seen.add(item.definitionId)) continue;
      if (definition == null || definition.supportedSpans.contains(item.span)) {
        normalized.add(item);
      } else {
        normalized.add(item.copyWith(span: definition.supportedSpans.first));
      }
    }
    return HomeConfiguration(version: version, items: normalized, shortcutWalletContext: shortcutWalletContext);
  }

  /// [item]을 맨 뒤에 추가한다.
  HomeConfiguration addItem(HomeItem item) => _withOrderedItems([...items, item]);

  /// [id] 항목을 [toIndex] 위치로 옮긴다. 범위를 벗어난 위치는 처음이나 끝으로 맞추고, 없는 id는 무시한다.
  HomeConfiguration moveItem(String id, int toIndex) {
    final index = items.indexWhere((item) => item.id == id);
    if (index < 0) return this;
    final reordered = [...items];
    final moved = reordered.removeAt(index);
    reordered.insert(toIndex.clamp(0, reordered.length), moved);
    return _withOrderedItems(reordered);
  }

  /// [id] 항목을 지운다.
  HomeConfiguration removeItem(String id) => _withOrderedItems(items.where((item) => item.id != id).toList());

  HomeConfiguration _withOrderedItems(List<HomeItem> ordered) {
    return HomeConfiguration(
      version: version,
      items: [for (var i = 0; i < ordered.length; i++) ordered[i].copyWith(order: i)],
      shortcutWalletContext: shortcutWalletContext,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HomeConfiguration &&
      other.version == version &&
      const ListEquality<HomeItem>().equals(other.items, items) &&
      other.shortcutWalletContext == shortcutWalletContext;

  @override
  int get hashCode => Object.hash(version, Object.hashAll(items), shortcutWalletContext);
}
