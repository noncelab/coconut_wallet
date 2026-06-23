enum BitBox02Coin {
  btc(0),
  tbtc(1),
  ltc(2),
  tltc(3),
  rbtc(4);

  const BitBox02Coin(this.value);
  final int value;
}

enum BitBox02ScriptType {
  p2wpkh('p2wpkh'),
  p2wpkhP2sh('p2wpkh-p2sh'),
  p2tr('p2tr');

  const BitBox02ScriptType(this.value);
  final String value;
}

enum BitBox02XPubType {
  tpub(0),
  xpub(1),
  ypub(2),
  zpub(3),
  vpub(4),
  upub(5),
  capitalVpub(6),
  capitalZpub(7),
  capitalUpub(8),
  capitalYpub(9);

  const BitBox02XPubType(this.value);
  final int value;
}

enum BitBox02FormatUnit {
  defaultUnit(0),
  sat(1);

  const BitBox02FormatUnit(this.value);
  final int value;
}

class BitBox02SignMessageResult {
  final String signature;
  final int recId;
  final String electrumSig65;

  const BitBox02SignMessageResult({
    required this.signature,
    required this.recId,
    required this.electrumSig65,
  });

  factory BitBox02SignMessageResult.fromJson(Map<String, dynamic> json) {
    return BitBox02SignMessageResult(
      signature: json['signature'] as String,
      recId: json['recId'] as int,
      electrumSig65: json['electrumSig65'] as String,
    );
  }
}
