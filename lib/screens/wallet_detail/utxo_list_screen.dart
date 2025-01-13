import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/app/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/model/app/utxo/utxo.dart' as model;
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:provider/provider.dart';

@Deprecated("UtxoListScreen 삭제")
class UtxoListScreen extends StatefulWidget {
  final int id;

  const UtxoListScreen({super.key, required this.id});

  @override
  State<UtxoListScreen> createState() => _UtxoListScreenState();
}

class _UtxoListScreenState extends State<UtxoListScreen> {
  static String changeField = 'change';
  static String accountIndexField = 'accountIndex';

  int _current = 0; // for ordering
  late int? _balance;
  late List<model.UTXO> _utxoList;
  late WalletListItemBase _walletBaseItem;
  late WalletType _walletType;

  @override
  void initState() {
    super.initState();
    final model = Provider.of<AppStateModel>(context, listen: false);
    _walletBaseItem = model.getWalletById(widget.id);
    _balance = _walletBaseItem.balance;
    _walletType = _walletBaseItem.walletType;

    if (_walletBaseItem.walletType == WalletType.multiSignature) {
      final multisigWallet = _walletBaseItem.walletBase as MultisignatureWallet;
      _utxoList = getUtxoListWithHoldingAddress(multisigWallet.getUtxoList());
    } else {
      final singlesigWallet =
          _walletBaseItem.walletBase as SingleSignatureWallet;
      _utxoList = getUtxoListWithHoldingAddress(singlesigWallet.getUtxoList());
    }
  }

  Map<String, int> getChangeAndAccountElements(String derivationPath) {
    var pathElements = derivationPath.split('/');
    Map<String, int> result;

    switch (_walletType) {
      // m / purpose' / coin_type' / account' / change / address_index
      case WalletType.singleSignature:
        result = {
          changeField: int.parse(pathElements[4]),
          accountIndexField: int.parse(pathElements[5])
        };
        break;
      // m / purpose' / coin_type' / account' / script_type' / change / address_index
      case WalletType.multiSignature:
        result = {
          changeField: int.parse(pathElements[5]),
          accountIndexField: int.parse(pathElements[6])
        };
        break;
      default:
        throw ArgumentError("wrong walletType: $_walletType");
    }

    return result;
  }

  List<model.UTXO> getUtxoListWithHoldingAddress(List<UTXO> utxoEntities) {
    List<model.UTXO> utxos = [];
    for (var element in utxoEntities) {
      Map<String, int> changeAndAccountIndex =
          getChangeAndAccountElements(element.derivationPath);

      String ownedAddress = _walletBaseItem.walletBase.getAddress(
          changeAndAccountIndex[accountIndexField]!,
          isChange: changeAndAccountIndex[changeField]! == 1);

      utxos.add(model.UTXO(
        element.timestamp.toString(),
        element.blockHeight.toString(),
        element.amount,
        ownedAddress,
        element.derivationPath,
        element.transactionHash,
        element.index,
      ));
    }
    return utxos;
  }

  @override
  Widget build(BuildContext context) {
    List<model.UTXO> sortedUTXOs =
        _current == 0 ? sortByAmount(_utxoList) : sortByTimestamp(_utxoList);

    return Scaffold(
        backgroundColor: MyColors.black,
        appBar: CustomAppBar.build(
            title: '잔액 상세', context: context, hasRightIcon: false),
        body: Selector<UpbitConnectModel, int?>(
            selector: (context, model) => model.bitcoinPriceKrw,
            builder: (context, bitcointPriceKrw, child) {
              return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '총 잔액',
                          style: Styles.body1,
                        ),
                        RichText(
                            text: TextSpan(
                                text: _balance == null
                                    ? '잔액 조회 실패'
                                    : satoshiToBitcoinString(_balance!),
                                style: Styles.h1Number,
                                children: <TextSpan>[
                              TextSpan(
                                  text: _balance == null ? '' : ' BTC',
                                  style: Styles.unit)
                            ])),
                        Text(
                          _balance != null && bitcointPriceKrw != null
                              ? '${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(_balance!, bitcointPriceKrw).toDouble())} ${CurrencyCode.KRW.code}'
                              : '',
                          style: Styles.balance2,
                        ),
                        const SizedBox(height: 8),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (_current == 1) {
                                        _current = 0;
                                      }
                                    });
                                  },
                                  child: Text('큰 금액순',
                                      style: Styles.caption.merge(TextStyle(
                                          color: _current == 0
                                              ? MyColors.white
                                              : MyColors
                                                  .transparentWhite_50)))),
                              const SizedBox(width: 8),
                              GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (_current == 0) {
                                        _current = 1;
                                      }
                                    });
                                  },
                                  child: Text('최신순',
                                      style: Styles.caption.merge(TextStyle(
                                          color: _current == 1
                                              ? MyColors.white
                                              : MyColors.transparentWhite_50))))
                            ]),
                        const SizedBox(height: 20),
                        Expanded(
                            child: ListView.builder(
                                itemCount: sortedUTXOs.length,
                                itemBuilder: (context, index) {
                                  /*String accountIndex = sortedUTXOs[index]
                                      .derivationPath
                                      .split('/')
                                      .last;*/
                                  // return UTXOItem(
                                  //     utxo: sortedUTXOs[index],
                                  //     btcPrice: bitcointPriceKrw ?? 0);
                                  return Container();
                                }))
                      ]));
            }));
  }

  List<model.UTXO> sortByTimestamp(List<model.UTXO> utxos) {
    List<model.UTXO> sortedList = List.from(utxos);
    sortedList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sortedList;
  }

  List<model.UTXO> sortByAmount(List<model.UTXO> utxos) {
    List<model.UTXO> sortedList = List.from(utxos);
    sortedList.sort((a, b) => b.amount.compareTo(a.amount));
    return sortedList;
  }
}
