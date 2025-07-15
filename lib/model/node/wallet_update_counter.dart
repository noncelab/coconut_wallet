import 'package:coconut_wallet/enums/network_enums.dart';

class WalletUpdateCounter {
  int _balanceCounter;
  int _transactionCounter;
  int _utxoCounter;
  int _subscriptionCounter;

  WalletUpdateCounter({
    int balanceCounter = 0,
    int transactionCounter = 0,
    int utxoCounter = 0,
    int subscriptionCounter = 0,
  })  : _subscriptionCounter = subscriptionCounter,
        _utxoCounter = utxoCounter,
        _transactionCounter = transactionCounter,
        _balanceCounter = balanceCounter;

  /// 초기화된 카운터 생성
  factory WalletUpdateCounter.initial() {
    return WalletUpdateCounter();
  }

  /// 특정 업데이트 요소의 카운터 증가
  void incrementCounter(UpdateElement updateType) {
    switch (updateType) {
      case UpdateElement.subscription:
        _subscriptionCounter++;
        break;
      case UpdateElement.balance:
        _balanceCounter++;
        break;
      case UpdateElement.transaction:
        _transactionCounter++;
        break;
      case UpdateElement.utxo:
        _utxoCounter++;
        break;
    }
  }

  /// 특정 업데이트 요소의 카운터 감소
  /// 카운터가 0보다 작아지지 않도록 처리
  /// @return 카운터 값이 0이면 true, 아니면 false
  bool decrementCounter(UpdateElement updateType) {
    switch (updateType) {
      case UpdateElement.subscription:
        _subscriptionCounter--;
        if (_subscriptionCounter <= 0) {
          return true;
        }
        break;
      case UpdateElement.balance:
        _balanceCounter--;
        if (_balanceCounter <= 0) {
          return true;
        }
        break;
      case UpdateElement.transaction:
        _transactionCounter--;
        if (_transactionCounter <= 0) {
          return true;
        }
        break;
      case UpdateElement.utxo:
        _utxoCounter--;
        if (_utxoCounter <= 0) {
          return true;
        }
        break;
    }
    return false;
  }
}
