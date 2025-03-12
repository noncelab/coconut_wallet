import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/fee_bumping/fee_bumping_view_model.dart';
import 'package:coconut_wallet/utils/derivation_path_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';

class RbfViewModel extends FeeBumpingViewModel {
  int get recommendFeeRate => _getRecommendFeeRate();
  RbfViewModel(
    super._transaction,
    super._walletId,
    super._nodeProvider,
    super._sendInfoProvider,
    super._walletProvider,
    super._currentUtxo,
    super._addressRepository,
  ) {
    Logger.log('RbfViewModel created');
  }

  int _getRecommendFeeRate() {
    return transaction.feeRate < (feeInfos[2].satsPerVb ?? 0)
        ? (feeInfos[2].satsPerVb ?? 0)
        : (feeInfos[2].satsPerVb ?? 0) + 1;
  }

  @override
  int getTotalEstimatedFee(int newFeeRate) {
    return (transaction.vSize * newFeeRate).ceil();
  }

  @override
  void setRecommendFeeRate() {}

  @override
  void updateSendInfoProvider(int newTxFeeRate) {
    super.updateSendInfoProvider(newTxFeeRate);
    sendInfoProvider.setAmount(transaction.amount!.toDouble());
  }

  List<Utxo> convertInputAddressesToUtxos(
      List<TransactionAddress> inputAddressList, String txHash, int walletId) {
    List<Utxo> utxoList = [];

    for (var transactionAddress in inputAddressList) {
      var derivationPath = addressRepository.getDerivationPath(
          walletId, transactionAddress.address);

      Utxo utxo = Utxo(
        txHash,
        inputAddressList.indexOf(transactionAddress),
        transactionAddress.amount,
        derivationPath,
      );

      utxoList.add(utxo);
    }

    return utxoList;
  }

  Future<String> generateUnsignedPsbt() async {
    String recipientAddress = '';
    String changeAddress = transaction.outputAddressList
        .map((e) => e.address)
        .firstWhere(
            (address) => walletProvider.containsAddress(walletId, address));
    int amount = 0;

    if (transaction.transactionType != 'SELF') {
      recipientAddress = transaction.outputAddressList
          .map((e) => e.address)
          .firstWhere(
              (address) => !walletProvider.containsAddress(walletId, address));
      amount = transaction.outputAddressList
          .firstWhere((output) => output.address == recipientAddress)
          .amount;
    } else {
      List<TransactionAddress> selfOutputAddressList = transaction
          .outputAddressList
          .where((address) =>
              walletProvider.containsAddress(walletId, address.address))
          .toList();
      for (var address in selfOutputAddressList) {
        bool isChangeAddress = DerivationPathUtil.isChangeAddress(
            addressRepository.getDerivationPath(walletId, address.address));
        if (isChangeAddress) {
          changeAddress = address.address;
        } else {
          recipientAddress = address.address;
          amount = address.amount;
        }
      }
    }

    int satsPerVb = sendInfoProvider.feeRate!;

    WalletBase wallet = walletListItemBase.walletBase;

    Transaction generateTx;
    List<Utxo> inputUtxoList = convertInputAddressesToUtxos(
        transaction.inputAddressList, transaction.transactionHash, walletId);

    debugPrint('''
  ========================== RBF Transaction Info =========================
  Transaction Type    : ${getTransactionType()}
  Transaction Hash    : ${transaction.transactionHash}
  Input Count        : ${transaction.inputAddressList.length}
  Output Count       : ${transaction.outputAddressList.length}
  Recipient Address  : $recipientAddress
  Change Address     : $changeAddress
  Amount             : $amount sats
  Fee Rate           : $satsPerVb sats/vb
  Wallet Type        : ${wallet.runtimeType}
  ------------------------------------------------------------------------
  Input UTXOs:
  ${inputUtxoList.map((utxo) => '  - TX Hash: ${utxo.transactionHash}, Index: ${utxo.index}, Amount: ${utxo.amount} sats').join('\n')}
  ------------------------------------------------------------------------
  Output Addresses:
  ${transaction.outputAddressList.map((addr) => '  - ${addr.address}: ${addr.amount} sats').join('\n')}
  =========================================================================
  ''');
    //                            목적        |           Input          |      output
    // forSinglePayment  특정 금액을 1명에게 송금 |  사용자가 선택한 최소한의 UTXO  | 수취인주소(1) + 잔돈주소(1) => 2
    // forSweep          모든 잔액을 한번에 송금  |     지갑 내 모든 UTXO       | 수취인주소(1) (잔돈x) => 1
    // forBatchPayment      여러명에게 송금     |      사용자가 선택한 UTXO     | 수취인주소(2개이상) + 잔돈주소(1) => 최소 3개 이상
    switch (getTransactionType()) {
      case TransactionType.forSweep:
        {
          debugPrint('### Original TransactionType: forSweep');
          generateTx = Transaction.forSweep(
              inputUtxoList, recipientAddress, satsPerVb, wallet);
          break;
        }
      case TransactionType.forSinglePayment:
        {
          debugPrint('### Original TransactionType: forSinglePayment');

          generateTx = Transaction.forSinglePayment(inputUtxoList,
              recipientAddress, changeAddress, amount, satsPerVb, wallet);
          break;
        }
      case TransactionType.forBatchPayment:
        {
          debugPrint('### Original TransactionType: forBatchPayment');

          Map<String, int> paymentMap =
              createPaymentMap(transaction.outputAddressList);

          generateTx = Transaction.forBatchPayment(
              inputUtxoList, paymentMap, changeAddress, satsPerVb, wallet);
          break;
        }
      default:
        throw ('Invalid TransactionType');
    }

    debugPrint('''
========== RBF Transaction Info ==========
- Input Addresses: 
  ${transaction.inputAddressList.map((e) => e.address).join('\n  ')}
--------------------------------------------
- Output Addresses: 
  ${transaction.outputAddressList.map((e) => e.address).join('\n  ')}
--------------------------------------------
- Transaction vSize: ${transaction.vSize} vB
============================================
''');
    debugPrint('''
========== Generated Transaction Info ==========
- transactionHash: ${generateTx.transactionHash}
- changeAddress: ${generateTx.changeAddress}
- paymentMap: ${generateTx.paymentMap.entries.toString()}
- totalInputAmount: ${generateTx.totalInputAmount}
--------------------------------------------
- Inputs: 
  ${generateTx.inputs}
- totalInputAmount: ${generateTx.totalInputAmount}
--------------------------------------------
- Outputs: 
  ${generateTx.outputs}
- totalSendingAmount: ${generateTx.totalSendingAmount}
''');

    return Psbt.fromTransaction(generateTx, walletListItemBase.walletBase)
        .serialize();
  }

  Map<String, int> createPaymentMap(
      List<TransactionAddress> outputAddressList) {
    Map<String, int> paymentMap = {};

    for (TransactionAddress addressInfo in outputAddressList) {
      paymentMap[addressInfo.address] = addressInfo.amount;
    }

    return paymentMap;
  }

  @override
  void initializeGenerateTx() {}
}
