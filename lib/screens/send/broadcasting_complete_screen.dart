import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/services/app_review_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class BroadcastingCompleteScreen extends StatefulWidget {
  final int id;

  const BroadcastingCompleteScreen({super.key, required this.id});

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
          child: Center(
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
