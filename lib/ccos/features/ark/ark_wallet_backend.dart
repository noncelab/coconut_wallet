import 'dart:typed_data';

import 'package:coconut_wallet/ccos/features/ark/ark_balance.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_board.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_exit.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_payment_request.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_vtxo.dart';

/// 라이트닝으로 받을 BOLT11 인보이스
class ArkLightningInvoice {
  const ArkLightningInvoice({
    required this.invoice,
    required this.paymentHash,
    required this.amountSats,
    required this.feeSats,
  });

  final String invoice;
  final String paymentHash;
  final int amountSats;

  /// 받을 때 아크 서버가 [amountSats]에서 떼는 수수료
  final int feeSats;

  int get netAmountSats => amountSats - feeSats;
}

/// 보내기 실패. bark가 그 사이에 거래를 남겼으면 [movementId]
class ArkPaymentException implements Exception {
  ArkPaymentException(this.cause, {this.movementId});

  final Object cause;
  final int? movementId;

  @override
  String toString() => 'ArkPaymentException($cause, movement $movementId)';
}

abstract interface class ArkWalletBackend {
  Future<String> fingerprintOf(Uint8List mnemonic);
  Future<void> create(String fingerprint, Uint8List mnemonic, {required bool restore});
  Future<void> open(String fingerprint, Uint8List mnemonic);
  bool isOpen(String fingerprint);
  Future<ArkBalance> balance(String fingerprint);
  Future<bool> isRecoveryPending(String fingerprint);
  Future<List<String>> listFingerprints();
  Future<void> wipeAll();

  /// 우편함·라운드·라이트닝 받기 수령에 더해 만료가 다가온 VTXO 갱신도 서버에 맡김(자동 갱신, 늘 켬)
  Future<void> sync(String fingerprint);
  Future<List<ArkMovement>> history(String fingerprint);
  Future<String> newArkAddress(String fingerprint);
  Future<ArkLightningInvoice> createLightningInvoice(String fingerprint, int amountSats, {String? description});
  Future<int> estimateSendFee(String fingerprint, ArkPaymentRail rail, int amountSats);

  /// 만든 거래 id를 돌려줌. 실패하면 [ArkPaymentException]
  Future<int?> send(
    String fingerprint,
    ArkPaymentRail rail,
    String destination,
    int amountSats, {
    bool invoiceHasAmount,
  });

  Future<List<ArkVtxo>> vtxos(String fingerprint);

  /// 아크 서버가 보는 체인의 현재 블록 높이
  Future<int?> tipHeight();

  /// [withinBlocks] 블록 안에 만료되는 갱신할 수 있는 VTXO
  Future<List<String>> expiringVtxoIds(String fingerprint, int withinBlocks);

  /// 갱신 라운드에 들어가 있는 VTXO
  Future<Set<String>> renewingVtxoIds(String fingerprint);
  Future<int> estimateRenewFee(String fingerprint, List<String> vtxoIds);

  /// 아크 서버가 새 VTXO에 주는 수명(블록)
  Future<int?> vtxoLifetime(String fingerprint);

  /// 갱신을 서버에 맡김(위임 라운드), 앱이 켜져 있지 않아도 됨
  Future<void> renew(String fingerprint, List<String> vtxoIds);

  Future<ArkBoardTerms> boardTerms(String fingerprint);

  /// 보딩할 새 주소. 부를 때마다 키를 하나 쓰므로 보딩이 끝날 때까지 다시 씀
  Future<ArkBoardFunding> boardFunding(String fingerprint);
  Future<int> estimateBoardFee(String fingerprint, int amountSats);

  /// 서명 전 펀딩 PSBT로 보딩을 등록. 이후 거래 ID가 고정되므로 RBF로 바꾸면 안 됨
  Future<void> board(String fingerprint, {required String unsignedPsbtBase64, required ArkBoardFunding funding});

  /// bark 체인 소스로 거래를 전송, 코코넛 노드 전송이 실패했을 때
  Future<String> broadcastTx(String fingerprint, String txHex);

  /// [amountSats]가 없으면 아크 잔액 전부(수수료는 금액에서 빠짐), 있으면 그 금액(수수료는 더해짐)
  Future<int> estimateExportFee(String fingerprint, String address, {int? amountSats});

  /// 아크 잔액을 [address]로 온체인 전송, 거래 ID
  Future<String> export(String fingerprint, String address, {int? amountSats});

  /// 서버 없이 출금할 수 있는 VTXO(잠기지 않고 만료되지 않은 것)와 예상 수수료
  Future<ArkExitQuote> estimateExit(String fingerprint);

  /// 출금 수수료 지갑으로 수수료를 보낼 주소
  Future<String> exitFeeAddress(String fingerprint);
  ArkExitSteps exitSteps(String fingerprint);
}
