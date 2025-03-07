import 'package:coconut_wallet/providers/view_model/wallet_detail/fee_bumping/fee_bumping_view_model.dart';

class RbfViewModel extends FeeBumpingViewModel {
  int get recommendFeeRate => getRecommendFeeRate();
  RbfViewModel(
    super._transaction,
    super._walletId,
    super._nodeProvider,
    super._sendInfoProvider,
    super._walletProvider,
    super._currentUtxo,
  ) {
    print('RbfViewModel created');
  }

  int getRecommendFeeRate() {
    // TODO : 기존수수료 + 1로 설정, 단 기존수수료가 feeInfo[2].satsPerVb(느린전송) 보다 작다면 feeInfo[2].satsPerVb으로 반환
    return 1;
  }
}
