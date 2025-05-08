import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/card/address_and_amount_card.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
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
  State<SendAddressAmountBodyForBatch> createState() => _SendAddressAmountBodyForBatchState();
}

class _SendAddressAmountBodyForBatchState extends State<SendAddressAmountBodyForBatch> {
  final ScrollController _scrollController = ScrollController();
  late final List<_RecipientInfo> _recipients;
  late final List<GlobalKey> _cardKeys;
  double _addressAndAmountCardHeight = 0;

  // MAX 제한은 현재 없음
  bool get isCompleteButtonEnabled =>
      _recipients.length >= 2 &&
      _recipients.every(
          (r) => r.isAddressValid == true && r.isAddressDuplicated != true && r.amount.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _recipients = [_getDefaultRecipientData(), _getDefaultRecipientData()];
    _cardKeys = List.generate(_recipients.length, (_) => GlobalKey());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final RenderBox renderBox = _cardKeys[0].currentContext?.findRenderObject() as RenderBox;
      _addressAndAmountCardHeight = renderBox.size.height;
    });
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
                  horizontal: CoconutLayout.defaultPadding, vertical: Sizes.size28),
              sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                return index != _recipients.length
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: Sizes.size12),
                        child: AddressAndAmountCard(
                          key: _cardKeys[index],
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
                          addressPlaceholder: t.send_address_screen.address_placeholder,
                          amountPlaceholder:
                              '${t.send_address_screen.amount_placeholder} (${t.btc})',
                          isAddressInvalid: _recipients[index].isAddressValid == false ||
                              _recipients[index].isAddressDuplicated == true,
                          isAmountDust: _recipients[index].isAmountDust == true,
                          isLastItem: index == _recipients.length - 1,
                          addressErrorMessage: _recipients[index].isAddressDuplicated == true
                              ? t.errors.address_error.duplicated
                              : null,
                          onFocusRequested: () async {
                            await Future.delayed(const Duration(milliseconds: 500));
                            if (!mounted) return;
                            if (index == _recipients.length - 1) {
                              _scrollToBottom();
                              return;
                            }
                            _scrollToIndex(index);
                          },
                          onFocusAfterScanned: () async {
                            await Future.delayed(const Duration(milliseconds: 700));
                            if (mounted) {
                              _scrollToBottom();
                            }
                          },
                        ),
                      )
                    : Column(children: [
                        CoconutUnderlinedButton(
                          text: t.send_address_screen.add_recipient,
                          onTap: _addAddressAndQuantityCard,
                          textStyle: CoconutTypography.body3_12,
                          brightness: Brightness.dark,
                          padding: const EdgeInsets.only(top: Sizes.size24, bottom: Sizes.size96),
                        ),
                      ]);
              }, childCount: _recipients.length + 1)),
            ),
          ],
        ),
        FixedBottomButton(
          onButtonClicked: () {
            _onComplete(context);
          },
          text: t.complete,
          showGradient: true,
          gradientPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 40, top: 110),
          isActive: isCompleteButtonEnabled,
          backgroundColor: CoconutColors.primary,
        ),
      ],
    );
  }

  void _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 500));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && _scrollController.hasClients) {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _scrollToIndex(int index) {
    final position = index * _addressAndAmountCardHeight;
    _scrollController.animateTo(
      position,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
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

  void _addAddressAndQuantityCard() async {
    setState(() {
      _recipients.add(_getDefaultRecipientData());
      _cardKeys.add(GlobalKey());
    });

    _scrollToBottom();
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
      _cardKeys.removeAt(index);
    });
  }

  void _updateIsAddressDuplication() {
    final addressDuplicatedRecipients = _recipients.where((r) => r.isAddressDuplicated == true);
    for (var addressDuplicatedOne in addressDuplicatedRecipients) {
      var sameAddressCount =
          _recipients.where((r) => r.address == addressDuplicatedOne.address).length;
      if (sameAddressCount == 1) {
        addressDuplicatedOne.isAddressDuplicated = false;
      }
    }
  }

  void _onComplete(BuildContext context) {
    double totalAmount =
        _recipients.fold(0, (sum, recipient) => sum + (double.parse(recipient.amount)));
    bool isAffordable = widget.checkSendAvailable(UnitUtil.bitcoinToSatoshi(totalAmount));
    if (!isAffordable) {
      CoconutToast.showToast(
          isVisibleIcon: true, context: context, text: t.errors.insufficient_balance);
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
