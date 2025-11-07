import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/utils/recommended_fee_util.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:flutter/material.dart';

class OnchainDonationInfoViewModel extends ChangeNotifier {
  final WalletProvider _walletProvider;
  final NodeProvider _nodeProvider;
  final SendInfoProvider _sendInfoProvider;
  final List<AvailableDonationWallet> _availableDonationWalletList = [];
  late final int _amount;
  late bool? _isNetworkOn;
  late StreamSubscription<NodeSyncState> _syncNodeStateSubscription;
  late NodeSyncState _nodeSyncState;

  OnchainDonationInfoViewModel(
    this._walletProvider,
    this._nodeProvider,
    this._sendInfoProvider,
    this._isNetworkOn,
    this._amount,
  ) {
    _nodeSyncState = _nodeProvider.state.nodeSyncState;
    _syncNodeStateSubscription = _nodeProvider.syncStateStream.listen(_handleNodeSyncState);
    initialize();
  }

  bool? _isRecommendedFeeFetchSuccess;
  bool _hasShownFeeErrorToast = false;
  bool _hasShownNotEnoughBalanceToast = false;
  int? _selectedIndex;
  bool _isDisposed = false;
  bool prevIsSyncing = false;
  bool _isLoading = false;
  double? satsPerVb;

  int? get selectedIndex => _selectedIndex;
  bool get isNetworkOn => _isNetworkOn == true;
  bool get isSyncCompleted => _nodeSyncState == NodeSyncState.completed;
  bool? get isRecommendedFeeFetchSuccess => _isRecommendedFeeFetchSuccess;
  bool get hasShownFeeErrorToast => _hasShownFeeErrorToast;
  bool get hasShownNotEnoughBalanceToast => _hasShownNotEnoughBalanceToast;
  bool get isLoading => _isLoading;
  List<AvailableDonationWallet> get availableDonationWalletList => _availableDonationWalletList;

  List<WalletListItemBase> get singlesigWalletList =>
      _walletProvider.walletItemList.where((wallet) => wallet.walletType == WalletType.singleSignature).toList();

