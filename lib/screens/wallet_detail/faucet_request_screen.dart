import 'package:coconut_wallet/model/data/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/viewModel/wallet_detail/faucet_request_view_model.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
import 'package:coconut_wallet/widgets/textfield/custom_text_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FaucetRequestScreen extends StatefulWidget {
  final WalletListItemBase walletBaseItem;
  final VoidCallback? onRequestSuccess;

  const FaucetRequestScreen({
    super.key,
    required this.walletBaseItem,
    required this.onRequestSuccess,
  });

  @override
  State<FaucetRequestScreen> createState() => _FaucetRequestScreenState();
}

class _FaucetRequestScreenState extends State<FaucetRequestScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FaucetRequestViewModel(widget.walletBaseItem),
      child: Consumer<FaucetRequestViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isErrorInStatus) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              CustomToast.showWarningToast(
                  context: context, text: '요청에 실패했습니다. 잠시후 다시 시도해 주세요.');
              viewModel.setErrorInStatus(false);
            });
          }
          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: MyColors.white),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                        const Text(
                          '테스트 비트코인 받기',
                          style: Styles.body1,
                        ),
                        Visibility(
                          visible: false,
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          maintainSemantics: false,
                          maintainInteractivity: false,
                          child: IconButton(
                            icon:
                                const Icon(Icons.close, color: MyColors.white),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 30),
                        const Text(
                          '받을 주소',
                          style: Styles.body1Bold,
                        ),
                        const SizedBox(height: 10),
                        CustomTextField(
                            controller: viewModel.textController,
                            placeholder:
                                "주소를 입력해 주세요.\n주소는 [받기] 버튼을 눌러서 확인할 수 있어요.",
                            onChanged: (text) {
                              viewModel.validateAddress(text.toLowerCase());
                            },
                            maxLines: 2,
                            style: Styles.body1.merge(TextStyle(
                                fontFamily: CustomFonts.number.getFontFamily))),
                        const SizedBox(height: 2),
                        const SizedBox(height: 2),
                        Visibility(
                          visible: !viewModel.isErrorInAddress,
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          maintainSemantics: false,
                          maintainInteractivity: false,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '내 지갑(${viewModel.walletName}) 주소 - ${viewModel.walletIndex}',
                              style: Styles.body2Number,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  IgnorePointer(
                    ignoring: (viewModel.isErrorInAddress ||
                        viewModel.isRequesting ||
                        viewModel.isErrorInRemainingTime),
                    child: CupertinoButton(
                        onPressed: viewModel.canRequestFaucet
                            ? () async {
                                if (viewModel.isLoading) {
                                  CustomToast.showToast(
                                      context: context,
                                      text: '서버 상태를 확인하는 중입니다. 잠시만 기다려 주세요.');
                                }

                                if (viewModel.canRequestFaucet) {
                                  await viewModel
                                      .requestTestBitcoin((success, message) {
                                    _onFaucetRequestResult(
                                        context, success, message);
                                    if (success) {
                                      widget.onRequestSuccess!();
                                    }
                                  });
                                  // await viewModel
                                  //     .startFaucetRequest(widget.onRequestSuccess!);
                                }
                                FocusScope.of(context).unfocus();
                              }
                            : null,
                        borderRadius: BorderRadius.circular(8.0),
                        padding: EdgeInsets.zero,
                        color: viewModel.canRequestFaucet
                            ? MyColors.white
                            : MyColors.transparentWhite_30,
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 12),
                            child: Text(
                              viewModel.isRequesting
                                  ? '요청 중...'
                                  : '${formatNumber(viewModel.requestAmount)} BTC 요청하기',
                              style: Styles.label.merge(TextStyle(
                                  color: (viewModel.isErrorInAddress ||
                                          viewModel.isRequesting ||
                                          viewModel.isLoading)
                                      ? MyColors.transparentBlack_50
                                      : MyColors.black,
                                  letterSpacing: -0.1,
                                  fontWeight: FontWeight.w600)),
                            ))),
                  ),
                  const SizedBox(height: 4),
                  if (viewModel.isErrorInAddress) ...{
                    _buildWarningMessage('올바른 주소인지 확인해 주세요'),
                  } else if (viewModel.isErrorInRemainingTime) ...{
                    _buildWarningMessage(
                        '${viewModel.remainingTimeString} 후에 다시 시도해 주세요'),
                  }
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _onFaucetRequestResult(
      BuildContext context, bool success, String message) {
    if (success) {
      vibrateLight();
    } else {
      vibrateMedium();
    }
    CustomToast.showToast(context: context, text: message);
  }

  Widget _buildWarningMessage(String message) {
    return Text(
      message,
      style: Styles.caption2.merge(
        const TextStyle(
          color: MyColors.warningRed,
        ),
      ),
    );
  }
}
