import 'package:equatable/equatable.dart';

class UtxoTag extends Equatable {
  final String id;
  final int walletId;
  final String name;
  final int colorIndex;
  final List<String>? utxoIdList;

  const UtxoTag({
    required this.id,
    required this.walletId,
    required this.name,
    required this.colorIndex,
    this.utxoIdList,
  });

  UtxoTag copyWith({String? name, int? colorIndex, int? walletId, List<String>? utxoIdList}) {
    return UtxoTag(
      id: id,
      walletId: walletId ?? this.walletId,
      name: name ?? this.name,
      colorIndex: colorIndex ?? this.colorIndex,
      utxoIdList: utxoIdList ?? this.utxoIdList,
    );
  }

  @override
  List<Object?> get props => [id, name, colorIndex, utxoIdList];

  @override
  bool? get stringify => true;
}
