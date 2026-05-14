import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/cupertino.dart';

class CoconutToggleRow extends StatefulWidget {
  final String toggleName;
  final bool initialValue;
  final ValueChanged<bool>? onChanged;

  const CoconutToggleRow({super.key, required this.toggleName, this.initialValue = false, this.onChanged});

  @override
  State<CoconutToggleRow> createState() => _CoconutToggleRowState();
}

class _CoconutToggleRowState extends State<CoconutToggleRow> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final typography = context.coconutTypography;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(child: Text(widget.toggleName, style: typography.body.copyWith(color: colors.primaryText))),
        CupertinoSwitch(
          value: _value,
          onChanged: (newValue) {
            setState(() {
              _value = newValue;
            });
            widget.onChanged?.call(newValue);
          },
          activeTrackColor: colors.primary.withValues(alpha: 0.8),
        ),
      ],
    );
  }
}
