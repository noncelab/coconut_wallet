import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:qr_flutter/qr_flutter.dart';

class AnimatedQrView extends StatefulWidget {
  final List<String> data;
  final double size;
  final int milliSeconds;

  const AnimatedQrView(
      {super.key, required this.data, required this.size, this.milliSeconds = 500});

  @override
  State<AnimatedQrView> createState() => _AnimatedQrViewState();
}

class _AnimatedQrViewState extends State<AnimatedQrView> {
  int dataIndex = 0;
  // Timer
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(milliseconds: widget.milliSeconds), (timer) {
      setState(() {
        dataIndex = (dataIndex + 1) % widget.data.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return QrImageView(data: widget.data[dataIndex], size: widget.size, version: 11);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}