  initialize() async {
    if (singlesigWalletList.isEmpty) {
      return;
    }
    _sendInfoProvider.setRecipientAddress(CoconutWalletApp.kDonationAddress);
    _isNetworkOn = isNetworkOn;

    RecommendedFee result = await getRecommendedFees(_nodeProvider);
    satsPerVb = result.hourFee.toDouble();

    _availableDonationWalletList.clear(); // 지갑 동기화 완료 후 initialize 호출 시 기존 목록 초기화
    for (var wallet in singlesigWalletList) {
      debugPrint('wallet: $wallet');
      final confirmedBalance = _walletProvider.getWalletBalance(wallet.id).confirmed;
      debugPrint('confirmedBalance: $confirmedBalance');

      try {
        final tx = _createTransaction(satsPerVb!, wallet.id, wallet.walletBase, _amount);
        int estimatedFee = tx.estimateFee(satsPerVb!.toDouble(), wallet.walletBase.addressType);

        final sendingAmount = confirmedBalance - estimatedFee;

        if (sendingAmount >= _amount && sendingAmount > dustLimit) {
          _availableDonationWalletList.add(AvailableDonationWallet(wallet: wallet, estimatedFee: estimatedFee));
        } else {
          debugPrint('Skipping wallet: ${wallet.name}, insufficient sendingAmount: $sendingAmount');
        }
      } catch (error) {
        debugPrint('catch : $wallet, error: $error');

        final message = error.toString();
        final feeMatch = RegExp(r'Not enough amount for sending\. \(Fee : (\d+)\)').firstMatch(message);

        if (feeMatch != null) {
          final fee = int.tryParse(feeMatch.group(1)!);
          final sendingAmount = confirmedBalance - fee!;
          debugPrint('fee: $fee, sendingAmount: $sendingAmount');

          if (confirmedBalance >= _amount && sendingAmount > dustLimit) {
            final tx = Transaction.forSweep(
              _walletProvider.getUtxoListByStatus(wallet.id, UtxoStatus.unspent),
              _sendInfoProvider.recipientAddress!,
              satsPerVb!,
              wallet.walletBase,
            );

            _availableDonationWalletList.add(AvailableDonationWallet(wallet: wallet, estimatedFee: fee));

            debugPrint('Sweep 실행: ${wallet.name}, sendingAmount: $sendingAmount');
          } else {
            debugPrint('Sweep 스킵: ${wallet.name}, dustLimit 보다 낮음');
          }
        }
      }
    }
    if (_availableDonationWalletList.isNotEmpty) {
      debugPrint('_availableDonationWalletList: $_availableDonationWalletList');
      _selectedIndex = 0;
    }
    _isRecommendedFeeFetchSuccess = true;

    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void _handleNodeSyncState(NodeSyncState syncState) {
    // TODO: completed -> syncing
    if (_nodeSyncState != syncState) {
      if (syncState == NodeSyncState.failed) {
        // TODO:
      }
      if (syncState == NodeSyncState.syncing) {
        // TODO:
      }
      if (syncState == NodeSyncState.init) {
        // TODO:
      }
      // 지갑 동기화가 끝났을 때 initialize를 호출하여 지갑 목록 업데이트
      if (syncState == NodeSyncState.completed) {
        initialize();
      }
      _nodeSyncState = syncState;
      notifyListeners();
    }
  }

  int estimateFee(double satsPerVb, int walletId, WalletBase walletBase, int amount) {
    final transaction = _createTransaction(satsPerVb, walletId, walletBase, amount);
    return transaction.estimateFee(satsPerVb, walletBase.addressType); // singlesignature
  }

  Transaction _createTransaction(
    double satsPerVb,
    int walletId,
    WalletBase walletBase,
    int amount, {
    bool isFinal = false,
  }) {
    final utxoPool = _walletProvider.getUtxoListByStatus(walletId, UtxoStatus.unspent);

    final changeAddress = _walletProvider.getChangeAddress(walletId);
    try {
      Transaction tx = Transaction.forSinglePayment(
        TransactionUtil.selectOptimalUtxos(utxoPool, amount, satsPerVb, walletBase.addressType), // singlesignature
        _sendInfoProvider.recipientAddress!,
        changeAddress.derivationPath,
        amount,
        satsPerVb.toDouble(),
        walletBase,
      );

      return tx;
    } catch (e) {
      if (isFinal) {
        final message = e.toString();
        final feeMatch = RegExp(r'Not enough amount for sending\. \(Fee : (\d+)\)').firstMatch(message);

        if (feeMatch != null) {
          final fee = int.tryParse(feeMatch.group(1)!);
          final confirmedBalance = _walletProvider.getWalletBalance(walletId).confirmed;
          final sendingAmount = confirmedBalance - (fee!);

          debugPrint('fee: $fee, sendingAmount: $sendingAmount');

          if (confirmedBalance >= _amount && sendingAmount > dustLimit) {
            return Transaction.forSweep(
              utxoPool,
              _sendInfoProvider.recipientAddress!,
              satsPerVb.toDouble(),
              walletBase,
            );
          }
        }
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _syncNodeStateSubscription.cancel();
    super.dispose();
  }

  void setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
    notifyListeners();
  }

  void setSelectedIndex(int index) {
    if (_availableDonationWalletList.isNotEmpty && index < _availableDonationWalletList.length) {
      _selectedIndex = index;
      notifyListeners();
    }
  }

  void setHasShownFeeErrorToast(bool value) {
    _hasShownFeeErrorToast = value;
  }

  void setHasShownNotEnoughBalanceToast(bool value) {
    _hasShownNotEnoughBalanceToast = value;
  }

  void plusSelectedIndex() {
    if (_availableDonationWalletList.isNotEmpty) {
      _selectedIndex = (_selectedIndex ?? 0) + 1;
      if (_selectedIndex! >= _availableDonationWalletList.length) {
        _selectedIndex = 0;
      }
      notifyListeners();
    }
  }

  void minusSelectedIndex() {
    if (_availableDonationWalletList.isNotEmpty) {
      _selectedIndex = (_selectedIndex ?? 0) - 1;
      if (_selectedIndex! < 0) {
        _selectedIndex = _availableDonationWalletList.length - 1;
      }
      notifyListeners();
    }
  }

  void saveFinalSendInfo() async {
    if (_selectedIndex == null ||
        _availableDonationWalletList.isEmpty ||
        _availableDonationWalletList.length <= _selectedIndex!) {
      return;
    }

    // await finalEstimateFee();

    final walletItem = _availableDonationWalletList[_selectedIndex!];
    final estimatedFee = walletItem.estimatedFee;
    final walletId = walletItem.wallet.id;
    final walletBase = walletItem.wallet.walletBase;
    final walletImportSource = walletItem.wallet.walletImportSource;
    _sendInfoProvider.clear();
    debugPrint(estimatedFee.toString());

    _sendInfoProvider.setWalletId(walletId);
    _sendInfoProvider.setRecipientAddress(CoconutWalletApp.kDonationAddress);
    _sendInfoProvider.setIsDonation(true);
    _sendInfoProvider.setSendEntryPoint(SendEntryPoint.home);
    _sendInfoProvider.setAmount(_amount.toDouble() - estimatedFee.toDouble());
    _sendInfoProvider.setEstimatedFee(estimatedFee);
    _sendInfoProvider.setWalletImportSource(walletImportSource);
    _sendInfoProvider.setIsMultisig(false);
    _sendInfoProvider.setFeeBumpfingType(null);
    _sendInfoProvider.setTransaction(
      _createTransaction(satsPerVb!, walletId, walletBase, _amount - estimatedFee, isFinal: true),
    );
    debugPrint('amount - estimatedFee: ${_amount - estimatedFee}');

    await generateUnsignedPsbt(walletBase).then((value) {
      _sendInfoProvider.setTxWaitingForSign(value);
    });
  }

  Future<String> generateUnsignedPsbt(WalletBase walletBase) async {
    assert(_sendInfoProvider.transaction != null);
    var psbt = Psbt.fromTransaction(_sendInfoProvider.transaction!, walletBase);
    return psbt.serialize();
  }

  void clearSendInfoProvider() {
    _sendInfoProvider.clear();
  }

  void setIsLoading(bool isLoading) {
    _isLoading = isLoading;
    notifyListeners();
  }
}

class AvailableDonationWallet {
  final WalletListItemBase wallet;
  final int estimatedFee;

  AvailableDonationWallet({required this.wallet, required this.estimatedFee});
}
