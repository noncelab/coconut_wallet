import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/bubble_clipper.dart';
import 'package:flutter/cupertino.dart';

class FaucetTooltip extends StatefulWidget {
  final String text;
  final double width;
  final bool isVisible;
  final Offset iconPosition;
  final Size iconSize;
  final Function onTapRemove;
  const FaucetTooltip({
    super.key,
    required this.text,
    required this.width,
    required this.isVisible,
    this.iconPosition = Offset.zero,
    this.iconSize = Size.zero,
    required this.onTapRemove,
  });

  @override
  State<FaucetTooltip> createState() => _FaucetTooltipState();
}

class _FaucetTooltipState extends State<FaucetTooltip> {
  bool _isOpacity = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 100));
      _isOpacity = true;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: widget.isVisible,
      child: Positioned(
        top: widget.iconPosition.dy + widget.iconSize.height - 10,
        right:
            widget.width - widget.iconPosition.dx - widget.iconSize.width + 5,
        child: AnimatedOpacity(
          opacity: _isOpacity ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 1000),
          child: GestureDetector(
            onTap: () {
              widget.onTapRemove();
            },
            child: ClipPath(
              clipper: RightTriangleBubbleClipper(),
              child: Container(
                padding: const EdgeInsets.only(
                  top: 25,
                  left: 18,
                  right: 18,
                  bottom: 10,
                ),
                color: MyColors.skybule,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.text,
                      style: Styles.caption.merge(TextStyle(
                        height: 1.3,
                        fontFamily: CustomFonts.text.getFontFamily,
                        color: MyColors.darkgrey,
                      )),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
