import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
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
  final bool animateEntry;

  const BroadcastingCompleteScreen({super.key, required this.id, required this.txHash, this.animateEntry = false});

  @override
  State<BroadcastingCompleteScreen> createState() => _BroadcastingCompleteScreenState();
}

class _BroadcastingCompleteScreenState extends State<BroadcastingCompleteScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late final AnimationController _completionLottieController;
  final TextEditingController _memoController = TextEditingController();
  final FocusNode _memoFocusNode = FocusNode();
  final GlobalKey _memoTagsKey = GlobalKey();
  double _memoTagsHeight = 0;
  late bool _showEntryActions;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: context.coconutColors.background,
          body: SafeArea(child: _buildBroadcastingCompleteScreen()),
        ),
      ),
    );
  }

  Widget _buildBroadcastingCompleteScreen() {
    return Stack(
      alignment: Alignment.center,
      children: [
        SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height:
                      _memoFocusNode.hasFocus && MediaQuery.of(context).viewInsets.bottom > 0
                          ? MediaQuery.of(context).size.height * 0.1
                          : MediaQuery.of(context).size.height * 0.3,
                ),
                if (widget.animateEntry)
                  Lottie.asset(
                    'assets/lottie/spinning-check.json',
                    controller: _completionLottieController,
                    width: 70,
                    height: 70,
                    repeat: false,
                    onLoaded: (composition) {
                      _completionLottieController.duration = composition.duration;
                      _completionLottieController.value = 1;
                    },
                  )
                else
                  SvgPicture.asset('assets/svg/completion-check.svg'),
                CoconutLayout.spacing_400h,
                Text(
                  t.broadcasting_complete_screen.complete,
                  style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.primaryText),
                ),
                CoconutLayout.spacing_400h,
                _CompletionEntryTransition(visible: _showEntryActions, child: _buildMemoInputField()),
                if (!_memoFocusNode.hasFocus && _memoController.text.isNotEmpty)
                  _CompletionEntryTransition(visible: _showEntryActions, child: _buildMemoReadOnlyText()),
                if (_memoFocusNode.hasFocus && MediaQuery.of(context).viewInsets.bottom > 0) ...[
                  CoconutLayout.spacing_1200h,
                  _buildMemoTags(),
                ],
              ],
            ),
          ),
        ),
        // if (_memoFocusNode.hasFocus && MediaQuery.of(context).viewInsets.bottom > 0)
        //   Positioned(bottom: Sizes.size16, child: _buildMemoTags()),
        _CompletionEntryTransition(
          visible: _showEntryActions,
          child: FixedBottomButton(
            showSurroundings: false,
            isVisibleAboveKeyboard: false,
            onButtonClicked: () => onTapConfirmButton(context),
            text: t.confirm,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _completionLottieController.dispose();
    _memoFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _showEntryActions = !widget.animateEntry;
    _animationController = BottomSheet.createAnimationController(this);
    _completionLottieController = AnimationController(vsync: this, value: 1);
    _animationController.duration = const Duration(seconds: 2);
    if (widget.animateEntry) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _showEntryActions = true);
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          Provider.of<SendInfoProvider>(context, listen: false).clear();
        }
      });
    } else {
      Provider.of<SendInfoProvider>(context, listen: false).clear();
    }
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
    if (memo.isNotEmpty && !context.read<TransactionProvider>().updateTransactionMemo(widget.id, widget.txHash, memo)) {
      CoconutToast.showToast(
        context: context,
        isVisibleIcon: true,
        iconPath: 'assets/svg/triangle-warning.svg',
        text: t.toast.memo_update_failed,
        level: CoconutToastLevel.warning,
      );
      return;
    }

    Future<dynamic>? showReviewScreenFuture = AppReviewService.showReviewScreenIfFirstSending(
      context,
      animationController: _animationController,
    );
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
        _memoController.selection = TextSelection.fromPosition(TextPosition(offset: _memoController.text.length));
        _memoFocusNode.requestFocus();
      },
      child: IntrinsicWidth(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Sizes.size12, vertical: Sizes.size4),
          decoration: BoxDecoration(
            color: context.coconutColors.inputSurface,
            borderRadius: BorderRadius.circular(Sizes.size24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/svg/pen.svg',
                colorFilter: ColorFilter.mode(context.coconutColors.inputPlaceholder, BlendMode.srcIn),
                width: Sizes.size12,
              ),
              CoconutLayout.spacing_100w,
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  TextUtils.ellipsisIfLonger(_memoController.text, maxLength: 8),
                  style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText),
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
            color: context.coconutColors.inputSurface,
            borderRadius: BorderRadius.circular(Sizes.size24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/svg/pen.svg',
                colorFilter: ColorFilter.mode(context.coconutColors.inputPlaceholder, BlendMode.srcIn),
                width: Sizes.size12,
              ),
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
                    style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText),
                    cursorColor: context.coconutColors.primaryText,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: t.broadcasting_complete_screen.memo_placeholder,
                      hintStyle: CoconutTypography.body1_16.setColor(context.coconutColors.inputPlaceholder),
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
          padding: const EdgeInsets.symmetric(horizontal: Sizes.size8, vertical: Sizes.size4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Sizes.size14),
            border: Border.all(width: 1, color: context.coconutColors.tertiaryText),
          ),
          child: Text(text, style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText)),
        ),
      ),
    );
  }
}

class _CompletionEntryTransition extends StatelessWidget {
  const _CompletionEntryTransition({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !visible,
    child: AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 0.18),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(opacity: visible ? 1 : 0, duration: const Duration(milliseconds: 240), child: child),
    ),
  );
}
