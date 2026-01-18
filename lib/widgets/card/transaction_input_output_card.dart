import 'dart:math';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/input_output_detail_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class TransactionInputOutputCard extends StatefulWidget {
  final TransactionRecord transaction;
  final bool Function(String address, int index) isSameAddress;
  final bool isForTransaction;
  final BitcoinUnit currentUnit;

  const TransactionInputOutputCard({
    super.key,
    required this.transaction,
    required this.isSameAddress,
    required this.currentUnit,
    this.isForTransaction = true,
  });

  @override
  State<TransactionInputOutputCard> createState() => _TransactionInputOutputCard();
}

class _TransactionInputOutputCard extends State<TransactionInputOutputCard> {
  static const int kIncomingTxInputCount = 3;
  static const int kIncomingTxOutputCount = 4;
  static const int kOutgoingTxInputCount = 5;
  static const int kOutgoingTxOutputCount = 2;

  static const int kViewMoreCount = 5;
  static const int kInputMaxCount = kIncomingTxInputCount; // txInputCount의 min값: kIncomingTxInputCount
  static const int kOutputMaxCount = kOutgoingTxOutputCount; // txOutputCount의 min값: kOutgoingTxOutputCount

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
  bool _isBalanceWidthCalculated = false;

  final String _minimumLongestText = "0.0000 0000";
  String _longestBtcText = "";
  String _longestSatoshiText = "";

  double get widthPerLetter => _balanceWidthSize.width / _minimumLongestText.length;
  double get satoshiBalanceWidth => _longestSatoshiText.length * widthPerLetter;
  double get btcBalanceWidth => _longestBtcText.length * widthPerLetter;
  double get balanceMaxWidth =>
      _isBalanceWidthCalculated
          ? widget.currentUnit == BitcoinUnit.btc
              ? btcBalanceWidth
              : satoshiBalanceWidth
          : 100;

