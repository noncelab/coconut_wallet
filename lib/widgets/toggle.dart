import 'package:flutter/cupertino.dart';
import 'package:coconut_wallet/ui/coconut/coconut_toggle_row.dart';

class ToggleWidget extends StatefulWidget {
  final String toggleName;
  final bool initialValue;
  final ValueChanged<bool>? onChanged;

  const ToggleWidget({super.key, required this.toggleName, this.initialValue = false, this.onChanged});

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
    return CoconutToggleRow(
      toggleName: widget.toggleName,
      initialValue: _value,
      onChanged: (newValue) {
        setState(() {
          _value = newValue;
        });
        widget.onChanged?.call(newValue);
      },
    );
  }
}
