import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:equatable/equatable.dart';

enum UtxoFilterType { all, locked, change, tag }

class UtxoFilter extends Equatable {
  final UtxoFilterType type;
  final String? tagId;

  const UtxoFilter._(this.type, [this.tagId]);

  static const all = UtxoFilter._(UtxoFilterType.all);
  static const locked = UtxoFilter._(UtxoFilterType.locked);
  static const change = UtxoFilter._(UtxoFilterType.change);

  const UtxoFilter.tag(String tagId) : this._(UtxoFilterType.tag, tagId);

  bool matches(UtxoState utxo, {List<UtxoTag>? tags}) {
    switch (type) {
      case UtxoFilterType.all:
        return true;
      case UtxoFilterType.locked:
        return utxo.status == UtxoStatus.locked;
      case UtxoFilterType.change:
        return utxo.isChange;
      case UtxoFilterType.tag:
        return (tags ?? utxo.tags)?.any((tag) => tag.id == tagId) ?? false;
    }
  }

  @override
  List<Object?> get props => [type, tagId];
}
