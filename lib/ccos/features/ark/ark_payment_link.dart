import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_payment_request.dart';

/// 결제 링크를 아크 지갑 보내기로 열지. 온체인 주소 없이 아크·라이트닝만 있으면 아크 지갑,
/// 온체인 주소가 있는 링크는 코코넛 보내기에서 어디서 보낼지 고름
bool opensInArkWallet(String uri, NetworkType network, {required bool hasArkWallet}) {
  if (!hasArkWallet) return false;
  final request = ArkPaymentRequest.parse(uri, network);
  if (!request.isPayable) return false;
  return request.bitcoinAddress == null && (request.arkAddress != null || request.lightningInvoice != null);
}
