import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/core/exceptions/rbf_creation/rbf_creation_exception.dart';

class OutputAnalysis {
  final List<TransactionAddress> externalOutputs; // 남의 주소
  final List<TransactionAddress> selfOutputs; // 내 receiving 주소
  final TransactionAddress? changeOutput; // 내 change 주소
  final String? changeDerivationPath;

  OutputAnalysis._(this.externalOutputs, this.selfOutputs, this.changeOutput, this.changeDerivationPath);

  factory OutputAnalysis.fromPendingTx({
    required TransactionRecord pendingTx,
    required bool Function(String address, {bool isChange}) isMyAddress,
    required String Function(String address) getDerivationPath,
  }) {
    final outputs = pendingTx.outputAddressList;

    // change output 찾기
    final changeIndex = outputs.lastIndexWhere((output) => isMyAddress(output.address, isChange: true));
    TransactionAddress? changeOutput;
    String? changeDerivationPath;
    if (changeIndex != -1) {
      changeOutput = outputs[changeIndex];
      changeDerivationPath = getDerivationPath(changeOutput.address);
      if (changeDerivationPath.isEmpty) {
        throw const InvalidChangeOutputException();
      }
    }

    // change output 을 제외한 나머지를 self/external로 분류
    final List<TransactionAddress> selfOutputs = [];
    final List<TransactionAddress> externalOutputs = [];
    for (int i = 0; i < outputs.length; i++) {
      if (i == changeIndex) continue;
      if (isMyAddress(outputs[i].address)) {
        selfOutputs.add(outputs[i]);
      } else {
        externalOutputs.add(outputs[i]);
      }
    }

    return OutputAnalysis._(externalOutputs, selfOutputs, changeOutput, changeDerivationPath);
  }

  int get externalSum => externalOutputs.fold(0, (s, o) => s + o.amount);
  int get selfSum => selfOutputs.fold(0, (s, o) => s + o.amount);
  int get nonChangeSum => externalSum + selfSum;

  bool get hasDuplicatedOutput {
    final externalAddresses = externalOutputs.map((output) => output.address).toList();
    final selfAddresses = selfOutputs.map((output) => output.address).toList();
    return externalAddresses.toSet().length != externalAddresses.length ||
        selfAddresses.toSet().length != selfAddresses.length;
  }

  Map<String, int> get recipientMap => {
    for (final o in [...externalOutputs, ...selfOutputs]) o.address: o.amount,
  };
}
