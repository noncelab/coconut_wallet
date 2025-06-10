import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/services/app_review_service.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

class BroadcastingCompleteScreen extends StatefulWidget {
  final int id;
  final bool isDonation;

  const BroadcastingCompleteScreen({super.key, required this.id, this.isDonation = false});

  @override
  State<BroadcastingCompleteScreen> createState() => _BroadcastingCompleteScreenState();
}

class _BroadcastingCompleteScreenState extends State<BroadcastingCompleteScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: CoconutColors.black,
        body: SafeArea(
          child: widget.isDonation
              ? _buildDonationCompleteScreen()
              : _buildBroadcastingCompleteScreen(),
        ),
      ),
    );
  }

  Widget _buildDonationCompleteScreen() {
    return Stack(
      children: [
        SizedBox(
          width: MediaQuery.sizeOf(context).width,
          height: MediaQuery.sizeOf(context).height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CoconutLayout.spacing_2500h,
              Lottie.asset(
                'assets/lottie/thankyou-hearts.json',
              ),
              CoconutLayout.spacing_800h,
              Text(
                t.donation.complete.thank_you,
                style: CoconutTypography.heading3_21_Bold,
              ),
              CoconutLayout.spacing_500h,
              Text(
                t.donation.complete.description,
                textAlign: TextAlign.center,
                style: CoconutTypography.body2_14,
              ),
            ],
          ),
        ),
        FixedBottomButton(
          onButtonClicked: () {
            onTap(context);
          },
          // 버튼 보이지 않을 때: 수수료 조회에 실패, 잔액이 충분한 지갑이 없음
          // 비활성화 상태로 보일 때: 지갑 동기화 진행 중, 수수료 조회 중,
          // 활성화 상태로 보일 때: 모든 지갑 동기화 완료, 지갑별 수수료 조회 성공
          text: t.close,
          backgroundColor: CoconutColors.gray100,
          pressedBackgroundColor: CoconutColors.gray500,
        ),
      ],
    );
  }

  Widget _buildBroadcastingCompleteScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SvgPicture.asset('assets/svg/completion-check.svg'),
          const SizedBox(height: 8),
          Text(
            t.broadcasting_complete_screen.complete,
            style: CoconutTypography.heading4_18_Bold.setColor(CoconutColors.white),
          ),
          const SizedBox(
            height: 40,
          ),
          GestureDetector(
              onTap: () => onTap(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14), color: CoconutColors.primary),
                child: Text(t.confirm,
                    style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.gray800)),
              )),
          const SizedBox(
            height: 40,
          ),
        ],
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
    debugPrint('isSending: ${widget.isDonation}');
    _animationController = BottomSheet.createAnimationController(this);
    _animationController.duration = const Duration(seconds: 2);
    Provider.of<SendInfoProvider>(context, listen: false).clear();
  }

  void onTap(BuildContext context) {
    if (widget.isDonation) {
      Navigator.pop(context);
      return;
    }

    Future<dynamic>? showReviewScreenFuture = AppReviewService.showReviewScreenIfFirstSending(
        context,
        animationController: _animationController);
    if (showReviewScreenFuture == null) {
      Navigator.pop(context);
    } else {
      showReviewScreenFuture.whenComplete(() {
        if (context.mounted) {
          Navigator.pop(context);
        }
      });
    }
  }
}
