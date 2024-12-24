import 'package:equatable/equatable.dart';

class UtxoTag extends Equatable {
  final String name;
  final int colorIndex;
  final List<String>? utxoIdList;

  const UtxoTag({
    required this.name,
    required this.colorIndex,
    this.utxoIdList,
  });

  UtxoTag copyWith({
    String? name,
    int? colorIndex,
    List<String>? utxoIdList,
  }) {
    return UtxoTag(
      name: name ?? this.name,
      colorIndex: colorIndex ?? this.colorIndex,
      utxoIdList: utxoIdList ?? this.utxoIdList,
    );
  }

  @override
  List<Object?> get props => [name, colorIndex, utxoIdList];

  @override
  bool? get stringify => true;
}
