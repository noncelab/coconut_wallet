import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/data/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/faucet_history.dart';
import 'package:coconut_wallet/model/request/faucet_request.dart';
import 'package:coconut_wallet/model/response/default_error_response.dart';
import 'package:coconut_wallet/model/response/faucet_response.dart';
import 'package:coconut_wallet/model/response/faucet_status_response.dart';
import 'package:coconut_wallet/repositories/faucet_repository.dart';
import 'package:coconut_wallet/services/shared_prefs_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/cupertino.dart';

class FaucetRequestViewModel extends ChangeNotifier {
  final FaucetRepository _repository = FaucetRepository();
  final SharedPrefs _sharedPrefs = SharedPrefs();

  late AddressBook _walletAddressBook;
  late FaucetStatusResponse _faucetStatusResponse;
  late FaucetHistory _faucetHistory;

  bool isLoading = true;
  bool addressError = false;
  bool remainTimeError = false;

  String inputText = '';
  String _walletAddress = '';
  String _walletName = '';
  String _walletIndex = '';
  int _walletId = 0;
  int _requestCount = 0;
  double _requestAmount = 0.0;

  bool isRequesting = false;
  bool isValidAddress = false;
  final TextEditingController textController = TextEditingController();

  Duration _remainingTime = const Duration();
  String _remainingTimeString = '';
  Timer? _timer;

  String get walletAddress => _walletAddress;
  String get walletName => _walletName;
  String get walletIndex => _walletIndex;
  int get requestCount => _requestCount;
  double get requestAmount => _requestAmount;

  Duration get remainingTime => _remainingTime;
  String get remainingTimeString => _remainingTimeString;
  bool get canRequestFaucet =>
      !addressError &&
      !remainTimeError &&
      !isLoading &&
      !isRequesting &&
      requestCount < 3;

  FaucetRequestViewModel(WalletListItemBase walletBaseItem) {
    Address receiveAddress = walletBaseItem.walletBase.getReceiveAddress();
    _walletAddress = receiveAddress.address;
    _walletId = walletBaseItem.id;
    _walletName = walletBaseItem.name.length > 20
        ? '${walletBaseItem.name.substring(0, 17)}...'
        : walletBaseItem.name;
    _walletIndex = receiveAddress.derivationPath.split('/').last;
    _walletAddressBook = walletBaseItem.walletBase.addressBook;

    _faucetHistory = _sharedPrefs.getFaucetHistoryWithId(_walletId);
    _checkFaucetHistory();
    _getFaucetStatus();

    inputText = _walletAddress;
    textController.text = inputText;
  }

  @override
  void dispose() {
    textController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  /// Faucet 상태 조회 (API 호출)
  Future<void> _getFaucetStatus() async {
    try {
      final response = await _repository.getStatus();
      if (response is FaucetStatusResponse) {
        _faucetStatusResponse = response;
        isLoading = false;

        _requestCount = _faucetHistory.count;
        switch (requestCount) {
          case 0:
            _requestAmount = response.maxLimit;
            return;
          case 1:
          case 2:
            _requestAmount = response.minLimit;
            return;
        }
      }
    } catch (_) {
      // Error handling
      // WidgetsBinding.instance.addPostFrameCallback((_) {
      //   CustomToast.showWarningToast(
      //       context: context, text: '테스트 비트코인 요청에 문제가 생겼어요.');
      // });
    } finally {
      notifyListeners();
    }
  }

  Future<void> startFaucetRequest(Function(bool, String) onResult) async {
    isRequesting = true;
    notifyListeners();

    try {
      final response = await _repository.getTestCoin(
          FaucetRequest(address: inputText, amount: _requestAmount));
      if (response is FaucetResponse) {
        remainTimeError = false;
        onResult(true, '테스트 비트코인을 요청했어요. 잠시만 기다려 주세요.');
        _updateFaucetHistory();
      } else if (response is DefaultErrorResponse &&
          response.error == 'TOO_MANY_REQUEST_FAUCET') {
        remainTimeError = true;
        onResult(false, '해당 주소로 이미 요청했습니다. 입금까지 최대 5분이 걸릴 수 있습니다.');
      } else {
        remainTimeError = true;
        onResult(false, '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.');
      }
    } catch (e) {
      // Error handling
      remainTimeError = true;
      onResult(false, '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.');
    } finally {
      isRequesting = false;
      notifyListeners();
    }
  }

  void validateAddress(String address) {
    inputText = address;
    _walletAddress = address;

    textController.value = textController.value.copyWith(
      text: inputText,
      selection: TextSelection.collapsed(
          offset:
              textController.selection.baseOffset.clamp(0, inputText.length)),
    );

    addressError = !_isValidAddress(address);
    notifyListeners();
  }

  bool _isValidAddress(String address) {
    try {
      return _walletAddressBook.contains(inputText) &&
          WalletUtility.validateAddress(address);
    } catch (_) {
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

  // FIXME
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
      if (_faucetHistory.count == 3) {
        _startTimer();
      }
    } else {
      _faucetHistory = FaucetHistory(
        id: _walletId,
        dateTime: DateTime.now().millisecondsSinceEpoch,
        count: 0,
      );
    }

    Logger.log('_checkFaucetHistory(): $_faucetHistory');
    _sharedPrefs.saveFaucetHistory(_faucetHistory);
  }

  void _startTimer() {
    _remainingTime = const Duration(hours: 24);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remainingTime = _remainingTime - const Duration(seconds: 1);
      _remainingTimeString = _formatDuration(_remainingTime);
      if (_remainingTime.inSeconds <= 0) {
        timer.cancel();
        remainTimeError = false;
        addressError = false;
        // FIXME 로직 체크
        // _checkFaucetHistory(isTimerCanceled: true);
      }
      notifyListeners();
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }
}
