import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/extensions/double_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/faucet/faucet_history.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/faucet_service.dart';
import 'package:coconut_wallet/services/model/response/faucet_status_response.dart';
import 'package:coconut_wallet/widgets/textfield/custom_text_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FaucetRequestBottomSheet extends StatefulWidget {
  final Map<String, dynamic> walletData;
  final bool isRequesting;
  final Function(String, double) onRequest;
  final WalletProvider walletProvider;
  final WalletListItemBase walletItem;

  const FaucetRequestBottomSheet({
    super.key,
    required this.walletData,
    required this.isRequesting,
    required this.onRequest,
    required this.walletProvider,
    required this.walletItem,
  });

  @override
  State<FaucetRequestBottomSheet> createState() => _FaucetRequestBottomSheetState();
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

    var requestHistory = SharedPrefsRepository().getFaucetHistoryWithId(_walletId);
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
        if (mounted) {
          setState(() {
            _requestAmount = (_todayRequestCount == 0) ? response.maxLimit : response.minLimit;
            _state = (_requestAmount != 0) ? _AvailabilityState.good : _AvailabilityState.bad;
          });
        }
      });
    }).catchError((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _requestAmount = 0;
            _state = _AvailabilityState.bad;
          });
        }
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
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: CoconutColors.white),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  Text(
                    t.faucet_request_bottom_sheet.title,
                    style: CoconutTypography.body1_16,
                  ),
                  Visibility(
                    visible: false,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    maintainSemantics: false,
                    maintainInteractivity: false,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: CoconutColors.white),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 30),
                  Text(
                    t.faucet_request_bottom_sheet.recipient,
                    style: CoconutTypography.body1_16_Bold,
                  ),
                  const SizedBox(height: 10),
                  CustomTextField(
                      controller: textController,
                      placeholder: t.faucet_request_bottom_sheet.placeholder,
                      onChanged: (text) {
                        _validateAddress(text.toLowerCase());
                      },
                      maxLines: 2,
                      style: CoconutTypography.body1_16_Number),
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
                        t.faucet_request_bottom_sheet
                            .my_address(name: _walletName, index: _walletIndex),
                        style: CoconutTypography.body2_14_Number,
                      ),
                    ),
                  ),
                ],
              ),
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
                color:
                    canRequestFaucet() ? CoconutColors.white : CoconutColors.white.withOpacity(0.3),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  child: _state == _AvailabilityState.checking
                      ? const SizedBox(
                          height: 28,
                          width: 28,
                          child: CircularProgressIndicator(
                            color: CoconutColors.white,
                          ),
                        )
                      : Text(
                          _isRequesting
                              ? t.faucet_request_bottom_sheet.requesting
                              : t.faucet_request_bottom_sheet
                                  .request_amount(bitcoin: _requestAmount.toTrimmedString()),
                          style: CoconutTypography.body2_14
                              .setColor((canRequestFaucet())
                                  ? CoconutColors.black
                                  : CoconutColors.black.withOpacity(0.5))
                              .merge(const TextStyle(
                                  letterSpacing: -0.1, fontWeight: FontWeight.w600)),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (_state == _AvailabilityState.bad) ...{
              _buildWarningMessage(t.alert.faucet.no_test_bitcoin),
            } else if (_state == _AvailabilityState.dailyLimitReached) ...{
              _buildWarningMessage(t.alert.faucet.try_again(count: _remainingTimeString)),
            } else if (_isErrorInAddress) ...{
              _buildWarningMessage(t.alert.faucet.check_address),
            }
          ],
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
    return SharedPrefsRepository().saveFaucetHistory(
        FaucetRecord(id: _walletId, dateTime: DateTime.now().millisecondsSinceEpoch, count: 0));
  }

  void _validateAddress(String address) {
    _walletAddress = address;
    textController.value = textController.value.copyWith(
      text: _walletAddress,
      selection: TextSelection.collapsed(
          offset: textController.selection.baseOffset.clamp(0, _walletAddress.length)),
    );

    _isErrorInAddress = !_isValidAddress(address);
    setState(() {});
  }

  bool _isValidAddress(String address) {
    try {
      return widget.walletProvider.containsAddress(widget.walletItem.id, address) &&
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
      style: CoconutTypography.body3_12.setColor(CoconutColors.red),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    textController.dispose();
    super.dispose();
  }
}
