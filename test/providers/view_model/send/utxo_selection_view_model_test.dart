import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/utxo_selection_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const int _walletId = 1;
const String _tagName = 'cold';

class _WalletProvider extends Fake implements WalletProvider {
  final List<UtxoState> utxos;

  _WalletProvider(this.utxos);

  @override
  List<UtxoState> getUtxoList(int walletId) => utxos;
}

class _UtxoTagProvider extends Fake implements UtxoTagProvider {
  final Map<String, List<UtxoTag>> tagsByUtxoId;

  _UtxoTagProvider(this.tagsByUtxoId);

  @override
  List<UtxoTag> getUtxoTagsByUtxoId(int walletId, String utxoId) => tagsByUtxoId[utxoId] ?? [];

  @override
  List<UtxoTag> getUtxoTagList(int walletId) => tagsByUtxoId.values.expand((tags) => tags).toSet().toList();
}

class _PriceProvider extends Fake implements PriceProvider {
  @override
  int? get bitcoinPriceKrw => null;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class _PreferenceProvider extends Fake implements PreferenceProvider {
  @override
  UtxoOrder get utxoSortOrder => UtxoOrder.byAmountDesc;
}

UtxoState _utxo(int index, int amount, {UtxoStatus status = UtxoStatus.unspent}) => UtxoState(
  transactionHash: index.toRadixString(16).padLeft(64, '0'),
  index: 0,
  amount: amount,
  blockHeight: 100,
  to: 'bcrt1qh22yl57ys0vaaln9nfp4zczj2fshjnl6gnsh66',
  derivationPath: "m/84'/1'/0'/0/$index",
  timestamp: DateTime(2026, 1, 1).add(Duration(minutes: index)),
  status: status,
);

void main() {
  final large = _utxo(1, 50000);
  final atMinimum = _utxo(2, 1000);
  final belowMinimum = _utxo(3, 999);
  final locked = _utxo(4, 30000, status: UtxoStatus.locked);
  final taggedLarge = _utxo(5, 20000);
  final taggedSmall = _utxo(6, 600);
  final taggedLocked = _utxo(7, 40000, status: UtxoStatus.locked);
  final outgoing = _utxo(8, 70000, status: UtxoStatus.outgoing);

  const tag = UtxoTag(id: 'tag-1', walletId: _walletId, name: _tagName, colorIndex: 0);

  UtxoSelectionViewModel createViewModel({int? minimumSelectableUtxoAmount}) {
    final viewModel = UtxoSelectionViewModel(
      _WalletProvider([large, atMinimum, belowMinimum, locked, taggedLarge, taggedSmall, taggedLocked, outgoing]),
      _UtxoTagProvider({
        taggedLarge.utxoId: [tag],
        taggedSmall.utxoId: [tag],
        taggedLocked.utxoId: [tag],
      }),
      _PriceProvider(),
      _PreferenceProvider(),
      true,
      _walletId,
    )..minimumSelectableUtxoAmount = minimumSelectableUtxoAmount;
    viewModel.initialize([]);
    return viewModel;
  }

  Set<String> ids(Iterable<UtxoState> utxos) => utxos.map((utxo) => utxo.utxoId).toSet();

  void expectConsistent(UtxoSelectionViewModel viewModel) {
    expect(viewModel.selectedUtxoIdSet, ids(viewModel.selectedUtxoList));
    expect(viewModel.selectedUtxoIdSet.length, viewModel.selectedUtxoList.length);
    expect(viewModel.selectedUtxoAmountSum, viewModel.selectedUtxoList.fold<int>(0, (sum, utxo) => sum + utxo.amount));
  }

  group('minimumSelectableUtxoAmount가 null일 때 (송금)', () {
    test('selectAllUtxo는 잠긴 UTXO만 빼고 소액 UTXO까지 모두 선택한다', () {
      final viewModel = createViewModel();

      viewModel.selectAllUtxo();

      expect(ids(viewModel.selectedUtxoList), ids([large, atMinimum, belowMinimum, taggedLarge, taggedSmall]));
      expectConsistent(viewModel);
    });

    test('selectTaggedUtxo는 태그가 붙은 UTXO 중 잠긴 UTXO만 뺀다', () {
      final viewModel = createViewModel();

      viewModel.setSelectedUtxoTagName(_tagName);
      viewModel.selectTaggedUtxo(_tagName);

      expect(ids(viewModel.selectedUtxoList), ids([taggedLarge, taggedSmall]));
      expectConsistent(viewModel);
    });

    test('isBelowMinimumSelectableAmount는 항상 false다', () {
      final viewModel = createViewModel();

      expect(viewModel.isBelowMinimumSelectableAmount(taggedSmall), isFalse);
    });
  });

  group('minimumSelectableUtxoAmount가 1000일 때 (나누기)', () {
    test('selectAllUtxo는 잠긴 UTXO와 1000 sats 미만 UTXO를 뺀다', () {
      final viewModel = createViewModel(minimumSelectableUtxoAmount: 1000);

      viewModel.selectAllUtxo();

      expect(ids(viewModel.selectedUtxoList), ids([large, atMinimum, taggedLarge]));
      expectConsistent(viewModel);
    });

    test('selectTaggedUtxo는 태그가 붙은 UTXO 중 잠긴 UTXO와 1000 sats 미만 UTXO를 뺀다', () {
      final viewModel = createViewModel(minimumSelectableUtxoAmount: 1000);

      viewModel.setSelectedUtxoTagName(_tagName);
      viewModel.selectTaggedUtxo(_tagName);

      expect(ids(viewModel.selectedUtxoList), ids([taggedLarge]));
      expectConsistent(viewModel);
    });

    test('999 sats는 최소 금액 미만, 1000 sats는 선택 가능하다', () {
      final viewModel = createViewModel(minimumSelectableUtxoAmount: 1000);

      expect(viewModel.isBelowMinimumSelectableAmount(belowMinimum), isTrue);
      expect(viewModel.isBelowMinimumSelectableAmount(atMinimum), isFalse);
    });
  });

  group('개별 토글', () {
    test('여러 UTXO를 토글하면 합계와 ID 집합이 선택 목록과 일치한다', () {
      final viewModel = createViewModel(minimumSelectableUtxoAmount: 1000);

      viewModel.toggleUtxoSelection(large);
      viewModel.toggleUtxoSelection(atMinimum);
      viewModel.toggleUtxoSelection(taggedLarge);
      expect(viewModel.selectedUtxoAmountSum, 71000);
      expectConsistent(viewModel);

      viewModel.toggleUtxoSelection(atMinimum);
      expect(ids(viewModel.selectedUtxoList), ids([large, taggedLarge]));
      expect(viewModel.selectedUtxoAmountSum, 70000);
      expectConsistent(viewModel);
    });

    test('전체 선택 후 토글로 하나를 빼고 전체 해제하면 비어 있다', () {
      final viewModel = createViewModel();

      viewModel.selectAllUtxo();
      viewModel.toggleUtxoSelection(large);
      expect(viewModel.selectedUtxoIdSet.contains(large.utxoId), isFalse);
      expectConsistent(viewModel);

      viewModel.deselectAllUtxo();
      expect(viewModel.selectedUtxoList, isEmpty);
      expect(viewModel.selectedUtxoAmountSum, 0);
      expectConsistent(viewModel);
    });
  });
}
