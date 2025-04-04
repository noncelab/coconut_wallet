import 'package:flutter/cupertino.dart';

import '../styles.dart';

class Label extends StatelessWidget {
  final String text;

  const Label({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Styles.label);
  }
}

class ValueText extends StatelessWidget {
  final String text;

  const ValueText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: Styles.body1.merge(const TextStyle(fontFamily: 'SpaceGrotesk', letterSpacing: 0)));
  }
}
