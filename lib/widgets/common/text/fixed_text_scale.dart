import 'package:flutter/material.dart';

class FixedTextScale extends StatelessWidget {
  final Widget child;
  final double scale;

  const FixedTextScale({super.key, required this.child, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    return MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child);
  }
}
