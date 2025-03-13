import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
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
  // TODO: recipients가 N개 이하 (테스트 해보고, 적합한 개수를 설정해야 함)
  bool get isCompleteButtonEnabled =>
      _recipients.length >= 2 &&
      _recipients.every((r) => r.isAddressValid == true && r.amount.isNotEmpty);

  @override
  void initState() {
    super.initState();
    //_recipients = [_getDefaultRecipientData()];
    // TODO: for test
    _recipients = [
      _getDefaultRecipientData()
        ..address = 'bcrt1qldnq90sqn6wz4kpd6u93f3uxt3gy7ehw7f4tw8'
        ..amount = '0.1'
        ..isAddressValid = true,
      _getDefaultRecipientData()
        ..address = 'bcrt1qndytt26zecsx9ypp3wl8zd69jg0cl7kz0lfuhf'
        ..amount = '0.1'
        ..isAddressValid = true
    ];
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
                          title: '받는 사람${index + 1}',
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
                          isRemovable: !(_recipients.length == 1 && index == 0),
                          addressPlaceholder:
                              t.send_address_screen.address_placeholder,
                          amountPlaceholder:
                              t.send_address_screen.amount_placeholder,
                          isAddressInvalid:
                              _recipients[index].isAddressValid == false,
                          isAmountDust: _recipients[index].isAmountDust == true,
                          addressErrorMessage:
                              _recipients[index].isAddressDuplicated == true
                                  ? t.errors.address_error.duplicated
                                  : null,
                        ))
                    : CoconutUnderlinedButton(
                        text: t.send_address_screen.add_recipient,
                        onTap: _addAddressAndQuantityCard,
                        textStyle: CoconutTypography.body3_12,
                        brightness: Brightness.dark,
                        padding: const EdgeInsets.only(
                            top: Sizes.size24, bottom: Sizes.size48),
                      );
              }, childCount: _recipients.length + 1)),
            ),
          ],
        ),
        Positioned(
            left: CoconutLayout.defaultPadding,
            right: CoconutLayout.defaultPadding,
            bottom: MediaQuery.of(context).viewInsets.bottom,
            child: CoconutButton(
                onPressed: () => _onComplete(context),
                text: t.complete,
                width: MediaQuery.sizeOf(context).width,
                backgroundColor: CoconutColors.primary,
                foregroundColor: CoconutColors.black,
                disabledBackgroundColor: CoconutColors.gray800,
                disabledForegroundColor: CoconutColors.gray700,
                isActive: isCompleteButtonEnabled))
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
          _recipients[index].isAddressValid = false;
          _recipients[index].isAddressDuplicated = true;
        }
      } catch (_) {
        if (_recipients[index].isAddressValid != false) {
          _recipients[index].isAddressValid = false;
        }
        _recipients[index].isAddressDuplicated = null;
        setState(() {});
      }
    }

    _recipients[index].address = address;
  }

  bool _isAddressDuplicated(String address) {
    return _recipients.any((r) => r.address == address);
  }

  void _updateAmount(int index, String amount) {
    double? doubleAmount = double.tryParse(amount);
    if (doubleAmount == null || doubleAmount == 0) {
      setState(() {
        _recipients[index].isAmountDust = null;
      });
      return;
    }

    if (doubleAmount < UnitUtil.satoshiToBitcoin(dustLimit)) {
      Logger.log(
          '-->doubleAmount: $doubleAmount, ${UnitUtil.satoshiToBitcoin(dustLimit)}');
      setState(() {
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
