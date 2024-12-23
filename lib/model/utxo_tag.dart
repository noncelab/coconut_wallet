import 'package:equatable/equatable.dart';

class UtxoTag extends Equatable {
  final String tag;
  final int colorIndex;
  final int usedCount;

  const UtxoTag({
    required this.tag,
    required this.colorIndex,
    this.usedCount = 0,
  });

  UtxoTag copyWith({
    String? tag,
    int? colorIndex,
    int? usedCount,
  }) {
    return UtxoTag(
      tag: tag ?? this.tag,
      colorIndex: colorIndex ?? this.colorIndex,
      usedCount: usedCount ?? this.usedCount,
    );
  }

  @override
  List<Object?> get props => [tag, colorIndex, usedCount];

  @override
  bool? get stringify => true;
}
