import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:flutter/material.dart';

class OnchainDonationInfoViewModel extends ChangeNotifier {
  final WalletProvider _walletProvider;
  final NodeProvider _nodeProvider;
  final SendInfoProvider _sendInfoProvider;
  final List<AvailableDonationWallet> _availableDonationWalletList = [];
  late int? _bitcoinPriceKrw;
  late final int _amount;
  late bool? _isNetworkOn;

  OnchainDonationInfoViewModel(this._walletProvider, this._nodeProvider, this._sendInfoProvider,
      this._bitcoinPriceKrw, this._isNetworkOn, this._amount) {
    initialize();
  }

  bool? _isRecommendedFeeFetchSuccess;
  bool _hasShownFeeErrorToast = false;
  bool _hasShownNotEnoughBalanceToast = false;
  int? _selectedIndex;
  bool _isDisposed = false;
  bool prevIsSyncing = false;
  int? satsPerVb;

  int? get bitcoinPriceKrw => _bitcoinPriceKrw;
  int? get selectedIndex => _selectedIndex;
  bool get isNetworkOn => _isNetworkOn == true;
  bool get isSyncing => _walletProvider.isSyncing;
  bool? get isRecommendedFeeFetchSuccess => _isRecommendedFeeFetchSuccess;
  bool get hasShownFeeErrorToast => _hasShownFeeErrorToast;
  bool get hasShownNotEnoughBalanceToast => _hasShownNotEnoughBalanceToast;
  List<AvailableDonationWallet> get availableDonationWalletList => _availableDonationWalletList;

  List<WalletListItemBase> get singlesigWalletList => _walletProvider.walletItemList
      .where((wallet) => wallet.walletType == WalletType.singleSignature)
      .toList();

  initialize() async {
    _bitcoinPriceKrw = _bitcoinPriceKrw;
    _isNetworkOn = isNetworkOn;

    var result = await _nodeProvider.getRecommendedFees().timeout(
      const Duration(seconds: 10), // 타임아웃 초
      onTimeout: () {
        return Result.failure(
            const AppError('NodeProvider', 'TimeoutException: Isolate response timeout'));
      },
    );

    if (result.isFailure) {
      _isRecommendedFeeFetchSuccess = false;
      return;
    }

    satsPerVb = result.value.hourFee;

    for (var wallet in singlesigWalletList) {
      debugPrint('wallet: $wallet');
      final confirmedBalance = _walletProvider.getWalletBalance(wallet.id).confirmed;
      try {
        int estimatedFee = estimateFee(satsPerVb!, wallet.id, wallet.walletBase);
        // 현재 사용 가능 잔액 - 수수료 > 더스트인 경우 리스트에 추가
        if (confirmedBalance - estimatedFee > dustLimit) {
          _availableDonationWalletList.add(AvailableDonationWallet(
            wallet: wallet,
            estimatedFee: estimatedFee,
          ));
        }
      } catch (error) {
        debugPrint('catch : $wallet, error: $error');

        continue;
      }
    }
    if (_availableDonationWalletList.isNotEmpty) {
      _selectedIndex = 0;
    }
    _isRecommendedFeeFetchSuccess = true;

    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
    notifyListeners();
  }

  void setBitcoinPriceKrw(int price) {
    _bitcoinPriceKrw = price;
    notifyListeners();
  }

  int estimateFee(int satsPerVb, int walletId, WalletBase walletBase) {
    final transaction = _createTransaction(satsPerVb, walletId, walletBase);

    return transaction.estimateFee(satsPerVb.toDouble(), AddressType.p2wpkh); // singlesignature
  }

  Transaction _createTransaction(int satsPerVb, int walletId, WalletBase walletBase) {
    final utxoPool = _walletProvider.getUtxoListByStatus(walletId, UtxoStatus.unspent);

    final changeAddress = _walletProvider.getChangeAddress(walletId);
    return Transaction.forSinglePayment(
      TransactionUtil.selectOptimalUtxos(
          utxoPool, _amount, satsPerVb, AddressType.p2wpkh), // singlesignature
      CoconutWalletApp.kDonationAddress,
      changeAddress.derivationPath,
      _amount,
      satsPerVb.toDouble(),
      walletBase,
    );
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
        _availableDonationWalletList.length <= _selectedIndex! ||
        satsPerVb == null) {
      return;
    }

    final walletItem = _availableDonationWalletList[_selectedIndex!];
    final estimatedFee = walletItem.estimatedFee;
    final walletId = walletItem.wallet.id;
    final walletBase = walletItem.wallet.walletBase;
    final walletImportSource = walletItem.wallet.walletImportSource;
    _sendInfoProvider.clear();

    _sendInfoProvider.setWalletId(walletId);
    _sendInfoProvider.setIsDonation(true);
    _sendInfoProvider.setAmount(_amount.toDouble());
    _sendInfoProvider.setEstimatedFee(estimatedFee);
    _sendInfoProvider.setWalletImportSource(walletImportSource);
    _sendInfoProvider.setIsMultisig(false);
    _sendInfoProvider.setFeeBumpfingType(null);
    _sendInfoProvider.setTransaction(_createTransaction(satsPerVb!, walletId, walletBase));

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
}

class AvailableDonationWallet {
  final WalletListItemBase wallet;
  final int estimatedFee;

  AvailableDonationWallet({
    required this.wallet,
    required this.estimatedFee,
  });
}
