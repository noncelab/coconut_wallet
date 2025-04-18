import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:flutter/cupertino.dart';

class ButtonContainer extends StatelessWidget {
  final Widget child;

  const ButtonContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: defaultBoxDecoration,
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24), child: child));
  }
}
