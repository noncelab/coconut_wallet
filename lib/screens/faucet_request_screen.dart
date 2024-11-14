import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/data/singlesig_wallet_list_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/model/faucet_history.dart';
import 'package:coconut_wallet/model/response/default_error_response.dart';
import 'package:coconut_wallet/model/response/faucet_response.dart';
import 'package:coconut_wallet/model/response/faucet_status_response.dart';
import 'package:coconut_wallet/repositories/faucet_repository.dart';
import 'package:coconut_wallet/services/shared_prefs_service.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/custom_text_field.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
import 'package:provider/provider.dart';

class FaucetRequestScreen extends StatefulWidget {
  final SinglesigWalletListItem singlesigWalletListItem;
  final VoidCallback? onRequestSuccess;
  final VoidCallback? onNextPressed;

  const FaucetRequestScreen({
    super.key,
    required this.onRequestSuccess,
    required this.singlesigWalletListItem,
    this.onNextPressed,
  });

  @override
  State<FaucetRequestScreen> createState() => _FaucetRequestScreenState();
}

class _FaucetRequestScreenState extends State<FaucetRequestScreen> {
  late TextEditingController _faucetAddressController;
  String inputText = '';
  bool addressError = false;
  bool remainTimeError = false;
  bool faucetStatusLoading = true;

  String _walletAddress = '';
  String _walletName = '';
  String _walletIndex = '';
  int _walletId = 0;

  Timer? _timer;
  Duration _remainingTime = const Duration();
  String _timeString = '';

  late AddressBook _walletAddressBook;
  late FaucetStatusResponse _faucetStatusResponse;

  final FaucetRepository _repository = FaucetRepository();

  final SharedPrefs _sharedPrefs = SharedPrefs();
  late FaucetHistory _faucetHistory;

  @override
  void initState() {
    super.initState();
    Address receiveAddress =
        widget.singlesigWalletListItem.walletBase.getReceiveAddress();
    _walletAddress = receiveAddress.address;
    inputText = _walletAddress;
    _walletName = widget.singlesigWalletListItem.name.length > 20
        ? '${widget.singlesigWalletListItem.name.substring(0, 17)}...'
        : widget.singlesigWalletListItem.name;
    _walletIndex = receiveAddress.derivationPath.split('/').last;
    _walletAddressBook = widget.singlesigWalletListItem.walletBase.addressBook;

    _faucetAddressController = TextEditingController(text: _walletAddress);

    _walletId = widget.singlesigWalletListItem.id;
    _faucetHistory = _sharedPrefs.getFaucetHistoryWithId(_walletId);
    _checkFaucetHistory();
    _getFaucetStatus();
  }

