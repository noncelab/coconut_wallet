import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/textfield/custom_text_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FaucetRequestBottomSheet extends StatefulWidget {
  final Map<String, dynamic> walletData;
  final AddressBook walletAddressBook;
  final bool isFaucetRequestLimitExceeded;
  final bool isRequesting;
  final Function(String) onRequest;

  const FaucetRequestBottomSheet({
    super.key,
    required this.walletData,
    required this.walletAddressBook,
    required this.isFaucetRequestLimitExceeded,
    required this.isRequesting,
    required this.onRequest,
  });

  @override
  State<FaucetRequestBottomSheet> createState() =>
      _FaucetRequestBottomSheetState();
}

class _FaucetRequestBottomSheetState extends State<FaucetRequestBottomSheet> {
  String _walletAddress = '';
  String _walletName = '';
  String _walletIndex = '';
  double _requestAmount = 0;

  final TextEditingController textController = TextEditingController();

  Duration _remainingTime = const Duration();
  Timer? _timer;
  String _remainingTimeString = '';
  bool _isFaucetRequestLimitExceeded = false;
  bool _isErrorInAddress = false;
  bool _isRequesting = false;

  bool canRequestFaucet() =>
      !_isErrorInAddress && !_isFaucetRequestLimitExceeded && !_isRequesting;

  @override
  void initState() {
    super.initState();
    _walletAddress = widget.walletData['wallet_address'] ?? '';
    _walletName = widget.walletData['wallet_name'] ?? '';
    _walletIndex = widget.walletData['wallet_index'] ?? '';
    _requestAmount = widget.walletData['wallet_request_amount'] ?? 0;
    textController.text = _walletAddress;

    _isFaucetRequestLimitExceeded = widget.isFaucetRequestLimitExceeded;
    _isRequesting = widget.isRequesting;

    if (_isFaucetRequestLimitExceeded) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant FaucetRequestBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFaucetRequestLimitExceeded !=
            oldWidget.isFaucetRequestLimitExceeded &&
        widget.isFaucetRequestLimitExceeded) {
      _startTimer();
    }

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
                    icon: const Icon(Icons.close, color: MyColors.white),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  const Text(
                    '테스트 비트코인 받기',
                    style: Styles.body1,
                  ),
                  Visibility(
                    visible: false,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    maintainSemantics: false,
                    maintainInteractivity: false,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: MyColors.white),
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
                  const Text(
                    '받을 주소',
                    style: Styles.body1Bold,
                  ),
                  const SizedBox(height: 10),
                  CustomTextField(
                      controller: textController,
                      placeholder: "주소를 입력해 주세요.\n주소는 [받기] 버튼을 눌러서 확인할 수 있어요.",
                      onChanged: (text) {
                        _validateAddress(text.toLowerCase());
                      },
                      maxLines: 2,
                      style: Styles.body1.merge(TextStyle(
                          fontFamily: CustomFonts.number.getFontFamily))),
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
                        '내 지갑($_walletName) 주소 - $_walletIndex',
                        style: Styles.body2Number,
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
                    widget.onRequest.call(_walletAddress);
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
                      child: Text(
                        _isRequesting
                            ? '요청 중...'
                            : '${formatNumber(_requestAmount)} BTC 요청하기',
                        style: Styles.label.merge(TextStyle(
                            color: (canRequestFaucet())
                                ? MyColors.black
                                : MyColors.transparentBlack_50,
                            letterSpacing: -0.1,
                            fontWeight: FontWeight.w600)),
                      ))),
            ),
            const SizedBox(height: 4),
            if (_isErrorInAddress) ...{
              _buildWarningMessage('올바른 주소인지 확인해 주세요'),
            } else if (_isFaucetRequestLimitExceeded) ...{
              _buildWarningMessage('$_remainingTimeString 후에 다시 시도해 주세요'),
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
    _isFaucetRequestLimitExceeded = true;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remainingTime = _remainingTime - const Duration(seconds: 1);
      _remainingTimeString = _formatDuration(_remainingTime);

      if (_remainingTime.inSeconds <= 0) {
        timer.cancel();
        _isFaucetRequestLimitExceeded = false;
        _isErrorInAddress = false;
      }
      setState(() {});
    });
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
    textController.dispose();
    super.dispose();
  }
}
