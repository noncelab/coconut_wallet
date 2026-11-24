/// 핫월렛 온체인 잔액을 아크로 채울 때(보딩) 보낼 주소. 주소가 [expiryHeight]와 [keypairIndex]를 담고 있어 보딩 등록 때 같이 넘김
class ArkBoardFunding {
  const ArkBoardFunding({required this.address, required this.expiryHeight, required this.keypairIndex});

  final String address;
  final int expiryHeight;
  final int keypairIndex;
}

/// 아크 서버의 보딩 한도
class ArkBoardTerms {
  const ArkBoardTerms({
    required this.minAmountSats,
    required this.maxAmountSats,
    required this.requiredConfirmations,
    this.vtxoLifetimeBlocks,
  });

  /// P2TR 출력의 더스트 한도, 이보다 작으면 보딩 자체가 안 됨
  static const int dustLimitSats = 330;

  final int minAmountSats;
  final int? maxAmountSats;

  /// 아크 잔액이 되기까지 필요한 블록 확정 수
  final int requiredConfirmations;

  /// 갱신한 VTXO가 만료되기까지의 블록 수
  final int? vtxoLifetimeBlocks;

  int get minimumSats => minAmountSats > dustLimitSats ? minAmountSats : dustLimitSats;

  bool allows(int amountSats) => amountSats >= minimumSats && (maxAmountSats == null || amountSats <= maxAmountSats!);
}
