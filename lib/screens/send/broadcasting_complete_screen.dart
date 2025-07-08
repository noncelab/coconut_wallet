import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/services/app_review_service.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

class BroadcastingCompleteScreen extends StatefulWidget {
  final int id;
  final String txHash;
  final bool isDonation;

  const BroadcastingCompleteScreen({super.key, required this.id, required this.txHash, this.isDonation = false});

  @override
  State<BroadcastingCompleteScreen> createState() => _BroadcastingCompleteScreenState();
}

class _BroadcastingCompleteScreenState extends State<BroadcastingCompleteScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  final TextEditingController _memoController = TextEditingController();
  final FocusNode _memoFocusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: CoconutColors.black,
          body: SafeArea(
            child: widget.isDonation
                ? _buildDonationCompleteScreen()
                : _buildBroadcastingCompleteScreen(),
          ),
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
            Navigator.pop(context);
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
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
        top: MediaQuery.of(context).size.height * 0.15,
        child: Column(
          children: [
            SvgPicture.asset('assets/svg/completion-check.svg'),
                                  CoconutLayout.spacing_400h,

            Text(
                        t.broadcasting_complete_screen.complete,
                        style: CoconutTypography.heading4_18_Bold.setColor(CoconutColors.white),
                      ),
                      CoconutLayout.spacing_400h,
            _buildMemoInputField(),
                      if (!_memoFocusNode.hasFocus && _memoController.text.isNotEmpty)
                        _buildMemoReadOnlyText(),
          ],
        ),
      ),
      if (_memoFocusNode.hasFocus)
      Positioned(
          bottom: MediaQuery.of(context).viewInsets.bottom + Sizes.size16,
          child: _buildMemoTags()),
      Positioned(
                  bottom: Sizes.size24,
                  left: Sizes.size16,
                  right: Sizes.size16,
                  child: CoconutButton(
                    onPressed: () => onTapConfirmButton(context),
                    textStyle: CoconutTypography.body2_14_Bold.setColor(CoconutColors.gray800),
                    disabledBackgroundColor: CoconutColors.gray800,
                    disabledForegroundColor: CoconutColors.gray700,
                    backgroundColor: CoconutColors.primary,
                    foregroundColor: CoconutColors.black,
                    pressedTextColor: CoconutColors.black,
                    text: t.confirm,
                  ),
                ),
      ],
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _memoFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    debugPrint('isSending: ${widget.isDonation}');
    _animationController = BottomSheet.createAnimationController(this);
    _animationController.duration = const Duration(seconds: 2);
    Provider.of<SendInfoProvider>(context, listen: false).clear();
    _memoFocusNode.addListener(() {
      setState(() {});
    });
  }

  void onTapConfirmButton(BuildContext context) {
    // 메모가 있는 경우 업데이트 시도
    final memo = _memoController.text.trim();
    if (memo.isNotEmpty &&
        !context
            .read<TransactionProvider>()
            .updateTransactionMemo(widget.id, widget.txHash, memo)) {
      CoconutToast.showWarningToast(
        context: context,
        text: t.toast.memo_update_failed,
      );
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

  Widget _buildMemoTags() {
    return Column(
      children: [
        Row(
          children: [
            _buildMemoTag(t.broadcasting_complete_screen.memo_tags[0]),
            _buildMemoTag(t.broadcasting_complete_screen.memo_tags[1]),
            _buildMemoTag(t.broadcasting_complete_screen.memo_tags[2]),
          ],
        ),
        Row(
          children: [
            _buildMemoTag(t.broadcasting_complete_screen.memo_tags[3]),
            _buildMemoTag(t.broadcasting_complete_screen.memo_tags[4]),
            _buildMemoTag(t.broadcasting_complete_screen.memo_tags[5]),
            _buildMemoTag(t.broadcasting_complete_screen.memo_tags[6]),
          ],
        ),
      ],
    );
  }

  Widget _buildMemoReadOnlyText() {
    return GestureDetector(
      onTap: () {
        _memoController.selection = TextSelection.fromPosition(
          TextPosition(offset: _memoController.text.length),
        );
        _memoFocusNode.requestFocus();
      },
      child: Padding(
        padding: const EdgeInsets.only(top: Sizes.size4),
        child: Container(
            height: Sizes.size24,
            padding: const EdgeInsets.only(left: Sizes.size12, right: Sizes.size12),
            decoration: BoxDecoration(
              color: CoconutColors.gray800,
              borderRadius: BorderRadius.circular(Sizes.size12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset('assets/svg/pen.svg',
                    colorFilter: const ColorFilter.mode(CoconutColors.gray350, BlendMode.srcIn),
                    width: Sizes.size12),
                CoconutLayout.spacing_100w,
                Text(
                  TextUtils.ellipsisIfLonger(_memoController.text, maxLength: 8),
                  style: CoconutTypography.body3_12.setColor(CoconutColors.gray100),
                ),
              ],
            )),
      ),
    );
  }

  Widget _buildMemoInputField() {
    double? memoInputFieldSize =
        _memoFocusNode.hasFocus || _memoController.text.isEmpty ? null : 0.0;
    return SizedBox(
      width: memoInputFieldSize,
      height: memoInputFieldSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // background
          Container(
            width: Sizes.size84,
            height: Sizes.size24,
            padding: const EdgeInsets.only(left: Sizes.size12, right: Sizes.size12),
            decoration: BoxDecoration(
              color: CoconutColors.gray800,
              borderRadius: BorderRadius.circular(Sizes.size12),
            ),
          ),
          Row(
            children: [
              SvgPicture.asset('assets/svg/pen.svg',
                  colorFilter: const ColorFilter.mode(CoconutColors.gray350, BlendMode.srcIn),
                  width: Sizes.size12),
              CoconutLayout.spacing_100w,
              // text field
              SizedBox(
                  width: Sizes.size48,
                  height: Sizes.size32,
                  child: TextField(
                    controller: _memoController,
                    focusNode: _memoFocusNode,
                    style: CoconutTypography.body3_12.setColor(CoconutColors.gray100),
                    cursorColor: CoconutColors.white,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: t.broadcasting_complete_screen.memo_placeholder,
                      hintStyle: CoconutTypography.body3_12.setColor(CoconutColors.gray350),
                      contentPadding: const EdgeInsets.only(
                        bottom: 15.5,
                      ),
                    ),
                  )),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMemoTag(String text) {
    return Padding(
      padding: const EdgeInsets.all(Sizes.size4),
      child: _MemoTagItem(
          text: text,
          onTap: () {
            _memoController.text = text;
          }),
    );
  }
}

class _MemoTagItem extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;

  const _MemoTagItem({required this.text, this.onTap});

  @override
  State<_MemoTagItem> createState() => _MemoTagItemState();
}

class _MemoTagItemState extends State<_MemoTagItem> {
  double _opacity = 1.0;

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _opacity = 0.5;
    });
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() {
      _opacity = 1.0;
    });
  }

  void _handleTapCancel() {
    setState(() {
      _opacity = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(Sizes.size14),
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          opacity: _opacity,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Sizes.size8,
              vertical: Sizes.size4,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Sizes.size14),
              border: Border.all(width: 1, color: CoconutColors.gray600),
            ),
            child: Text(
              widget.text,
              style: CoconutTypography.caption_10.setColor(CoconutColors.gray300),
            ),
          ),
        ),
      ),
    );
  }
}
