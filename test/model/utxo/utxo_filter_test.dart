import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_filter.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  UtxoState utxo(int index, {String derivationPath = "m/84'/0'/0'/0/0", List<UtxoTag>? tags, UtxoStatus? status}) {
    return UtxoState(
      transactionHash: '00000000000000000000000000000000000000000000000000000000000000a$index',
      index: index,
      amount: 10000,
      derivationPath: derivationPath,
      blockHeight: 100,
      to: 'address$index',
      timestamp: DateTime(2026, 1, 1),
      tags: tags,
      status: status ?? UtxoStatus.unspent,
    );
  }

  group('UtxoFilter', () {
    test('a tag named like a default filter matches only its tagged UTXOs', () {
      final allTag = UtxoTag(id: 'tag-all', walletId: 1, name: t.all, colorIndex: 0);
      final changeTag = UtxoTag(id: 'tag-change', walletId: 1, name: t.change, colorIndex: 1);
      final tagged = utxo(0, tags: [allTag, changeTag]);
      final untagged = utxo(1);
      final change = utxo(2, derivationPath: "m/84'/0'/0'/1/0");

      final utxos = [tagged, untagged, change];
      expect(utxos.where(UtxoFilter.tag(allTag.id).matches), [tagged]);
      expect(utxos.where(UtxoFilter.tag(changeTag.id).matches), [tagged]);
      expect(utxos.where(UtxoFilter.all.matches), utxos);
      expect(utxos.where(UtxoFilter.change.matches), [change]);
    });

    test('tag filter matches by id after the tag is renamed', () {
      const tag = UtxoTag(id: 'tag-1', walletId: 1, name: 'Savings', colorIndex: 0);
      final renamed = tag.copyWith(name: 'Cold');

      expect(UtxoFilter.tag(tag.id).matches(utxo(0, tags: [renamed])), isTrue);
    });

    test('explicit tags override the UTXO tags', () {
      const tag = UtxoTag(id: 'tag-1', walletId: 1, name: 'Savings', colorIndex: 0);

      expect(UtxoFilter.tag(tag.id).matches(utxo(0), tags: [tag]), isTrue);
      expect(UtxoFilter.tag(tag.id).matches(utxo(0, tags: [tag]), tags: []), isFalse);
    });

    test('locked filter matches locked UTXOs only', () {
      final locked = utxo(0, status: UtxoStatus.locked);

      expect([locked, utxo(1)].where(UtxoFilter.locked.matches), [locked]);
    });
  });
}
