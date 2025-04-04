import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/faucet/faucet_history.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/model/request/faucet_request.dart';
import 'package:coconut_wallet/services/model/error/default_error_response.dart';
import 'package:coconut_wallet/services/model/response/faucet_response.dart';
import 'package:coconut_wallet/services/faucet_service.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/cupertino.dart';

class FaucetRequestViewModel extends ChangeNotifier {
  static const int MAX_REQUEST_COUNT = 3;
  final Faucet _faucetService = Faucet();
  final SharedPrefsRepository _sharedPrefs = SharedPrefsRepository();
  final TextEditingController textController = TextEditingController();
  final WalletProvider _walletProvider;
  late FaucetRecord _faucetRecord;

  bool isLoading = true;
  bool isErrorInAddress = false;
  bool isErrorInRemainingTime = false;

  String inputText = '';
  String _walletAddress = '';
  String _walletName = '';
  String _walletIndex = '';
  int _walletId = 0;
  int _requestCount = 0;
  double _requestAmount = 0.0;

  bool isRequesting = false;
  bool isValidAddress = false;

  bool _isStartTimer = false;
  bool get isStartTimer => _isStartTimer;

  String get walletAddress => _walletAddress;
  String get walletName => _walletName;
  String get walletIndex => _walletIndex;
  double get requestAmount => _requestAmount;

  bool get canRequestFaucet =>
      !isErrorInAddress &&
      !isErrorInRemainingTime &&
      !isLoading &&
      !isRequesting &&
      _requestCount < MAX_REQUEST_COUNT;

  bool _isErrorInServerStatus = false;
  bool get isErrorInServerStatus => _isErrorInServerStatus;

  FaucetRequestViewModel(WalletListItemBase walletBaseItem, this._walletProvider) {
    initReceivingAddress(walletBaseItem);

    _faucetRecord = _sharedPrefs.getFaucetHistoryWithId(walletBaseItem.id);
    _checkFaucetRecord();
    _getFaucetStatus();

    inputText = _walletAddress;
    textController.text = inputText;
  }

  void initReceivingAddress(WalletListItemBase walletBaseItem) {
    WalletAddress receiveAddress = _walletProvider.getReceiveAddress(walletBaseItem.id);
    _walletAddress = receiveAddress.address;
    _walletId = walletBaseItem.id;
    _walletName = walletBaseItem.name.length > 20
        ? '${walletBaseItem.name.substring(0, 17)}...'
        : walletBaseItem.name; // FIXME 지갑 이름 최대 20자로 제한, 이 코드 필요 없음
    _walletIndex = receiveAddress.derivationPath.split('/').last;
  }

  @override
  void dispose() {
    textController.dispose();
    // _timer?.cancel();
    super.dispose();
  }

  /// Faucet 상태 조회 (API 호출)
  Future<void> _getFaucetStatus() async {
    try {
      final response = await _faucetService.getStatus();
      isLoading = false;
      _requestCount = _faucetRecord.count;
      if (_requestCount == 0) {
        _requestAmount = response.maxLimit;
      } else if (_requestCount <= 2) {
        _requestAmount = response.minLimit;
      }
    } catch (_) {
      setErrorInStatus(true);
    } finally {
      notifyListeners();
    }
  }

  void setErrorInStatus(bool statusValue) {
    _isErrorInServerStatus = statusValue;
  }

  Future<void> requestTestBitcoin(Function(bool, String) onResult) async {
    isRequesting = true;
    notifyListeners();

    try {
      final response = await _faucetService
          .getTestCoin(FaucetRequest(address: inputText, amount: _requestAmount));
      if (response is FaucetResponse) {
        isErrorInRemainingTime = false;
        onResult(true, '테스트 비트코인을 요청했어요. 잠시만 기다려 주세요.');
        _updateFaucetHistory();
      } else if (response is DefaultErrorResponse && response.error == 'TOO_MANY_REQUEST_FAUCET') {
        isErrorInRemainingTime = true;
        onResult(false, '해당 주소로 이미 요청했습니다. 입금까지 최대 5분이 걸릴 수 있습니다.');
      } else {
        isErrorInRemainingTime = true;
        onResult(false, '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.');
      }
    } catch (e) {
      // Error handling
      isErrorInRemainingTime = true;
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
          offset: textController.selection.baseOffset.clamp(0, inputText.length)),
    );

    isErrorInAddress = !_isValidAddress(address);
    notifyListeners();
  }

  bool _isValidAddress(String address) {
    try {
      return _walletProvider.containsAddress(_walletId, address) &&
          WalletUtility.validateAddress(address);
    } catch (_) {
      return false;
    }
  }

  void _updateFaucetHistory() {
    _checkFaucetRecord();

    int count = _faucetRecord.count;
    int dateTime = DateTime.now().millisecondsSinceEpoch;
    _faucetRecord = _faucetRecord.copyWith(dateTime: dateTime, count: count + 1);
    _saveFaucetRecordToSharedPrefs();
  }

  /// faucet 요청 이력 확인
  /// 자정을 기점으로 이력 초기화
  /// 최대 요청 횟수를 소진한 경우, 다음 요청까지 남은 시간을 알려줌
  void _checkFaucetRecord() {
    if (!_faucetRecord.isToday) {
      // 오늘 처음 요청
      _initFaucetRecord();
      _saveFaucetRecordToSharedPrefs();
      return;
    }

    _isStartTimer = _faucetRecord.count == MAX_REQUEST_COUNT;
    notifyListeners();
  }

  // void _startTimer() {
  //   DateTime now = DateTime.now();
  //   DateTime midnight = DateTime(now.year, now.month, now.day + 1);
  //
  //   _remainingTime = midnight.difference(now);
  //   _remainingTimeString = _formatDuration(_remainingTime);
  //   isErrorInRemainingTime = true;
  //
  //   _timer?.cancel();
  //   _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
  //     _remainingTime = _remainingTime - const Duration(seconds: 1);
  //     _remainingTimeString = _formatDuration(_remainingTime);
  //
  //     if (_remainingTime.inSeconds <= 0) {
  //       timer.cancel();
  //       isErrorInRemainingTime = false;
  //       isErrorInAddress = false;
  //       _initFaucetRecord();
  //       _saveFaucetRecordToSharedPrefs();
  //       _getFaucetStatus();
  //     }
  //     notifyListeners();
  //   });
  // }

  void _initFaucetRecord() {
    _faucetRecord =
        FaucetRecord(id: _walletId, dateTime: DateTime.now().millisecondsSinceEpoch, count: 0);
  }

  void _saveFaucetRecordToSharedPrefs() {
    Logger.log('_checkFaucetHistory(): $_faucetRecord');
    _sharedPrefs.saveFaucetHistory(_faucetRecord);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }
}
