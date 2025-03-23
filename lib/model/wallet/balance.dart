import 'dart:convert';

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

/// 지갑의 현재 잔액과 이전 잔액(AnimatedBalance 용도)
class RecentBalance {
  final int? _currentBalance;
  final int? _previousBalance;

  RecentBalance(this._currentBalance, this._previousBalance);

  int? get currentBalance => _currentBalance;
  int? get previousBalance => _previousBalance;
}

/// 특정 인덱스를 가진 주소의 잔액
class AddressBalance extends Balance {
  final int index;

  AddressBalance(super.confirmed, super.unconfirmed, this.index);
}
