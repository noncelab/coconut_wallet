import 'package:coconut_wallet/enums/network_enums.dart';

class TransactionAddress {
  final String _address;
  final int _amount;

  /// The address string.
  String get address => _address;

  /// The amount of the address.
  int get amount => _amount;

  TransactionAddress(this._address, this._amount);

  @override
  bool operator ==(Object other) {
    if (other is TransactionAddress) {
      return address == other.address && amount == other.amount;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(address, amount);
}

/// 내 주소 몫으로 금액(받은 출력 − 쓴 입력)과 유형을 정한다.
/// 거래 기록을 만들 때와, 내 주소가 늘어난 뒤 저장된 입출력으로 다시 셀 때 같은 식을 쓴다.
({int amount, TransactionType type}) countOwnAmount(
  List<TransactionAddress> inputs,
  List<TransactionAddress> outputs,
  bool Function(String address) isOwn,
) {
  var amount = 0, ownInputs = 0, ownOutputs = 0;
  for (final input in inputs) {
    if (!isOwn(input.address)) continue;
    ownInputs++;
    amount -= input.amount;
  }
  for (final output in outputs) {
    if (!isOwn(output.address)) continue;
    ownOutputs++;
    amount += output.amount;
  }
  final type =
      ownInputs == 0
          ? TransactionType.received
          : ownOutputs < outputs.length
          ? TransactionType.sent
          : ownInputs == inputs.length
          ? TransactionType.self
          : TransactionType.received;
  return (amount: amount, type: type);
}
