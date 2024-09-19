import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/model/utxo.dart' as model;
import 'package:coconut_wallet/model/wallet_list_item.dart';
import 'package:coconut_wallet/screens/utxo_detail_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/bottom_sheet.dart';
import 'package:provider/provider.dart';

class UtxoListScreen extends StatefulWidget {
  final int id;

  const UtxoListScreen({super.key, required this.id});

  @override
  State<UtxoListScreen> createState() => _UtxoListScreenState();
}

class _UtxoListScreenState extends State<UtxoListScreen> {
  int _current = 0; // for ordering
  late int? _balance;
  late List<model.UTXO> _utxoList;
  late WalletListItem _walletListItem;

  @override
  void initState() {
    super.initState();
    final model = Provider.of<AppStateModel>(context, listen: false);
    _walletListItem = model.getWalletById(widget.id);
    _balance = _walletListItem.balance;
    List<UTXO> utxoEntities = _walletListItem.coconutWallet.getUtxoList();
    _utxoList = getUtxoListWithHoldingAddress(utxoEntities);
  }

  List<model.UTXO> getUtxoListWithHoldingAddress(List<UTXO> utxoEntities) {
    List<model.UTXO> utxos = [];
    for (var element in utxoEntities) {
      var pathElements = element.derivationPath.split('/');
      String accountIndex = pathElements.last;
      // m/84'/1'/0'/1/1
      String change = pathElements[4];

      String ownedAddress = _walletListItem.coconutWallet.getAddress(
          int.parse(accountIndex),
          isChange: int.parse(change) == 1);

      utxos.add(model.UTXO(
          element.timestamp.toString(),
          element.blockHeight.toString(),
          element.amount,
          ownedAddress,
          element.derivationPath,
          element.transactionHash));
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
                              ? '₩ ${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(_balance!, bitcointPriceKrw).toDouble())}'
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
                                  String accountIndex = sortedUTXOs[index]
                                      .derivationPath
                                      .split('/')
                                      .last;

                                  return UTXOItem(
                                      utxo: sortedUTXOs[index],
                                      btcPrice: bitcointPriceKrw ?? 0);
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

class UTXOItem extends StatelessWidget {
  final model.UTXO utxo;
  final int btcPrice;

  const UTXOItem({
    super.key,
    required this.utxo,
    required this.btcPrice,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () {
          MyBottomSheet.showBottomSheet_90(
              context: context,
              child: UtxoDetailScreen(utxo: utxo, btcPrice: btcPrice));
        },
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: MyColors.transparentWhite_06),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(DateTimeUtil.formatDatetime(utxo.timestamp),
                        style: Styles.caption),
                    Expanded(
                        child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(satoshiToBitcoinString(utxo.amount),
                                style: Styles.h3.merge(TextStyle(
                                    fontFamily:
                                        CustomFonts.number.getFontFamily)))))
                  ],
                ),
                Text(utxo.to,
                    style: Styles.caption.merge(
                        const TextStyle(color: MyColors.transparentWhite_50)))
              ],
            )));
  }
}
