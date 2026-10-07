import 'package:collection/collection.dart';

enum HomeItemKind { widget, shortcut }

class HomeGridPosition {
  final int column;
  final int row;

  const HomeGridPosition(this.column, this.row);

  static HomeGridPosition? fromJson(Object? value) {
    if (value is! Map || value['column'] is! int || value['row'] is! int) return null;
    return HomeGridPosition(value['column'] as int, value['row'] as int);
  }

  Map<String, int> toJson() => {'column': column, 'row': row};

  @override
  bool operator ==(Object other) => other is HomeGridPosition && other.column == column && other.row == row;

  @override
  int get hashCode => Object.hash(column, row);

  @override
  String toString() => '($column, $row)';
}

class HomeSpan {
  final int width;
  final int height;

  const HomeSpan(this.width, this.height);

  static const shortcut = HomeSpan(1, 1);
  static const small = HomeSpan(2, 2);
  static const wide = HomeSpan(4, 2);

  static HomeSpan? parse(Object? value) {
    if (value is! String) return null;
    final parts = value.split('x');
    if (parts.length != 2) return null;
    final width = int.tryParse(parts[0]);
    final height = int.tryParse(parts[1]);
    if (width == null || height == null) return null;
    return HomeSpan(width, height);
  }

  String toJson() => '${width}x$height';

  @override
  bool operator ==(Object other) => other is HomeSpan && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => toJson();
}

class HomeItem {
  final String id;
  final String definitionId;
  final HomeItemKind kind;
  final int order;
  final HomeSpan span;
  final HomeGridPosition? position;
  final Map<String, Object?> configuration;

  const HomeItem({
    required this.id,
    required this.definitionId,
    required this.kind,
    required this.order,
    required this.span,
    this.position,
    this.configuration = const {},
  });

  HomeItem copyWith({int? order, HomeSpan? span, HomeGridPosition? position, Map<String, Object?>? configuration}) {
    return HomeItem(
      id: id,
      definitionId: definitionId,
      kind: kind,
      order: order ?? this.order,
      span: span ?? this.span,
      position: position ?? this.position,
      configuration: configuration ?? this.configuration,
    );
  }

  static HomeItem? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final definitionId = json['definitionId'];
    final kind = HomeItemKind.values.firstWhereOrNull((k) => k.name == json['kind']);
    final order = json['order'];
    final span = HomeSpan.parse(json['span']);
    final configuration = json['configuration'];
    if (id is! String || definitionId is! String || kind == null || order is! int || span == null) return null;
    return HomeItem(
      id: id,
      definitionId: definitionId,
      kind: kind,
      order: order,
      span: span,
      position: HomeGridPosition.fromJson(json['position']),
      configuration: configuration is Map ? Map<String, Object?>.from(configuration) : const {},
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'definitionId': definitionId,
    'kind': kind.name,
    'order': order,
    'span': span.toJson(),
    if (position != null) 'position': position!.toJson(),
    'configuration': configuration,
  };

  @override
  bool operator ==(Object other) =>
      other is HomeItem &&
      other.id == id &&
      other.definitionId == definitionId &&
      other.kind == kind &&
      other.order == order &&
      other.span == span &&
      other.position == position &&
      const DeepCollectionEquality().equals(other.configuration, configuration);

  @override
  int get hashCode => Object.hash(id, definitionId, kind, order, span, position);
}
