import 'dart:ui';

import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/wallet/transaction_draft.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/broadcasting_view_model.dart';
import 'package:coconut_wallet/providers/view_model/send/send_view_model.dart';
import 'package:coconut_wallet/providers/view_model/transaction_draft/transaction_draft_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

class _Wallet extends Fake implements WalletItemBase {
  @override
  final int id;
  @override
  bool hasLocalKey;
  _Wallet(this.id, {this.hasLocalKey = false});
}

class _WalletProvider extends Fake implements WalletProvider {
  @override
  final List<WalletItemBase> walletItemList;
  _WalletProvider(this.walletItemList);
  @override
  WalletItemBase getWalletById(int id) => walletItemList.firstWhere((wallet) => wallet.id == id);
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

class _Preferences extends Fake implements PreferenceProvider {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.sats;
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

class _DraftRepository extends Fake implements TransactionDraftRepository {
  final List<TransactionDraft> unsigned;
  final List<TransactionDraft> signed;
  _DraftRepository({this.unsigned = const [], this.signed = const []});
  @override
  List<TransactionDraft> getAllUnsignedDrafts() => unsigned;
  @override
  Future<List<TransactionDraft>> getAllSignedDrafts() async => signed;
  @override
  TransactionDraft? getUnsignedTransactionDraft(int id) => unsigned.firstWhere((draft) => draft.id == id);
  @override
  Future<Result<TransactionDraft>> getSignedDraft(int id) async =>
      Result.success(signed.firstWhere((draft) => draft.id == id));
}

class _Utxos extends Fake implements UtxoRepository {}

class _Tags extends Fake implements UtxoTagProvider {}

class _Node extends Fake implements NodeProvider {}

class _Transactions extends Fake implements TransactionProvider {}

class _SendViewModel extends SendViewModel {
  final WalletItemBase? wallet;
  _SendViewModel(this.wallet, _WalletProvider wallets, _DraftRepository drafts)
    : super(
        wallets,
        SendInfoProvider(),
        _Preferences(),
        drafts,
        _Utxos(),
        true,
        (_) {},
        (_) {},
        (_) {},
        null,
        SendEntryPoint.home,
        null,
        [],
      );
  @override
  WalletItemBase? get selectedWalletItem => wallet;
}

TransactionDraft _draft(int id, int walletId, {bool signed = false}) => TransactionDraft(
  id: id,
  walletId: walletId,
  createdAt: DateTime(2026),
  recipients: [],
  feeRate: 1,
  isMaxMode: false,
  txWaitingForSign: signed ? 'unsigned transaction' : null,
  signedPsbtBase64Encoded: signed ? 'signed transaction' : null,
);

void main() {
  test('hot wallet cannot save, update, or load an unsigned draft', () async {
    final hot = _Wallet(1, hasLocalKey: true);
    final vm = _SendViewModel(hot, _WalletProvider([hot]), _DraftRepository(unsigned: [_draft(1, 1)]));
    addTearDown(vm.dispose);
    expect(vm.canUseTransactionDrafts, false);
    await expectLater(vm.saveNewDraft(), throwsStateError);
    await expectLater(vm.updateDraft(), throwsStateError);
    expect(() => vm.loadTransactionDraft(1), throwsStateError);
  });

  test('watch-only wallet retains draft availability; no wallet disables it', () {
    final cold = _Wallet(1);
    final vm = _SendViewModel(cold, _WalletProvider([cold]), _DraftRepository());
    final empty = _SendViewModel(null, _WalletProvider([]), _DraftRepository());
    addTearDown(vm.dispose);
    addTearDown(empty.dispose);
    expect(vm.canUseTransactionDrafts, true);
    expect(empty.canUseTransactionDrafts, false);
  });

  test('draft lists exclude hot wallets and retain watch-only and deleted wallet entries', () async {
    final hot = _Wallet(1, hasLocalKey: true);
    final cold = _Wallet(2);
    final repo = _DraftRepository(
      unsigned: [_draft(1, 1), _draft(2, 2), _draft(3, 3)],
      signed: [_draft(4, 1, signed: true), _draft(5, 2, signed: true)],
    );
    final vm = TransactionDraftViewModel(repo, _WalletProvider([hot, cold]));
    addTearDown(vm.dispose);
    await vm.initializeDraftList();
    expect(vm.unsignedTransactionDraftList.map((draft) => draft.id), [2, 3]);
    expect(vm.signedTransactionDraftList.map((draft) => draft.id), [5]);
    expect(repo.unsigned, hasLength(3));
    cold.hasLocalKey = true;
    expect(vm.unsignedTransactionDraftList.map((draft) => draft.id), [3]);
    expect(vm.signedTransactionDraftList, isEmpty);
  });

  test('hot wallet cannot save or reopen a signed draft', () async {
    final hot = _Wallet(1, hasLocalKey: true);
    final info = SendInfoProvider()..setWalletId(hot.id);
    final vm = BroadcastingViewModel(
      info,
      _WalletProvider([hot]),
      _Tags(),
      true,
      _Node(),
      _Transactions(),
      _DraftRepository(signed: [_draft(1, 1, signed: true)]),
      _Utxos(),
      1,
    );
    expect(vm.canUseTransactionDrafts, false);
    await expectLater(vm.saveTransactionDraft(), throwsStateError);
    await expectLater(vm.setTxInfo(), throwsStateError);
    expect(info.walletId, hot.id);
  });

  test('watch-only wallet retains signed draft availability', () {
    final cold = _Wallet(1);
    final vm = BroadcastingViewModel(
      SendInfoProvider()..setWalletId(1),
      _WalletProvider([cold]),
      _Tags(),
      true,
      _Node(),
      _Transactions(),
      _DraftRepository(),
      _Utxos(),
      null,
    );
    expect(vm.canUseTransactionDrafts, true);
  });
}
