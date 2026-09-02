import 'dart:convert';

enum Bip329Type {
  tx('tx'),
  addr('addr'),
  pubkey('pubkey'),
  input('input'),
  output('output'),
  xpub('xpub');

  final String value;
  const Bip329Type(this.value);

  static Bip329Type? fromString(String? value) {
    if (value == null) return null;
    for (final type in Bip329Type.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

class Bip329Record {
  final Bip329Type type;
  final String ref;
  final String? label;
  final String? origin;
  final bool? spendable;
  final int? tagColor;

  const Bip329Record({required this.type, required this.ref, this.label, this.origin, this.spendable, this.tagColor});

  factory Bip329Record.fromJson(Map<String, dynamic> json) {
    final typeString = json['type'] as String?;
    final type = Bip329Type.fromString(typeString);
    if (type == null) {
      throw FormatException('Invalid or missing BIP-329 type: $typeString');
    }

    final ref = json['ref'] as String?;
    if (ref == null || ref.isEmpty) {
      throw const FormatException('Missing or empty BIP-329 ref');
    }

    int? tagColor = json['tag_color'] as int?;
    if (tagColor != null && (tagColor < 0 || tagColor > 11)) {
      tagColor = null;
    }

    return Bip329Record(
      type: type,
      ref: ref,
      label: json['label'] as String?,
      origin: json['origin'] as String?,
      spendable: json['spendable'] as bool?,
      tagColor: tagColor,
    );
  }

  static Bip329Record? tryParseJson(Map<String, dynamic> json) {
    try {
      return Bip329Record.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static Bip329Record? tryParseLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        return tryParseJson(decoded);
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'type': type.value, 'ref': ref};
    if (label != null && label!.isNotEmpty) {
      map['label'] = label;
    }
    if (origin != null && origin!.isNotEmpty) {
      map['origin'] = origin;
    }
    if (spendable != null) {
      map['spendable'] = spendable;
    }
    if (tagColor != null) {
      map['tag_color'] = tagColor;
    }
    return map;
  }

  String toJsonLine() => jsonEncode(toJson());

  @override
  String toString() => toJsonLine();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bip329Record &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          ref == other.ref &&
          label == other.label &&
          origin == other.origin &&
          spendable == other.spendable &&
          tagColor == other.tagColor;

  @override
  int get hashCode => Object.hash(type, ref, label, origin, spendable, tagColor);
}
