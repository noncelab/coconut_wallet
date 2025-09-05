import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/services/app_review_service.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/ripple_effect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

class BroadcastingCompleteScreen extends StatefulWidget {
  final int id;
  final String txHash;
  final bool isDonation;

  const BroadcastingCompleteScreen(
      {super.key, required this.id, required this.txHash, this.isDonation = false});

  @override
  State<BroadcastingCompleteScreen> createState() => _BroadcastingCompleteScreenState();
}

class _BroadcastingCompleteScreenState extends State<BroadcastingCompleteScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  final TextEditingController _memoController = TextEditingController();
  final FocusNode _memoFocusNode = FocusNode();
  final GlobalKey _memoTagsKey = GlobalKey();
  double _memoTagsHeight = 0;

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
        SingleChildScrollView(
          child: SizedBox(
            height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: _memoFocusNode.hasFocus && MediaQuery.of(context).viewInsets.bottom > 0
                      ? MediaQuery.of(context).size.height * 0.1
                      : MediaQuery.of(context).size.height * 0.3,
                ),
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
                if (_memoFocusNode.hasFocus && MediaQuery.of(context).viewInsets.bottom > 0) ...[
                  CoconutLayout.spacing_1200h,
                  _buildMemoTags()
                ]
              ],
            ),
          ),
        ),
        // if (_memoFocusNode.hasFocus && MediaQuery.of(context).viewInsets.bottom > 0)
        //   Positioned(bottom: Sizes.size16, child: _buildMemoTags()),
        FixedBottomButton(
            showGradient: false,
            isVisibleAboveKeyboard: false,
            onButtonClicked: () => onTapConfirmButton(context),
            text: t.confirm),
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
      if (_memoFocusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _memoTagsKey.currentContext;
          if (ctx != null) {
            final box = ctx.findRenderObject() as RenderBox?;
            final height = box?.size.height ?? 0;
            if (height != _memoTagsHeight) {
              setState(() {
                _memoTagsHeight = height;
              });
            }
          }
        });
      }
      setState(() {}); // 기존 갱신 유지
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
    return Container(
      key: _memoTagsKey,
      padding: const EdgeInsets.symmetric(horizontal: Sizes.size12),
      width: MediaQuery.of(context).size.width,
      child: Wrap(
        alignment: WrapAlignment.center,
        children: [
          _buildMemoTag(t.broadcasting_complete_screen.memo_tags[0]),
          _buildMemoTag(t.broadcasting_complete_screen.memo_tags[1]),
          _buildMemoTag(t.broadcasting_complete_screen.memo_tags[2]),
          _buildMemoTag(t.broadcasting_complete_screen.memo_tags[3]),
          _buildMemoTag(t.broadcasting_complete_screen.memo_tags[4]),
          _buildMemoTag(t.broadcasting_complete_screen.memo_tags[5]),
          _buildMemoTag(t.broadcasting_complete_screen.memo_tags[6]),
        ],
      ),
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
      child: IntrinsicWidth(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Sizes.size12, vertical: Sizes.size4),
          decoration: BoxDecoration(
            color: CoconutColors.gray800,
            borderRadius: BorderRadius.circular(Sizes.size24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset('assets/svg/pen.svg',
                  colorFilter: const ColorFilter.mode(CoconutColors.gray350, BlendMode.srcIn),
                  width: Sizes.size12),
              CoconutLayout.spacing_100w,
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  TextUtils.ellipsisIfLonger(_memoController.text, maxLength: 8),
                  style: CoconutTypography.body3_12.setColor(CoconutColors.gray100),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemoInputField() {
    final showInput = _memoFocusNode.hasFocus || _memoController.text.isEmpty;

    return Visibility(
      visible: showInput,
      maintainState: true,
      child: IntrinsicWidth(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Sizes.size12, vertical: Sizes.size4),
          decoration: BoxDecoration(
            color: CoconutColors.gray800,
            borderRadius: BorderRadius.circular(Sizes.size24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset('assets/svg/pen.svg',
                  colorFilter: const ColorFilter.mode(CoconutColors.gray350, BlendMode.srcIn),
                  width: Sizes.size12),
              CoconutLayout.spacing_100w,
              Flexible(
                fit: FlexFit.loose,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 48, maxWidth: 160),
                  child: TextField(
                    controller: _memoController,
                    focusNode: _memoFocusNode,
                    maxLines: 1,
                    textAlignVertical: TextAlignVertical.center,
                    style: CoconutTypography.body3_12.setColor(CoconutColors.gray100),
                    cursorColor: CoconutColors.white,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: t.broadcasting_complete_screen.memo_placeholder,
                      hintStyle: CoconutTypography.body3_12.setColor(CoconutColors.gray350),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemoTag(String text) {
    return Padding(
      padding: const EdgeInsets.all(Sizes.size4),
      child: RippleEffect(
          borderRadius: Sizes.size14,
          onTap: () {
            _memoController.text = text;
          },
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
              text,
              style: CoconutTypography.caption_10.setColor(CoconutColors.gray300),
            ),
          )),
    );
  }
}
