import 'dart:convert';

import 'package:coconut_wallet/utils/logger.dart';

/// Represents the balance of a wallet.
class Balance {
  int confirmed;
  int unconfirmed;

  Balance(this.confirmed, this.unconfirmed);

  int get total => confirmed + unconfirmed;

  /// @nodoc
  Balance operator +(Balance other) {
    return Balance(
        confirmed + other.confirmed, unconfirmed + other.unconfirmed);
  }

  /// @nodoc
  String toJson() {
    return jsonEncode({'confirmed': confirmed, 'unconfirmed': unconfirmed});
  }

  /// @nodoc
  factory Balance.fromJson(String jsonStr) {
    Map<String, dynamic> json = jsonDecode(jsonStr);
    return Balance(json['confirmed'], json['unconfirmed']);
  }
}

/// 특정 인덱스를 가진 주소의 잔액
class AddressBalance extends Balance {
  final int index;

  AddressBalance(super.confirmed, super.unconfirmed, this.index);
}

/// 전체 지갑의 잔액 정보
class WalletBalance extends Balance {
  final List<AddressBalance> receiveAddressBalances;
  final List<AddressBalance> changeAddressBalances;

  WalletBalance(
    this.receiveAddressBalances,
    this.changeAddressBalances,
  ) : super(
          _calculateTotal(receiveAddressBalances, changeAddressBalances, true),
          _calculateTotal(receiveAddressBalances, changeAddressBalances, false),
        );

  static int _calculateTotal(
    List<AddressBalance> receiveBalances,
    List<AddressBalance> changeBalances, [
    bool isConfirmed = true,
  ]) {
    final receiveTotal = receiveBalances
        .map((e) => isConfirmed ? e.confirmed : e.unconfirmed)
        .reduce((a, b) => a + b);
    final changeTotal = changeBalances
        .map((e) => isConfirmed ? e.confirmed : e.unconfirmed)
        .reduce((a, b) => a + b);

    return receiveTotal + changeTotal;
  }
}
