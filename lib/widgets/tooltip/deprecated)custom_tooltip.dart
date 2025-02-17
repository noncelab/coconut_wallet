import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:coconut_wallet/styles.dart';

enum TooltipType {
  info('info', 4, 'assets/svg/tooltip/info.svg'),
  normal('normal', 8, 'assets/svg/tooltip/normal.svg'),
  success('success', 3, 'assets/svg/tooltip/success.svg'),
  warning('warning', 2, 'assets/svg/tooltip/warning.svg'),
  error('error', 5, 'assets/svg/tooltip/error.svg');

  const TooltipType(this.code, this.colorIndex, this.svgPath);
  final String code;
  final int colorIndex;
  final String svgPath;

  factory TooltipType.getByCode(String code) {
    return TooltipType.values.firstWhere((value) => value.code == code);
  }
}

@Deprecated('Use CoconutTooltip instead')
class CustomTooltip extends StatefulWidget {
  final RichText richText;
  final TooltipType type;
  final bool showIcon;
  final double marginHorizontal;
  final Color backgroundColor;

  const CustomTooltip(
      {super.key,
      required this.richText,
      this.type = TooltipType.info,
      required this.showIcon,
      this.marginHorizontal = 16.0,
      this.backgroundColor = Colors.transparent});

  @override
  State<CustomTooltip> createState() => _CustomTooltipState();
}

class _CustomTooltipState extends State<CustomTooltip> {
  late Color _borderColor;
  late Color _backgroundColor;
  late SvgPicture _icon;

  @override
  void initState() {
    super.initState();
    _borderColor = ColorPalette[widget.type.colorIndex];
    _backgroundColor =
        BackgroundColorPalette[widget.type.colorIndex].withOpacity(0.18);
    _icon = SvgPicture.asset(widget.type.svgPath,
        colorFilter: ColorFilter.mode(_borderColor, BlendMode.srcIn),
        width: 18);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0),
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(width: 0.4, color: _borderColor)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (widget.showIcon)
                Container(
                  padding: const EdgeInsets.only(right: 8),
                  child: _icon,
                ),
              Expanded(child: widget.richText)
            ])));
  }
}
