import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_filter.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/utxo_selection_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
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

class _PreferenceProvider extends Fake implements PreferenceProvider {
  @override
  UtxoOrder get utxoSortOrder => UtxoOrder.byAmountDesc;
}

UtxoState _utxo(int index, int amount, {UtxoStatus status = UtxoStatus.unspent, bool isChange = false}) => UtxoState(
  transactionHash: index.toRadixString(16).padLeft(64, '0'),
  index: 0,
  amount: amount,
  blockHeight: 100,
  to: 'bcrt1qh22yl57ys0vaaln9nfp4zczj2fshjnl6gnsh66',
  derivationPath: "m/84'/1'/0'/${isChange ? 1 : 0}/$index",
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

    test('selectFilteredUtxo는 태그가 붙은 UTXO 중 잠긴 UTXO만 뺀다', () {
      final viewModel = createViewModel();

      viewModel.setSelectedUtxoFilter(UtxoFilter.tag(tag.id));
      viewModel.selectFilteredUtxo();

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

    test('selectFilteredUtxo는 태그가 붙은 UTXO 중 잠긴 UTXO와 1000 sats 미만 UTXO를 뺀다', () {
      final viewModel = createViewModel(minimumSelectableUtxoAmount: 1000);

      viewModel.setSelectedUtxoFilter(UtxoFilter.tag(tag.id));
      viewModel.selectFilteredUtxo();

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

  group('잔돈 필터', () {
    final receive = _utxo(11, 50000);
    final receiveLocked = _utxo(12, 10000, status: UtxoStatus.locked);
    final changeLarge = _utxo(13, 20000, isChange: true);
    final changeSmall = _utxo(14, 600, isChange: true);
    final changeLocked = _utxo(15, 40000, isChange: true, status: UtxoStatus.locked);
    final changeOutgoing = _utxo(16, 70000, isChange: true, status: UtxoStatus.outgoing);

    UtxoSelectionViewModel createChangeViewModel(List<UtxoState> utxos, {int? minimumSelectableUtxoAmount}) {
      final viewModel = UtxoSelectionViewModel(
        _WalletProvider(utxos),
        _UtxoTagProvider({}),
        _PreferenceProvider(),
        true,
        _walletId,
      )..minimumSelectableUtxoAmount = minimumSelectableUtxoAmount;
      viewModel.initialize([]);
      return viewModel;
    }

    final mixed = [receive, receiveLocked, changeLarge, changeSmall, changeLocked, changeOutgoing];

    test('hasChangeUtxo는 목록에 잔돈 UTXO가 있을 때만 true다', () {
      expect(createChangeViewModel(mixed).hasChangeUtxo, isTrue);
      expect(createChangeViewModel([receive, receiveLocked]).hasChangeUtxo, isFalse);
      // 보내는 중인 잔돈은 선택 목록에 나오지 않으므로 잔돈이 없는 것으로 본다
      expect(createChangeViewModel([receive, changeOutgoing]).hasChangeUtxo, isFalse);
    });

    test('잔돈 필터를 켠 화면에서만, 고를 수 있는 잔돈이 있을 때 잔돈 칩과 필터 줄이 보인다', () {
      final enabled = createChangeViewModel(mixed)..isChangeFilterEnabled = true;
      expect(enabled.showChangeFilter, isTrue);
      expect(enabled.isFilterBarVisible, isTrue);

      final disabled = createChangeViewModel(mixed);
      expect(disabled.showChangeFilter, isFalse);
      expect(disabled.isFilterBarVisible, isFalse);

      final noChange = createChangeViewModel([receive, changeLocked])..isChangeFilterEnabled = true;
      expect(noChange.showChangeFilter, isFalse);
      expect(noChange.isFilterBarVisible, isFalse);
    });

    test('태그가 있으면 잔돈 필터가 꺼져 있어도 필터 줄이 보인다', () {
      final viewModel = createViewModel();
      expect(viewModel.showChangeFilter, isFalse);
      expect(viewModel.isFilterBarVisible, isTrue);
    });

    test('고를 수 있는 잔돈이 없으면 hasChangeUtxo는 false다', () {
      expect(createChangeViewModel([receive, changeLocked]).hasChangeUtxo, isFalse);
      expect(createChangeViewModel([receive, changeSmall], minimumSelectableUtxoAmount: 1000).hasChangeUtxo, isFalse);
    });

    test('잔돈 필터에서 전체 선택해도 필터 밖에서 고른 UTXO는 남는다', () {
      final viewModel = createChangeViewModel(mixed);

      viewModel.toggleUtxoSelection(receive);
      viewModel.setSelectedUtxoFilter(UtxoFilter.change);
      viewModel.selectFilteredUtxo();

      expect(ids(viewModel.selectedUtxoList), ids([receive, changeLarge, changeSmall]));
      expectConsistent(viewModel);
    });

    test('잔돈 필터에서 전체 해제하면 보이는 잔돈만 풀리고 필터 밖 선택은 남는다', () {
      final viewModel = createChangeViewModel(mixed);

      viewModel.toggleUtxoSelection(receive);
      viewModel.toggleUtxoSelection(changeLarge);
      viewModel.setSelectedUtxoFilter(UtxoFilter.change);
      viewModel.deselectFilteredUtxo();

      expect(ids(viewModel.selectedUtxoList), ids([receive]));
      expectConsistent(viewModel);
    });

    test('다시 읽을 때 고를 수 있는 잔돈이 없으면 잔돈 필터는 전체로 돌아간다', () {
      final utxos = List<UtxoState>.of(mixed);
      final viewModel = UtxoSelectionViewModel(
        _WalletProvider(utxos),
        _UtxoTagProvider({}),
        _PreferenceProvider(),
        true,
        _walletId,
      )..initialize([]);

      viewModel.setSelectedUtxoFilter(UtxoFilter.change);
      utxos.removeWhere((utxo) => utxo == changeLarge || utxo == changeSmall);
      viewModel.reload([]);

      expect(viewModel.hasChangeUtxo, isFalse);
      expect(viewModel.selectedUtxoFilter, UtxoFilter.all);
      expect(ids(viewModel.filteredUtxoList), ids([receive, receiveLocked, changeLocked]));
    });

    test('잔돈 필터를 고르면 잔돈 주소의 UTXO만 남고, 잠긴 잔돈은 뒤에 온다', () {
      final viewModel = createChangeViewModel(mixed);

      viewModel.setSelectedUtxoFilter(UtxoFilter.change);

      expect(viewModel.filteredUtxoList, [changeLarge, changeSmall, changeLocked]);
      expect(viewModel.filteredUtxoList.every((utxo) => utxo.isChange), isTrue);
    });

    test('잔돈 필터에서 전체 선택하면 잠기지 않은 잔돈 UTXO만 선택된다', () {
      final viewModel = createChangeViewModel(mixed);

      viewModel.setSelectedUtxoFilter(UtxoFilter.change);
      viewModel.selectFilteredUtxo();

      expect(ids(viewModel.selectedUtxoList), ids([changeLarge, changeSmall]));
      expect(viewModel.selectedUtxoAmountSum, 20600);
      expectConsistent(viewModel);
    });

    test('최소 금액이 1000이면 잔돈 필터의 전체 선택에서 1000 sats 미만 잔돈을 뺀다', () {
      final viewModel = createChangeViewModel(mixed, minimumSelectableUtxoAmount: 1000);

      viewModel.setSelectedUtxoFilter(UtxoFilter.change);
      viewModel.selectFilteredUtxo();

      expect(ids(viewModel.selectedUtxoList), ids([changeLarge]));
      expectConsistent(viewModel);
    });

    test('잔돈 필터를 바꿔도 이미 선택한 UTXO는 유지되고, 전체로 돌아오면 모두 다시 보인다', () {
      final viewModel = createChangeViewModel(mixed);

      viewModel.toggleUtxoSelection(receive);
      viewModel.setSelectedUtxoFilter(UtxoFilter.change);
      expect(ids(viewModel.selectedUtxoList), ids([receive]));

      viewModel.setSelectedUtxoFilter(UtxoFilter.all);
      expect(ids(viewModel.filteredUtxoList), ids([receive, receiveLocked, changeLarge, changeSmall, changeLocked]));
      expectConsistent(viewModel);
    });
  });
}
