import 'package:coconut_wallet/ccos/features/ark/ark_vtxo.dart';

enum ArkVtxoGroupKind { expired, expiring, spendable, locked }

class ArkVtxoGroup {
  const ArkVtxoGroup(this.kind, this.vtxos);

  final ArkVtxoGroupKind kind;
  final List<ArkVtxo> vtxos;
}

/// 만료됨 → 곧 만료 → 사용 가능 → 사용 중(갱신 중 포함). 빈 묶음은 뺌
List<ArkVtxoGroup> groupArkVtxos(
  List<ArkVtxo> vtxos, {
  required List<ArkVtxo> toRenew,
  required bool Function(String id) isRenewing,
  required int? tipHeight,
}) {
  final expiringIds = {for (final vtxo in toRenew) vtxo.id};
  ArkVtxoGroupKind kindOf(ArkVtxo vtxo) {
    if (vtxo.isLocked || isRenewing(vtxo.id)) return ArkVtxoGroupKind.locked;
    if ((vtxo.blocksLeft(tipHeight) ?? 1) <= 0) return ArkVtxoGroupKind.expired;
    if (expiringIds.contains(vtxo.id)) return ArkVtxoGroupKind.expiring;
    return ArkVtxoGroupKind.spendable;
  }

  return [
    for (final kind in ArkVtxoGroupKind.values)
      if (vtxos.where((vtxo) => kindOf(vtxo) == kind).toList() case final members when members.isNotEmpty)
        ArkVtxoGroup(kind, members),
  ];
}

/// 골라서 갱신할 때 고를 수 있는 VTXO, 사용 중이거나 갱신 중이면 못 고름. 만료된 것은 서버가 받아 주면 갱신됨
bool canRenewArkVtxo(ArkVtxo vtxo, {required int? tipHeight, required bool Function(String id) isRenewing}) =>
    !vtxo.isLocked && !isRenewing(vtxo.id);

/// 수명 중 지난 몫(0~1). 시작은 만료에서 서버 수명을 뺀 높이(Noah와 같음), 받은 VTXO는 보낸 쪽 만료를 물려받아 어림값
double? arkVtxoLifetimeUsed(ArkVtxo vtxo, {required int? tipHeight, required int? lifetime}) {
  if (tipHeight == null || lifetime == null || lifetime <= 0) return null;
  final start = vtxo.expiryHeight - lifetime;
  return ((tipHeight - start) / lifetime).clamp(0, 1).toDouble();
}