  @override
  void initState() {
    super.initState();
    _initializeTransactionData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderBox = _balanceWidthKey.currentContext?.findRenderObject();
      if (renderBox is RenderBox) {
        _balanceWidthSize = renderBox.size;
        _isBalanceWidthCalculated = true;
        updateBalanceMaxWidth();
      }
    });
  }

  void _initializeTransactionData() {
    _inputCountToShow = _transaction.inputAddressList.length;
    _outputCountToShow = _transaction.outputAddressList.length;
    _inputAddressList = _transaction.inputAddressList;
    _outputAddressList = _transaction.outputAddressList;
    _status = TransactionUtil.getStatus(_transaction)!;

    // 버튼 상태 초기화
    _canShowMoreInputs = false;
    _canShowMoreOutputs = false;
    _canShowLessInputs = false;
    _canShowLessOutputs = false;

    if (_inputAddressList.length > kInputMaxCount) {
      _canShowMoreInputs = true;
      _setInitialInputCountToShow();
    }
    if (_outputAddressList.length > kOutputMaxCount) {
      _canShowMoreOutputs = true;
      _setInitialOutputCountToShow();
    }
  }

  @override
  void didUpdateWidget(TransactionInputOutputCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 트랜잭션 데이터가 변경되었으면 상태를 다시 초기화
    if (oldWidget.transaction != widget.transaction) {
      _initializeTransactionData();
      updateBalanceMaxWidth();
    }
  }

  void updateBalanceMaxWidth() {
    /// 사토시 단위의 경우, 최대 텍스트 길이에 맞게 영역을 지정한다.
    final inputList = _canShowMoreInputs ? _inputAddressList.sublist(0, _inputCountToShow) : _inputAddressList;
    final outputList = _canShowMoreOutputs ? _outputAddressList.sublist(0, _outputCountToShow) : _outputAddressList;

    int maxInputAmount =
        inputList.isNotEmpty ? inputList.map((item) => item.amount.abs()).reduce((a, b) => a > b ? a : b) : 0;
    int maxOutputAmount =
        outputList.isNotEmpty ? outputList.map((item) => item.amount.abs()).reduce((a, b) => a > b ? a : b) : 0;

    int maxAmount = max(maxInputAmount, maxOutputAmount);
    _longestSatoshiText = maxAmount.toThousandsSeparatedString();
    _longestBtcText = BalanceFormatUtil.formatSatoshiToReadableBitcoin(maxAmount);

    /// 최소값
    if (_longestBtcText.length < _minimumLongestText.length) {
      _longestBtcText = _minimumLongestText;
    }
    if (_longestSatoshiText.length < _minimumLongestText.length) {
      _longestSatoshiText = _minimumLongestText;
    }

    // 사토시 크기와 btc 크기에 큰 차이가 없는 경우, 동일한 깂을 사용한다.
    if (btcBalanceWidth < satoshiBalanceWidth && (satoshiBalanceWidth - btcBalanceWidth) < 20) {
      _longestSatoshiText = _longestBtcText;
    }

    Logger.log(
      "_longestSatoshiText = $_longestSatoshiText / _longestBtcText = $_longestBtcText / widthPerLetter = $widthPerLetter",
    );
    Logger.log("satoshiBalanceWidth = $satoshiBalanceWidth / btcBalanceWidth = $btcBalanceWidth");
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: CoconutColors.gray800),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 인풋을 조회할 수 없는 경우, 경고 메시지 표시
          if (_inputAddressList.isEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    CoconutLayout.spacing_100h,
                    SvgPicture.asset(
                      'assets/svg/triangle-warning.svg',
                      width: 14,
                      colorFilter: const ColorFilter.mode(CoconutColors.warningYellow, BlendMode.srcIn),
                    ),
                  ],
                ),
                CoconutLayout.spacing_100w,
                Expanded(
                  child: Text(
                    t.errors.empty_input,
                    softWrap: true,
                    style: CoconutTypography.body2_14.copyWith(color: CoconutColors.warningYellow),
                  ),
                ),
              ],
            ),
            CoconutLayout.spacing_200h,
          ],
          _buildAddressList(
            list: _canShowMoreInputs ? _inputAddressList.sublist(0, _inputCountToShow) : _inputAddressList,
            rowType: InputOutputRowType.input,
          ),
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
          if (_inputAddressList.isNotEmpty) _buildFee(widget.transaction.fee),
          _buildAddressList(
            list: _canShowMoreOutputs ? _outputAddressList.sublist(0, _outputCountToShow) : _outputAddressList,
            rowType: InputOutputRowType.output,
          ),
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
          Offstage(child: Text(key: _balanceWidthKey, _minimumLongestText, style: CoconutTypography.body2_14_Number)),
        ],
      ),
    );
  }

  Widget _buildAddressList({required List<TransactionAddress> list, required InputOutputRowType rowType}) {
    final filteredEntries = list.asMap().entries.where((entry) => entry.value.address.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...filteredEntries.map((entry) {
          final originalIndex = entry.key; // UTXO의 인덱스에 해당하는 원본 인덱스 유지
          final item = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: InputOutputDetailRow(
              address: item.address,
              balance: item.amount,
              balanceMaxWidth: balanceMaxWidth,
              rowType: rowType,
              isCurrentAddress: widget.isSameAddress(item.address, originalIndex),
              transactionStatus: widget.isForTransaction ? _status : null,
              currentUnit: widget.currentUnit,
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
        balanceMaxWidth: balanceMaxWidth,
        rowType: InputOutputRowType.fee,
        transactionStatus: widget.isForTransaction ? _status : null,
        currentUnit: widget.currentUnit,
      ),
    );
  }

  void _setInitialInputCountToShow() {
    final direction = TransactionUtil.getDirection(_transaction);
    setState(() {
      if (direction == TransactionDirection.outgoing) {
        _inputCountToShow = min(kOutgoingTxInputCount, _inputAddressList.length);
        if (_inputAddressList.length <= kOutgoingTxInputCount) {
          _canShowMoreInputs = false;
        }
      } else {
        _inputCountToShow = min(kIncomingTxInputCount, _inputAddressList.length);
        if (_inputAddressList.length <= kIncomingTxInputCount) {
          _canShowMoreInputs = false;
        }
      }
    });
  }

  void _setInitialOutputCountToShow() {
    final direction = TransactionUtil.getDirection(_transaction);
    setState(() {
      if (direction == TransactionDirection.outgoing) {
        _outputCountToShow = min(kOutgoingTxOutputCount, _outputAddressList.length);
        if (_outputAddressList.length <= kOutgoingTxOutputCount) {
          _canShowMoreOutputs = false;
        }
      } else {
        _outputCountToShow = min(kIncomingTxOutputCount, _outputAddressList.length);
        if (_outputAddressList.length <= kIncomingTxOutputCount) {
          _canShowMoreOutputs = false;
        }
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
      updateBalanceMaxWidth();
    });
  }

  void _onTapViewLessInputs() {
    _setInitialInputCountToShow();
    setState(() {
      _canShowMoreInputs = true;
      _canShowLessInputs = false;
    });
    updateBalanceMaxWidth();
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
      updateBalanceMaxWidth();
    });
  }

  void _onTapViewLessOutputs() {
    _setInitialOutputCountToShow();
    setState(() {
      _canShowMoreOutputs = true;
      _canShowLessOutputs = false;
      updateBalanceMaxWidth();
    });
  }
}