  @override
  void dispose() {
    _faucetAddressController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  /// Faucet 상태 조회 (API 호출)
  Future<void> _getFaucetStatus() async {
    try {
      final response = await _repository.getStatus();
      if (response is FaucetStatusResponse) {
        _faucetStatusResponse = response;
        Logger.log(_faucetStatusResponse.toString());
        setState(() {
          faucetStatusLoading = false;
        });
      }
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        CustomToast.showWarningToast(
            context: context, text: '테스트 비트코인 요청에 문제가 생겼어요.');
      });
    }
  }

  Future<void> _startFaucetRequest(AppStateModel model) async {
    try {
      final result = await model.startFaucetRequest(
          inputText,
          _faucetHistory.count == 0
              ? _faucetStatusResponse.maxLimit
              : _faucetStatusResponse.minLimit);
      if (result is FaucetResponse) {
        if (mounted) {
          vibrateLight();
          CustomToast.showToast(
              context: context, text: '테스트 비트코인을 요청했어요. 잠시만 기다려 주세요.');
          widget.onRequestSuccess!();
          _updateFaucetHistory();
        }
      } else if (result is DefaultErrorResponse) {
        if (result.error == 'TOO_MANY_REQUEST_FAUCET') {
          if (mounted) {
            vibrateLight();
            CustomToast.showToast(
                context: context,
                text: '해당 주소로 이미 요청했습니다. 입금까지 최대 5분이 걸릴 수 있습니다.');
          }
        }
      } else {
        if (mounted) {
          vibrateMedium();
          CustomToast.showWarningToast(
              context: context, text: '요청에 실패했습니다. 잠시후 다시 시도해 주세요.');
        }
      }
    } catch (_) {
      vibrateMedium();
      CustomToast.showWarningToast(
          context: context, text: '요청에 실패했습니다. 잠시후 다시 시도해 주세요.');
    }
  }

  void _startTimer() {
    DateTime now = DateTime.now();
    DateTime midnight = DateTime(now.year, now.month, now.day + 1);

    setState(() {
      _remainingTime = midnight.difference(now);
      // 자정 10초 전 테스트를 하고 싶으시면 아래 주석을 해제하세요.
      //_remainingTime = Duration(seconds: 10);
      _timeString = _formatDuration(_remainingTime);
      remainTimeError = true;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingTime = _remainingTime - const Duration(seconds: 1);
        _timeString = _formatDuration(_remainingTime);

        if (_remainingTime.inSeconds <= 0) {
          timer.cancel();
          addressError = false;
          remainTimeError = false;
          _checkFaucetHistory(isTimerCanceled: true);
        }
      });
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  bool _validateAddress() {
    // 입력된 주소가 주소록에 포함되어 있는지 확인
    if (!_walletAddressBook.contains(inputText)) {
      return false;
    }
    // derivationPath 가져와서 마지막 숫자 추출
    _walletIndex =
        _walletAddressBook.getDerivationPath(inputText).split('/').last;
    // 주소가 유효한지 확인
    return _isValidAddress(inputText);
  }

  bool _isValidAddress(String address) {
    try {
      return WalletUtility.validateAddress(address);
    } catch (_) {
      // 예외가 발생하면 유효하지 않은 주소로 간주
      return false;
    }
  }

  void _updateFaucetHistory() {
    int count = _faucetHistory.count;
    int dateTime = _faucetHistory.dateTime;

    if (count == 3) {
      dateTime = DateTime.now().millisecondsSinceEpoch;
    } else {
      count += 1;
    }

    _faucetHistory = _faucetHistory.copyWith(dateTime: dateTime, count: count);

    _checkFaucetHistory();
  }

  void _checkFaucetHistory({bool isTimerCanceled = false}) {
    /// isTimerCanceled = true이면
    /// 자정이 넘어가 타이머가 초기화 된 경우
    if (isTimerCanceled) {
      _faucetHistory = FaucetHistory(
          id: _walletId,
          dateTime: DateTime.now().millisecondsSinceEpoch,
          count: 0);
    }

    if (_faucetHistory.isToday) {
      /// today
      if (_faucetHistory.count == 3) {
        _startTimer();
      }
    } else {
      /// Not today
      _faucetHistory = _faucetHistory.copyWith(
        dateTime: DateTime.now().millisecondsSinceEpoch,
        count: 0,
      );
    }

    Logger.log('_checkFaucetHistory(): $_faucetHistory');
    _sharedPrefs.saveFaucetHistory(_faucetHistory);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateModel>(
      builder: (context, model, child) {
        return GestureDetector(
          // behavior: HitTestBehavior.opaque,
          onTap: () {
            _closeKeyboard();
          },
          child: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 23),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '받을 주소',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: MyColors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      CustomTextField(
                        controller: _faucetAddressController,
                        placeholder:
                            "주소를 입력해 주세요.\n주소는 [받기] 버튼을 눌러서 확인할 수 있어요.",
                        onChanged: (text) {
                          bool addressValue = addressError;
                          inputText = text.toLowerCase();

                          addressValue = _validateAddress();
                          setState(() {
                            _faucetAddressController.value =
                                _faucetAddressController.value.copyWith(
                              text: inputText,
                              selection: TextSelection.collapsed(
                                offset: _faucetAddressController
                                    .selection.baseOffset
                                    .clamp(0, inputText.length),
                              ),
                            );
                            addressError = !addressValue;
                          });
                        },
                        maxLines: 2,
                      ),
                      const SizedBox(height: 2),
                      Visibility(
                        visible: !addressError,
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
                const SizedBox(
                  height: 24,
                ),
                IgnorePointer(
                  ignoring: (addressError ||
                      model.isFaucetRequesting ||
                      remainTimeError),
                  child: CupertinoButton(
                    onPressed: () async {
                      if (faucetStatusLoading) {
                        CustomToast.showToast(
                            context: context,
                            text: '서버 상태를 확인하는 중입니다. 잠시만 기다려주세요.');
                      }
                      if (!addressError) {
                        _closeKeyboard();
                        await _startFaucetRequest(model);
                      }
                    },
                    borderRadius: BorderRadius.circular(8.0),
                    padding: EdgeInsets.zero,
                    color: (addressError ||
                            model.isFaucetRequesting ||
                            faucetStatusLoading ||
                            remainTimeError)
                        ? MyColors.transparentWhite_30
                        : MyColors.white,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 12,
                      ),
                      child: Text(
                        faucetStatusLoading
                            ? '0 BTC 요청하기'
                            : model.isFaucetRequesting
                                ? '요청 중...'
                                : '${formatNumber(_faucetHistory.count == 0 ? _faucetStatusResponse.maxLimit : _faucetStatusResponse.minLimit)} BTC 요청하기',
                        style: Styles.label.merge(
                          TextStyle(
                              color: (addressError ||
                                      model.isFaucetRequesting ||
                                      faucetStatusLoading)
                                  ? MyColors.transparentBlack_50
                                  : MyColors.black,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              letterSpacing: -0.1),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                if (addressError || remainTimeError)
                  Text(
                    remainTimeError
                        ? '$_timeString 후에 다시 시도해 주세요'
                        : '올바른 주소인지 확인해 주세요',
                    style: Styles.label.merge(
                      const TextStyle(
                        color: MyColors.warningRed,
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _closeKeyboard() {
    FocusScope.of(context).unfocus();
  }
}
