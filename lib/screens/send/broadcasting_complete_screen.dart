import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/app_review_service.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class BroadcastingCompleteScreen extends StatefulWidget {
  final int id;
  final String txId;

  const BroadcastingCompleteScreen(
      {super.key, required this.id, required this.txId});

  @override
  State<BroadcastingCompleteScreen> createState() =>
      _BroadcastingCompleteScreenState();
}

class _BroadcastingCompleteScreenState extends State<BroadcastingCompleteScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: MyColors.black,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SvgPicture.asset('assets/svg/completion-check.svg'),
                const SizedBox(height: 8),
                const Text(
                  "전송 요청 완료",
                  style: Styles.h3,
                ),
                const SizedBox(
                  height: 40,
                ),
                // SmallActionButton(
                //     text: '트랜잭션 보기',
                //     onPressed: () => launchUrl(Uri.parse(
                //         "${CoconutWalletApp.kMempoolHost}/tx/${widget.txId}"))),
                // const SizedBox(
                //   height: 120,
                // ),
                GestureDetector(
                  onTap: () => onTap(context),
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: MyColors.primary),
                      child: Text(
                        '확인',
                        style: Styles.label.merge(const TextStyle(
                            color: MyColors.darkgrey,
                            fontWeight: FontWeight.bold)),
                      )),
                ),
                const SizedBox(
                  height: 40,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _animationController = BottomSheet.createAnimationController(this);
    _animationController.duration = const Duration(seconds: 2);
    Provider.of<SendInfoProvider>(context, listen: false).clear();
  }

  void onTap(BuildContext context) {
    // 보내는 중 tx list 조회를 위한 조치
    Provider.of<WalletProvider>(context, listen: false)
        .initWallet(targetId: widget.id);
    Future<dynamic>? showReviewScreenFuture =
        AppReviewService.showReviewScreenIfFirstSending(context,
            animationController: _animationController);
    if (showReviewScreenFuture == null) {
      Navigator.pop(context);
    } else {
      showReviewScreenFuture.whenComplete(() {
        Navigator.pop(context);
      });
    }
  }
}
