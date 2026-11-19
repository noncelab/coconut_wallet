import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;

/// 아크 지갑이 가진 VTXO 하나
class ArkVtxo {
  const ArkVtxo({
    required this.id,
    required this.amountSats,
    required this.expiryHeight,
    required this.kind,
    required this.isLocked,
  });

  factory ArkVtxo.fromBark(bark.Vtxo vtxo) => ArkVtxo(
    id: vtxo.id,
    amountSats: vtxo.amountSats,
    expiryHeight: vtxo.expiryHeight,
    kind: vtxo.kind,
    isLocked: vtxo.state is bark.LockedVtxoState,
  );

  /// 함께 갱신하는 VTXO 합계의 최소값. bark가 라운드 전에 막는 VTXO_DUST(P2TR dust)와 같음
  static const int minRenewSats = 330;

  final String id;
  final int amountSats;

  /// 이 높이가 지나면 서버가 거둘 수 있어서 그 전에 갱신해야 함
  final int expiryHeight;

  /// bark의 정책 종류, 예: `Pubkey`
  final String kind;

  /// 진행 중인 작업(라운드, 라이트닝 보내기 등)이 잡고 있어 지금은 못 씀
  final bool isLocked;

  int? blocksLeft(int? tipHeight) => tipHeight == null ? null : expiryHeight - tipHeight;
}
