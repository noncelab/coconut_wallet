import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/button/single_bottom_button.dart';
import 'package:coconut_wallet/widgets/card/address_and_amount_card.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:coconut_wallet/widgets/overlays/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class SendAddressAmountBodyForBatch extends StatefulWidget {
  final Future<void> Function(String recipient) validateAddress;
  final bool Function(int totalSendAmount) checkSendAvailable;
  final void Function(Map<String, double> recipients) onRecipientsConfirmed;

  const SendAddressAmountBodyForBatch(
      {super.key,
      required this.validateAddress,
      required this.checkSendAvailable,
      required this.onRecipientsConfirmed});

  @override
  State<SendAddressAmountBodyForBatch> createState() =>
      _SendAddressAmountBodyForBatchState();
}

class _SendAddressAmountBodyForBatchState
    extends State<SendAddressAmountBodyForBatch> {
  final ScrollController _scrollController = ScrollController();
  late final List<_RecipientInfo> _recipients;
  // MAX 제한은 현재 없음
  bool get isCompleteButtonEnabled =>
      _recipients.length >= 2 &&
      _recipients.every((r) =>
          r.isAddressValid == true &&
          r.isAddressDuplicated != true &&
          r.amount.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _recipients = [_getDefaultRecipientData(), _getDefaultRecipientData()];
    // TODO: for test
    // _recipients = [
    //   _getDefaultRecipientData()
    //     ..address =
    //         'bcrt1qlc9kcmyx6e3kwtwqmxu4wlel3pc02r6e8er7eh2ynp38p9l54w5q7326pc'
    //     ..amount = '0.0001'
    //     ..isAddressValid = true,
    //   _getDefaultRecipientData()
    //     ..address =
    //         'bcrt1q93xjhmf73tm6lh5u2rqwyadn2whw3gfkuwgqf9x6kknxx90488kq6skjhv'
    //     ..amount = '0.0001'
    //     ..isAddressValid = true,
    //   _getDefaultRecipientData()
    //     ..address =
    //         'bcrt1qyvfvzme5khvcmu3dtts0m0fjkxwkh7uz2aaclvsgzdf7c3glgzeq3v0ezs'
    //     ..amount = '0.0001'
    //     ..isAddressValid = true,
    //   _getDefaultRecipientData()
    //     ..address =
    //         'bcrt1qfwfh4zujux2rngpzcm0wahf5hdmgwlcrw35lkymetchsy88fps8qzugted'
    //     ..amount = '0.0001'
    //     ..isAddressValid = true,
    //   _getDefaultRecipientData()
    //     ..address =
    //         'bcrt1qctqkvm3e4tgpcvdc0g5fn3dhh9dq0xsc3lszr2m4zltaqfwc2xgssa6y7d'
    //     ..amount = '0.0001'
    //     ..isAddressValid = true,
    //   _getDefaultRecipientData()
    //     ..address =
    //         'bcrt1qmrjk4yg6qj4afr85zdyc9fkry38va5g6pu4p8d6uuljglu8kczkq36spcc'
    //     ..amount = '0.0001'
    //     ..isAddressValid = true,
    //   _getDefaultRecipientData()
    //     ..address =
    //         'bcrt1q292el3m6yd9m3jprrdeue4xl0ht4ywuv8xd9r3ytkehyl86k3f4s4ysm32'
    //     ..amount = '0.0001'
    //     ..isAddressValid = true,
    //   _getDefaultRecipientData()
    //     ..address =
    //         'bcrt1qnu9r52v8mthrgrc3qpev9sz5gra0k48ay05kdg265dg6jpgjfgtqrvtldj'
    //     ..amount = '0.0001'
    //     ..isAddressValid = true,
    //   _getDefaultRecipientData()
    //     ..address =
    //         'bcrt1q6q8wtr3xl85m9ynfgr3eju9rfrzjwv8qmxwwxgk8xkxt2g9ueqeq97u4cr'
    //     ..amount = '0.0001'
    //     ..isAddressValid = true,
    //   _getDefaultRecipientData()
    //     ..address =
    //         'bcrt1qpvm9enveccwj3hcvt530r5qu4ug5rxz67r8f2mhezcrjfjzfcphsw7s553'
    //     ..amount = '0.0001'
    //     ..isAddressValid = true,
    //   _getDefaultRecipientData()
    //     ..address =
    //         'bcrt1qkxrprv0wxq0ku8ptw85ykc39km9m3a2h722m2dgsyv2d2pl3p24sc0mykr'
    //     ..amount = '0.0001'
    //     ..isAddressValid = true,
    //   _getDefaultRecipientData()
    //     ..address =
    //         'bcrt1qu9patke3pgaq49csf2mtmzf4vushqjn2dz53ul8ajswqn8p8tgpsrp20gs'
    //     ..amount = '0.0001'
    //     ..isAddressValid = true,
    //   _getDefaultRecipientData()
    //     ..address =
    //         'bcrt1qh0ypcrkd20ysljw5awug5ey4wqtn9xt9q4pj0ypvkt82ywhwyrxsq4yvlt'
    //     ..amount = '0.0001'
    //     ..isAddressValid = true,
    //   _getDefaultRecipientData()
    //     ..address =
    //         'bcrt1q8a2we9yvqz7rylm2366qd4g5v7n0mlhgawq2ahrmewqrc4rpwc4stjn0te'
    //     ..amount = '0.0001'
    //     ..isAddressValid = true,
    //   _getDefaultRecipientData()
    //     ..address =
    //         'bcrt1qmdlmtwu6wyc6vfdk0sruc0heu4q7g72yq5l7zjuzngjlyj3xvpnqggmthh'
    //     ..amount = '0.0001'
    //     ..isAddressValid = true,
    //   _getDefaultRecipientData()
    //     ..address =
    //         'bcrt1qsswd8z623d8hkfedgmdq87d8j3p90f8qxfxd0wsd6sc0n5pd0y5stnywz4'
    //     ..amount = '0.0001'
    //     ..isAddressValid = true,
    //   _getDefaultRecipientData()
    //     ..address =
    //         'bcrt1qgjqjpek8suvhdfr453vs8wkgsukg0k26zk3v9lcgt8uzqhs7jrcscelh2w'
    //     ..amount = '0.0001'
    //     ..isAddressValid = true,
    //   _getDefaultRecipientData()
    //     ..address =
    //         'bcrt1qp98gcqxfvh4hd770mhkeeag0rcdhm3rdg2fdw2p674e324hejs2sdqgun7'
    //     ..amount = '0.0001'
    //     ..isAddressValid = true,
    //   _getDefaultRecipientData()
    //     ..address =
    //         'bcrt1qc3qy5smzaxlqzmejlsdj8zawt7k6f43hmhjzew5qhd5gdzfz5jjs3z7cez'
    //     ..amount = '0.0001'
    //     ..isAddressValid = true,
    //   _getDefaultRecipientData()
    //     ..address =
    //         'bcrt1ql7ll4v6t6326yxcytnapu30aama7dn2qxux8vszzsrp7gadfs9rs8pn6g8'
    //     ..amount = '0.0001'
    //     ..isAddressValid = true,
    //];
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,
          semanticChildCount: 1,
          slivers: [
            SliverSafeArea(
              bottom: false,
              minimum: const EdgeInsets.symmetric(
                  horizontal: CoconutLayout.defaultPadding,
                  vertical: Sizes.size28),
              sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                return index != _recipients.length
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: Sizes.size12),
                        child: AddressAndAmountCard(
                          key: ValueKey(_recipients[index].key),
                          title: '${t.recipient} ${index + 1}',
                          address: _recipients[index].address,
                          amount: _recipients[index].amount,
                          onAddressChanged: (String address) {
                            _updateAddress(index, address);
                          },
                          onAmountChanged: (String amount) {
                            _updateAmount(index, amount);
                          },
                          onDeleted: (bool isContentEmpty) {
                            _onDeleted(isContentEmpty, index);
                          },
                          validateAddress: widget.validateAddress,
                          isRemovable: _recipients.length > 2,
                          addressPlaceholder:
                              t.send_address_screen.address_placeholder,
                          amountPlaceholder:
                              '${t.send_address_screen.amount_placeholder} (${t.btc})',
                          isAddressInvalid: _recipients[index].isAddressValid ==
                                  false ||
                              _recipients[index].isAddressDuplicated == true,
                          isAmountDust: _recipients[index].isAmountDust == true,
                          addressErrorMessage:
                              _recipients[index].isAddressDuplicated == true
                                  ? t.errors.address_error.duplicated
                                  : null,
                        ))
                    : Column(children: [
                        CoconutUnderlinedButton(
                          text: t.send_address_screen.add_recipient,
                          onTap: _addAddressAndQuantityCard,
                          textStyle: CoconutTypography.body3_12,
                          brightness: Brightness.dark,
                          padding: const EdgeInsets.only(
                              top: Sizes.size24, bottom: Sizes.size96),
                        ),
                      ]);
              }, childCount: _recipients.length + 1)),
            ),
          ],
        ),
        SingleBottomButton(
          onButtonClicked: () => _onComplete(context),
          text: t.complete,
          showGradient: true,
          isActive: isCompleteButtonEnabled,
          backgroundColor: CoconutColors.primary,
        ),
      ],
    );
  }

  void _updateAddress(int index, String address) async {
    if (address.isEmpty) {
      setState(() {
        _recipients[index].isAddressValid = null;
        _recipients[index].isAddressDuplicated = null;
      });
    } else {
      try {
        await widget.validateAddress(address);
        if (!_isAddressDuplicated(address)) {
          _recipients[index].isAddressValid = true;
          _recipients[index].isAddressDuplicated = false;
        } else {
          _recipients[index].isAddressValid = true;
          _recipients[index].isAddressDuplicated = true;
        }
      } catch (_) {
        if (_recipients[index].isAddressValid != false) {
          _recipients[index].isAddressValid = false;
        }
        _recipients[index].isAddressDuplicated = null;
      }
    }

    _recipients[index].address = address;
    setState(() {});
  }

  bool _isAddressDuplicated(String address) {
    return _recipients.any((r) => r.address == address);
  }

  void _updateAmount(int index, String amount) {
    double? doubleAmount = double.tryParse(amount);
    if (doubleAmount == null || doubleAmount == 0) {
      setState(() {
        _recipients[index].amount = '';
        _recipients[index].isAmountDust = null;
      });
      return;
    }

    if (doubleAmount < UnitUtil.satoshiToBitcoin(dustLimit)) {
      setState(() {
        _recipients[index].amount = '';
        _recipients[index].isAmountDust = true;
      });
      return;
    }

    setState(() {
      _recipients[index].amount = amount;
      _recipients[index].isAmountDust = false;
    });
  }

  void _addAddressAndQuantityCard() {
    setState(() {
      _recipients.add(_getDefaultRecipientData());
    });
  }

  _RecipientInfo _getDefaultRecipientData() {
    return _RecipientInfo(key: const Uuid().v1(), address: '', amount: '');
  }

  void _onDeleted(bool isEmpty, int index) {
    if (!isEmpty) {
      CustomDialogs.showCustomAlertDialog(context,
          title: '${t.delete} ${t.confirm}',
          message: t.alert.recipient_delete.description, onConfirm: () {
        _deleteRecipient(index);
        _updateIsAddressDuplication();
        Navigator.pop(context);
      }, onCancel: () {
        Navigator.pop(context);
      });
      return;
    }

    _deleteRecipient(index);
  }

  void _deleteRecipient(int index) {
    setState(() {
      _recipients.removeAt(index);
    });
  }

  void _updateIsAddressDuplication() {
    final addressDuplicatedRecipients =
        _recipients.where((r) => r.isAddressDuplicated == true);
    for (var addressDuplicatedOne in addressDuplicatedRecipients) {
      var sameAddressCount = _recipients
          .where((r) => r.address == addressDuplicatedOne.address)
          .length;
      if (sameAddressCount == 1) {
        addressDuplicatedOne.isAddressDuplicated = false;
      }
    }
  }

  void _onComplete(BuildContext context) {
    double totalAmount = _recipients.fold(
        0, (sum, recipient) => sum + (double.parse(recipient.amount)));
    bool isAffordable =
        widget.checkSendAvailable(UnitUtil.bitcoinToSatoshi(totalAmount));
    if (!isAffordable) {
      CustomToast.showToast(
          context: context, text: t.errors.insufficient_balance);
    } else {
      widget.onRecipientsConfirmed(_recipients.fold({}, (result, recipient) {
        result[recipient.address] = double.parse(recipient.amount);
        return result;
      }));
    }
  }
}

class _RecipientInfo {
  late final String key;
  String address;
  String amount;
  bool? isAddressValid;
  bool? isAmountDust;
  bool? isAddressDuplicated;

  _RecipientInfo({required this.key, this.address = '', this.amount = ''});
}
