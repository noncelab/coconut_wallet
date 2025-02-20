import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/faucet/faucet_history.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/faucet_service.dart';
import 'package:coconut_wallet/services/model/response/faucet_status_response.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FaucetRequestBottomSheet extends StatefulWidget {
  final Map<String, dynamic> walletData;
  final AddressBook walletAddressBook;
  final bool isRequesting;
  final Function(String, double) onRequest;

  const FaucetRequestBottomSheet({
    super.key,
    required this.walletData,
    required this.walletAddressBook,
    required this.isRequesting,
    required this.onRequest,
  });

  @override
  State<FaucetRequestBottomSheet> createState() =>
      _FaucetRequestBottomSheetState();
}

enum _AvailabilityState { checking, bad, good, dailyLimitReached }

class _FaucetRequestBottomSheetState extends State<FaucetRequestBottomSheet> {
  final int kMaxFaucetRequestCount = 3;
  _AvailabilityState _state = _AvailabilityState.checking;
  late int _todayRequestCount;
  double _requestAmount = 0;

  late int _walletId;
  String _walletAddress = '';
  String _walletName = '';
  String _walletIndex = '';

  final TextEditingController textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Duration _remainingTime = const Duration();
  Timer? _timer;
  String _remainingTimeString = '';
  bool _isErrorInAddress = false;
  bool _isRequesting = false;

  bool canRequestFaucet() =>
      _state == _AvailabilityState.good &&
      _requestAmount > 0 &&
      !_isErrorInAddress &&
      !_isRequesting;

  @override
  void initState() {
    super.initState();
    _walletId = widget.walletData['wallet_id'];
    _walletAddress = widget.walletData['wallet_address'] ?? '';
    _walletName = widget.walletData['wallet_name'] ?? '';
    _walletIndex = widget.walletData['wallet_index'] ?? '';
    textController.text = _walletAddress;
    _isRequesting = widget.isRequesting;

    var requestHistory =
        SharedPrefsRepository().getFaucetHistoryWithId(_walletId);
    _todayRequestCount = requestHistory.isToday ? requestHistory.count : 0;

    if (_todayRequestCount >= kMaxFaucetRequestCount) {
      _requestAmount = 0;
      _state = _AvailabilityState.dailyLimitReached;
      _startTimer();
    } else {
      _setAvailabilityAndAmount();
    }
  }

  void _setAvailabilityAndAmount() async {
    await Faucet().getStatus().then((FaucetStatusResponse response) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _requestAmount =
              (_todayRequestCount == 0) ? response.maxLimit : response.minLimit;
          _state = (_requestAmount != 0)
              ? _AvailabilityState.good
              : _AvailabilityState.bad;
        });
      });
    }).catchError((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _requestAmount = 0;
          _state = _AvailabilityState.bad;
        });
      });
    });
  }

  @override
  void didUpdateWidget(covariant FaucetRequestBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRequesting != oldWidget.isRequesting) {
      _isRequesting = widget.isRequesting;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: CoconutBottomSheet(
          useIntrinsicHeight: true,
          appBar: CoconutAppBar.build(
            context: context,
            title: t.faucet_request_bottom_sheet.title,
            hasRightIcon: false,
            isBottom: true,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.faucet_request_bottom_sheet.recipient,
                      style: Styles.body1Bold,
                    ),
                    const SizedBox(height: 10),
                    CoconutTextField(
                      brightness: Brightness.dark,
                      controller: textController,
                      focusNode: _focusNode,
                      maxLines: 2,
                      fontSize: 16,
                      isVisibleBorder: false,
                      placeholderText:
                          t.faucet_request_bottom_sheet.placeholder,
                      backgroundColor: CoconutColors.white.withOpacity(0.15),
                      onChanged: (text) {
                        _validateAddress(text.toLowerCase());
                      },
                    ),
                    const SizedBox(height: 2),
                    const SizedBox(height: 2),
                    Visibility(
                      visible: !_isErrorInAddress,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      maintainSemantics: false,
                      maintainInteractivity: false,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          t.faucet_request_bottom_sheet.my_address(
                              name: _walletName, index: _walletIndex),
                          style: Styles.body2Number,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                IgnorePointer(
                  ignoring: !canRequestFaucet(),
                  child: CupertinoButton(
                      onPressed: () {
                        widget.onRequest.call(_walletAddress, _requestAmount);
                        FocusScope.of(context).unfocus();
                      },
                      borderRadius: BorderRadius.circular(8.0),
                      padding: EdgeInsets.zero,
                      color: canRequestFaucet()
                          ? MyColors.white
                          : MyColors.transparentWhite_30,
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 12),
                          child: _state == _AvailabilityState.checking
                              ? const SizedBox(
                                  height: 28,
                                  width: 28,
                                  child: CircularProgressIndicator(
                                    color: MyColors.white,
                                  ),
                                )
                              : Text(
                                  _isRequesting
                                      ? t.faucet_request_bottom_sheet.requesting
                                      : t.faucet_request_bottom_sheet
                                          .request_amount(
                                              bitcoin:
                                                  formatNumber(_requestAmount)),
                                  style: Styles.label.merge(TextStyle(
                                      color: (canRequestFaucet())
                                          ? MyColors.black
                                          : MyColors.transparentBlack_50,
                                      letterSpacing: -0.1,
                                      fontWeight: FontWeight.w600)),
                                ))),
                ),
                const SizedBox(height: 4),
                if (_state == _AvailabilityState.bad) ...{
                  _buildWarningMessage(t.alert.faucet.no_test_bitcoin),
                } else if (_state == _AvailabilityState.dailyLimitReached) ...{
                  _buildWarningMessage(
                      t.alert.faucet.try_again(count: _remainingTimeString)),
                } else if (_isErrorInAddress) ...{
                  _buildWarningMessage(t.alert.faucet.check_address),
                }
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startTimer() {
    DateTime now = DateTime.now();
    DateTime midnight = DateTime(now.year, now.month, now.day + 1);

    _remainingTime = midnight.difference(now);
    _remainingTimeString = _formatDuration(_remainingTime);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remainingTime = _remainingTime - const Duration(seconds: 1);
      _remainingTimeString = _formatDuration(_remainingTime);

      if (_remainingTime.inSeconds <= 0) {
        timer.cancel();
        _todayRequestCount = 0;
        _resetFaucetRecord().then((_) {
          _setAvailabilityAndAmount();
        });
      }
      setState(() {});
    });
  }

  Future<void> _resetFaucetRecord() {
    return SharedPrefsRepository().saveFaucetHistory(FaucetRecord(
        id: _walletId,
        dateTime: DateTime.now().millisecondsSinceEpoch,
        count: 0));
  }

  void _validateAddress(String address) {
    _walletAddress = address;
    textController.value = textController.value.copyWith(
      text: _walletAddress,
      selection: TextSelection.collapsed(
          offset: textController.selection.baseOffset
              .clamp(0, _walletAddress.length)),
    );

    _isErrorInAddress = !_isValidAddress(address);
    setState(() {});
  }

  bool _isValidAddress(String address) {
    try {
      return widget.walletAddressBook.contains(_walletAddress) &&
          WalletUtility.validateAddress(address);
    } catch (_) {
      return false;
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  Widget _buildWarningMessage(String message) {
    return Text(
      message,
      style: Styles.warning,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
