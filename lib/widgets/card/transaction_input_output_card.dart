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
  static const int kInputMaxCount = kIncomingTxInputCount;
  static const int kOutputMaxCount = kOutgoingTxOutputCount;

  bool _canSeeMoreInputs = false;
  bool _canSeeMoreOutputs = false;
  int _inputCountToShow = 0;
  int _outputCountToShow = 0;

  late List<TransactionAddress> _inputAddressList = [];
  late List<TransactionAddress> _outputAddressList = [];
  late final TransactionStatus _status;

  @override
  void initState() {
    super.initState();

    final transaction = widget.transaction;
    _inputCountToShow = transaction.inputAddressList.length;
    _outputCountToShow = transaction.outputAddressList.length;
    _inputAddressList = transaction.inputAddressList;
    _outputAddressList = transaction.outputAddressList;
    _status = TransactionUtil.getStatus(transaction)!;
    final direction = TransactionUtil.getDirection(transaction);

    if (transaction.inputAddressList.length > kInputMaxCount) {
      _canSeeMoreInputs = true;
      _inputCountToShow = direction == TransactionDirection.outgoing
          ? kOutgoingTxInputCount
          : kIncomingTxInputCount;
    }
    if (transaction.outputAddressList.length > kOutputMaxCount) {
      _canSeeMoreOutputs = true;
      _outputCountToShow = direction == TransactionDirection.outgoing
          ? kOutgoingTxOutputCount
          : kIncomingTxOutputCount;
    }
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
              list: _canSeeMoreInputs
                  ? _inputAddressList.sublist(0, _inputCountToShow)
                  : _inputAddressList,
              rowType: InputOutputRowType.input),
          Visibility(
            visible: _canSeeMoreInputs,
            child: Center(
              child: CustomUnderlinedButton(
                text: t.view_more,
                onTap: _onTapViewMoreInputs,
                fontSize: 12,
                lineHeight: 14,
              ),
            ),
          ),
          _buildFee(widget.transaction.fee),
          _buildAddressList(
              list: _canSeeMoreOutputs
                  ? _outputAddressList.sublist(0, _outputCountToShow)
                  : _outputAddressList,
              rowType: InputOutputRowType.output),
          Visibility(
            visible: _canSeeMoreOutputs,
            child: Center(
              child: CustomUnderlinedButton(
                text: t.view_more,
                onTap: _onTapViewMoreOutputs,
                fontSize: 12,
                lineHeight: 14,
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
    debugPrint('>>> _buildAddressList : ${list.length}');
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
              balanceMaxWidth: 100,
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
          balanceMaxWidth: 100,
          rowType: InputOutputRowType.fee,
          transactionStatus: widget.isForTransaction ? _status : null,
        ));
  }

  void _onTapViewMoreInputs() {
    setState(() {
      if (_inputCountToShow + kViewMoreCount < _inputAddressList.length) {
        _inputCountToShow += kViewMoreCount;
      } else {
        _inputCountToShow = _inputAddressList.length;
        _canSeeMoreInputs = false;
      }
    });
  }

  void _onTapViewMoreOutputs() {
    setState(() {
      if (_outputCountToShow + kViewMoreCount < _outputAddressList.length) {
        _outputCountToShow += kViewMoreCount;
      } else {
        _outputCountToShow = _outputAddressList.length;
        _canSeeMoreOutputs = false;
      }
    });
  }
}
