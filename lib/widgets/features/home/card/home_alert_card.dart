import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/ccos/open_store/coconut_open_store_content.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/common/buttons/positioned_card_close_button.dart';
import 'package:coconut_wallet/widgets/features/ccos/card/coconut_open_store_intro_card.dart';
import 'package:flutter/material.dart';

/// [securityIncident]는 위급 사건 배너(백업 경고와 같은 빨간 카드, 닫기 없음)
enum HomeAlertCardType { mnemonicBackup, appLock, openStore, securityIncident }

class HomeAlertCard extends StatefulWidget {
  static const contentPadding = EdgeInsets.fromLTRB(16, 16, 8, 16);

  const HomeAlertCard.security({
    super.key,
    required this.type,
    required this.showDelay,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    required this.onClosed,
    this.topSpacing = 16,
    this.reserveSpaceOnShow = false,
  }) : assert(type != HomeAlertCardType.openStore),
       intro = null;

  const HomeAlertCard.openStore({
    super.key,
    required this.showDelay,
    required CcosOpenStoreIntro this.intro,
    required this.onTap,
    required this.onClosed,
  }) : type = HomeAlertCardType.openStore,
       topSpacing = 16,
       reserveSpaceOnShow = false,
       title = null,
       description = null,
       icon = null;

  final HomeAlertCardType type;
  final Duration showDelay;
  final String? title;
  final String? description;
  final Widget? icon;
  final CcosOpenStoreIntro? intro;
  final VoidCallback onTap;

  /// null이면 닫기 버튼을 그리지 않는다(위급 사건은 인지·완료될 때만 사라진다)
  final VoidCallback? onClosed;

  /// 카드가 나타날 때 위에 함께 펼쳐지는 여백.
  final double topSpacing;

  /// 자동 스크롤 중 뒤늦은 높이 변화가 생기지 않도록 등장 공간을 미리 확보한다.
  final bool reserveSpaceOnShow;

  @override
  State<HomeAlertCard> createState() => _HomeAlertCardState();
}

class _HomeAlertCardState extends State<HomeAlertCard> with SingleTickerProviderStateMixin {
  static const _animationDuration = Duration(milliseconds: 240);
  static const _securityIconSize = 20.0;

  late final AnimationController _controller;
  late final Animation<double> _animation;
  Timer? _showDelayTimer;
  bool _closing = false;

  /// 동작 줄이기면 펼치기·접기 없이 최종 모습으로 바로 바뀐다
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _animationDuration);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    _showDelayTimer = Timer(widget.showDelay, () {
      if (!mounted) return;
      _reduceMotion ? _controller.value = 1 : _controller.forward(from: 0);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
    // 펼치는 도중에 켜지면 끝 모습으로. 접는 중이면 그대로 둔다(멈추면 닫기 콜백이 오지 않음)
    if (_reduceMotion && _controller.status == AnimationStatus.forward) _controller.value = 1;
  }

  @override
  void dispose() {
    _showDelayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    setState(() => _closing = true);
    _showDelayTimer?.cancel();
    if (_reduceMotion) {
      _controller.value = 0;
    } else {
      await _controller.reverse();
    }
    if (mounted) widget.onClosed?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.type != HomeAlertCardType.openStore) {
      return AnimatedBuilder(
        animation: _animation,
        builder: (context, _) => _buildAnimatedSecurityCard(context, _animation.value),
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final value = _animation.value;
        return ClipRect(
          child: Align(
            heightFactor: value,
            child: Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 4 * (1 - value)),
                child: Transform.scale(scale: 0.96 + (0.04 * value), child: child),
              ),
            ),
          ),
        );
      },
      child: _buildOpenStoreCard(),
    );
  }

  Widget _buildAnimatedSecurityCard(BuildContext context, double value) {
    final layoutFactor = widget.reserveSpaceOnShow && !_closing ? 1.0 : value;
    return IgnorePointer(
      ignoring: value == 0,
      child: Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 4 * (1 - value)),
          child: Transform.scale(
            scale: 0.96 + (0.04 * value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: widget.topSpacing * layoutFactor),
                _buildSecurityCard(context, heightFactor: layoutFactor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOpenStoreCard() {
    return CoconutOpenStoreIntroCard(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      intro: widget.intro!,
      onTap: widget.onTap,
      onDismiss: _close,
    );
  }

  Widget _buildSecurityCard(BuildContext context, {required double heightFactor}) {
    final isRed = widget.type != HomeAlertCardType.appLock;
    final textColor =
        isRed ? context.coconutColors.unbackedWarningForeground : context.coconutColors.appLockWarningForeground;
    final titleStyle = CoconutTypography.body1_16_Bold.setColor(textColor);
    final titleLineHeight =
        TextPainter(
          text: TextSpan(text: ' ', style: titleStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        ).preferredLineHeight;
    final calculatedIconTop = (titleLineHeight - _securityIconSize) / 2;
    final iconTop = calculatedIconTop > 0 ? calculatedIconTop : 0.0;
    final calculatedCloseIconTop = (titleLineHeight - PositionedCardCloseButton.defaultIconSize) / 2;
    final closeIconTop = calculatedCloseIconTop > 0 ? calculatedCloseIconTop : 0.0;
    final closeButtonTop = HomeAlertCard.contentPadding.top + closeIconTop - PositionedCardCloseButton.padding.top;
    final iconColor = isRed ? context.coconutColors.iconOnDanger : context.coconutColors.appLockWarningForeground;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isRed ? null : context.coconutColors.appLockWarningBackground,
          gradient:
              isRed
                  ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [context.coconutColors.danger, const Color(0xFFE18A99)],
                  )
                  : null,
          borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
        ),
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: heightFactor,
          child: Stack(
            children: [
              Padding(
                padding: HomeAlertCard.contentPadding.copyWith(
                  right:
                      widget.onClosed == null
                          ? HomeAlertCard.contentPadding.left
                          : PositionedCardCloseButton.contentRightInset,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(padding: EdgeInsets.only(top: iconTop), child: widget.icon!),
                    CoconutLayout.spacing_200w,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title!, style: titleStyle),
                          const SizedBox(height: 4),
                          Text(widget.description!, style: CoconutTypography.body3_12_Bold.setColor(textColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onClosed != null)
                PositionedCardCloseButton(onPressed: _close, color: iconColor, positionTop: closeButtonTop),
            ],
          ),
        ),
      ),
    );
  }
}
