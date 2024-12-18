import 'package:equatable/equatable.dart';

class UtxoTag extends Equatable {
  final String tag;
  final int colorIndex;

  const UtxoTag({
    required this.tag,
    required this.colorIndex,
  });

  UtxoTag copyWith({
    String? tag,
    int? colorIndex,
  }) {
    return UtxoTag(
      tag: tag ?? this.tag,
      colorIndex: colorIndex ?? this.colorIndex,
    );
  }

  @override
  List<Object?> get props => [tag, colorIndex];

  @override
  bool? get stringify => true;
}
