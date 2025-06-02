import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/widgets/button/copy_text_container.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

class OnchainDonationInfoScreen extends StatefulWidget {
  final int donationAmount;
  const OnchainDonationInfoScreen({
    super.key,
    required this.donationAmount,
  });

  @override
  State<OnchainDonationInfoScreen> createState() => _OnchainDonationInfoScreenState();
}

class _OnchainDonationInfoScreenState extends State<OnchainDonationInfoScreen> {
  int? totalDonationAmount;
  int? feeValue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CoconutAppBar.build(
        title: t.donation.donate,
        context: context,
        backgroundColor: CoconutColors.black,
      ),
      resizeToAvoidBottomInset: false,
      body: Consumer3<WalletProvider, NodeProvider, ConnectivityProvider>(
        builder: (context, walletProvider, nodeProvider, connectivityProvider, _) {
          // bool isSyncing = nodeProvider.state.connectionState != MainClientState.waiting;
          bool isSyncing = walletProvider.isSyncing;
          bool isNetworkConnected = connectivityProvider.isNetworkOn ?? false;
          List<WalletListItemBase> singlesigWalletList = walletProvider.walletItemList
              .where((wallet) => wallet.walletType == WalletType.singleSignature)
              .toList();

          var confirmedBalance = walletProvider.getUtxoList(1).fold<int>(0, (sum, utxo) {
            if (utxo.status == UtxoStatus.unspent) {
              return sum + utxo.amount;
            }
            return sum;
          });
          debugPrint('confirmedBalance: $confirmedBalance');
          return SafeArea(
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Container(
                    width: MediaQuery.sizeOf(context).width,
                    padding: const EdgeInsets.only(left: 28, right: 28, top: 30, bottom: 60),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        if (walletProvider.walletItemList.isNotEmpty &&
                            singlesigWalletList.isNotEmpty) ...[
                          Stack(
                            children: [
                              Column(
                                children: [
                                  _buildWalletSelectionWidget(),
                                  _divider(),
                                  _buildDonationAmountInfoWidget(),
                                  _divider(),
                                ],
                              ),
                              if (isSyncing)
                                // 동기화 중일 때
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Container(
                                      alignment: Alignment.topCenter,
                                      color: CoconutColors.black.withOpacity(0.6),
                                      child: const CoconutCircularIndicator(
                                        size: 150,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        _buildDonationAddressWidget(),
                      ],
                    ),
                  ),
                ),
                if (walletProvider.walletItemList.isNotEmpty) ...[
                  FixedBottomButton(
                    onButtonClicked: () {
                      if (!isNetworkConnected) {
                        CoconutToast.showWarningToast(
                            context: context, text: ErrorCodes.networkError.message);
                        return;
                      }
                    },
                    isActive: !isSyncing,
                    text: t.next,
                    backgroundColor: CoconutColors.gray100,
                    pressedBackgroundColor: CoconutColors.gray500,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _divider() {
    return const Column(
      children: [
        CoconutLayout.spacing_400h,
        Divider(
          height: 1,
          color: CoconutColors.gray600,
        ),
        CoconutLayout.spacing_400h,
      ],
    );
  }

  Widget _buildWalletSelectionWidget() {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            t.donation.donation_wallet,
            style: CoconutTypography.body2_14_Bold.setColor(
              CoconutColors.white,
            ),
          ),
          Text(
            '',
            style: CoconutTypography.body2_14_NumberBold.setColor(
              CoconutColors.gray400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationAmountInfoWidget() {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                // TODO 후원금액 - 수수료
                t.donation.total_donation_amount,
                style: CoconutTypography.body2_14_Bold.setColor(
                  CoconutColors.white,
                ),
              ),
              Text(
                '${totalDonationAmount ?? '-'} sats',
                style: CoconutTypography.body2_14_NumberBold.setColor(
                  CoconutColors.gray400,
                ),
              ),
            ],
          ),
          CoconutLayout.spacing_300h,
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.donation.donation_amount,
                  style: CoconutTypography.body2_14_Bold.setColor(
                    CoconutColors.white,
                  ),
                ),
                Text(
                  '${widget.donationAmount} ${t.sats}',
                  style: CoconutTypography.body2_14_NumberBold.setColor(
                    CoconutColors.gray400,
                  ),
                ),
              ],
            ),
          ),
          CoconutLayout.spacing_300h,
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.fee,
                  style: CoconutTypography.body2_14_Bold.setColor(
                    CoconutColors.white,
                  ),
                ),
                Text(
                  // TODO 수수료
                  '${feeValue ?? '-'} ${t.sats}',
                  style: CoconutTypography.body2_14_NumberBold.setColor(
                    CoconutColors.gray400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationAddressWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            t.donation.donation_address,
            style: CoconutTypography.body2_14_Bold.setColor(
              CoconutColors.white,
            ),
          ),
        ),
        CoconutLayout.spacing_500h,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
            child: QrImageView(
              backgroundColor: CoconutColors.white,
              // TODO: QR Data
              data: 'bc1q3hyfj96kcmzlkfpxqxs6f0nksqf7rc9tfzkdqk',
              version: QrVersions.auto,
            ),
          ),
        ),
        CoconutLayout.spacing_600h,
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: CopyTextContainer(
            // TODO: QR Data
            text: 'bc1q3hyfj96kcmzlkfpxqxs6f0nksqf7rc9tfzkdqk',
            textStyle: CoconutTypography.body2_14,
          ),
        ),
      ],
    );
  }

  // 후원 잔액이 충분한 지갑 확인 함수
  // bool isBalanceEnough(int? estimatedFee) {
  //   if (estimatedFee == null || estimatedFee == 0) return false;
  //   return (_confirmedBalance - estimatedFee) > dustLimit;
  // }

  // void saveFinalSendInfo(int estimatedFee, int satsPerVb) {
  //   double finalAmount =
  //       _isMaxMode ? UnitUtil.satoshiToBitcoin(_confirmedBalance - estimatedFee) : _amount;
  //   _sendInfoProvider.setAmount(finalAmount);
  //   _sendInfoProvider.setEstimatedFee(estimatedFee);
  //   _sendInfoProvider.setTransaction(_createTransaction(satsPerVb));
  //   _sendInfoProvider.setFeeBumpfingType(null);
  //   _sendInfoProvider.setWalletImportSource(_walletListItemBase.walletImportSource);
  // }
}
