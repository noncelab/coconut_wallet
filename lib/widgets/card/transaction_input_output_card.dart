import 'dart:math';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/input_output_detail_row.dart';
import 'package:flutter/material.dart';

class TransactionInputOutputCard extends StatefulWidget {
  final TransactionRecord transaction;
  final bool Function(String address, int index) isSameAddress;
  final bool isForTransaction;

  const TransactionInputOutputCard(
      {super.key,
      required this.transaction,
      required this.isSameAddress,
      this.isForTransaction = true});

  @override
  State<TransactionInputOutputCard> createState() => _TransactionInputOutputCard();
}

class _TransactionInputOutputCard extends State<TransactionInputOutputCard> {
  static const int kIncomingTxInputCount = 3;
  static const int kIncomingTxOutputCount = 4;
  static const int kOutgoingTxInputCount = 5;
  static const int kOutgoingTxOutputCount = 2;

  static const int kViewMoreCount = 5;
  static const int kInputMaxCount =
      kIncomingTxInputCount; // txInputCount의 min값: kIncomingTxInputCount
  static const int kOutputMaxCount =
      kOutgoingTxOutputCount; // txOutputCount의 min값: kOutgoingTxOutputCount

  bool _canShowMoreInputs = false;
  bool _canShowMoreOutputs = false;
  bool _canShowLessInputs = false;
  bool _canShowLessOutputs = false;

  int _inputCountToShow = 0;
  int _outputCountToShow = 0;

  late final TransactionRecord _transaction = widget.transaction;
  late List<TransactionAddress> _inputAddressList = [];
  late List<TransactionAddress> _outputAddressList = [];
  late final TransactionStatus _status;

  final GlobalKey _balanceWidthKey = GlobalKey();
  Size _balanceWidthSize = Size.zero;

  @override
  void initState() {
    super.initState();

    _inputCountToShow = _transaction.inputAddressList.length;
    _outputCountToShow = _transaction.outputAddressList.length;
    _inputAddressList = _transaction.inputAddressList;
    _outputAddressList = _transaction.outputAddressList;
    _status = TransactionUtil.getStatus(_transaction)!;

    if (_inputAddressList.length > kInputMaxCount) {
      _canShowMoreInputs = true;
      _setInitialInputCountToShow();
    }
    if (_outputAddressList.length > kOutputMaxCount) {
      _canShowMoreOutputs = true;
      _setInitialOutputCountToShow();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderBox = _balanceWidthKey.currentContext?.findRenderObject();
      if (renderBox is RenderBox) {
        setState(() {
          _balanceWidthSize = renderBox.size;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration:
          BoxDecoration(borderRadius: BorderRadius.circular(20), color: CoconutColors.gray800),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAddressList(
              list: _canShowMoreInputs
                  ? _inputAddressList.sublist(0, _inputCountToShow)
                  : _inputAddressList,
              rowType: InputOutputRowType.input),
          Visibility(
            visible: _canShowMoreInputs,
            child: Center(
              child: CustomUnderlinedButton(
                text: t.view_more,
                onTap: _onTapViewMoreInputs,
                fontSize: 12,
                lineHeight: 14,
              ),
            ),
          ),
          Visibility(
            visible: _canShowLessInputs,
            child: Center(
              child: CustomUnderlinedButton(
                text: t.view_less,
                onTap: _onTapViewLessInputs,
                fontSize: 12,
                lineHeight: 14,
              ),
            ),
          ),
          _buildFee(widget.transaction.fee),
          _buildAddressList(
              list: _canShowMoreOutputs
                  ? _outputAddressList.sublist(0, _outputCountToShow)
                  : _outputAddressList,
              rowType: InputOutputRowType.output),
          Visibility(
            visible: _canShowMoreOutputs,
            child: Center(
              child: CustomUnderlinedButton(
                text: t.view_more,
                onTap: _onTapViewMoreOutputs,
                fontSize: 12,
                lineHeight: 14,
              ),
            ),
          ),
          Visibility(
            visible: _canShowLessOutputs,
            child: Center(
              child: CustomUnderlinedButton(
                text: t.view_less,
                onTap: _onTapViewLessOutputs,
                fontSize: 12,
                lineHeight: 14,
              ),
            ),
          ),

          /// balance 최대 너비 체크를 위함
          Visibility(
            visible: false,
            child: Text(
              key: _balanceWidthKey,
              '0.0000 0000',
              style: CoconutTypography.body2_14_Number.setColor(
                Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressList({
    required List<TransactionAddress> list,
    required InputOutputRowType rowType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...list.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: InputOutputDetailRow(
              address: item.address,
              balance: item.amount,
              balanceMaxWidth: _balanceWidthSize.width > 0 ? _balanceWidthSize.width : 100,
              rowType: rowType,
              isCurrentAddress: widget.isSameAddress(item.address, index),
              transactionStatus: widget.isForTransaction ? _status : null,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFee(int fee) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: InputOutputDetailRow(
          address: t.fee,
          balance: fee,
          balanceMaxWidth: _balanceWidthSize.width > 0 ? _balanceWidthSize.width : 100,
          rowType: InputOutputRowType.fee,
          transactionStatus: widget.isForTransaction ? _status : null,
        ));
  }

  void _setInitialInputCountToShow() {
    final direction = TransactionUtil.getDirection(_transaction);
    setState(() {
      _inputCountToShow = direction == TransactionDirection.outgoing
          ? min(kOutgoingTxInputCount, _inputAddressList.length)
          : min(kIncomingTxInputCount, _inputAddressList.length);
      if (_inputAddressList.length < kOutgoingTxInputCount ||
          _inputAddressList.length < kIncomingTxInputCount) {
        _canShowMoreInputs = false;
      }
    });
  }

  void _setInitialOutputCountToShow() {
    final direction = TransactionUtil.getDirection(_transaction);
    setState(() {
      _outputCountToShow = direction == TransactionDirection.outgoing
          ? min(kOutgoingTxOutputCount, _outputAddressList.length)
          : min(kIncomingTxOutputCount, _outputAddressList.length);
      if (_outputAddressList.length < kOutgoingTxOutputCount ||
          _outputAddressList.length < kIncomingTxOutputCount) {
        _canShowMoreOutputs = false;
      }
    });
  }

  void _onTapViewMoreInputs() {
    setState(() {
      if (_inputCountToShow + kViewMoreCount < _inputAddressList.length) {
        _inputCountToShow += kViewMoreCount;
      } else {
        _inputCountToShow = _inputAddressList.length;
        _canShowMoreInputs = false;
        _canShowLessInputs = true;
      }
    });
  }

  void _onTapViewLessInputs() {
    _setInitialInputCountToShow();
    setState(() {
      _canShowMoreInputs = true;
      _canShowLessInputs = false;
    });
  }

  void _onTapViewMoreOutputs() {
    setState(() {
      if (_outputCountToShow + kViewMoreCount < _outputAddressList.length) {
        _outputCountToShow += kViewMoreCount;
      } else {
        _outputCountToShow = _outputAddressList.length;
        _canShowMoreOutputs = false;
        _canShowLessOutputs = true;
      }
    });
  }

  void _onTapViewLessOutputs() {
    _setInitialOutputCountToShow();
    setState(() {
      _canShowMoreOutputs = true;
      _canShowLessOutputs = false;
    });
  }
}
