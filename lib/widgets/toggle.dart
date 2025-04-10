import 'package:flutter/cupertino.dart';
import 'package:coconut_wallet/styles.dart';

class ToggleWidget extends StatefulWidget {
  final String toggleName;
  final bool initialValue;
  final ValueChanged<bool>? onChanged;

  const ToggleWidget({
    super.key,
    required this.toggleName,
    this.initialValue = false,
    this.onChanged,
  });

  @override
  State<ToggleWidget> createState() => _ToggleWidgetState();
}

class _ToggleWidgetState extends State<ToggleWidget> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
            child: Text(widget.toggleName,
                style: Styles.subLabel.merge(const TextStyle(color: MyColors.defaultText)))),
        CupertinoSwitch(
          value: _value,
          onChanged: (newValue) {
            setState(() {
              _value = newValue;
            });
            if (widget.onChanged != null) {
              widget.onChanged!(newValue);
            }
          },
          activeColor: MyColors.primary.withOpacity(0.8),
        )
      ],
    );
  }
}
