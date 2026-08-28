import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class SizeReportingWidget extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onSizeChanged;

  const SizeReportingWidget({super.key, required this.onSizeChanged, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return SizeReportingRenderObject(onSizeChanged);
  }

  @override
  void updateRenderObject(BuildContext context, covariant SizeReportingRenderObject renderObject) {
    renderObject.onSizeChanged = onSizeChanged;
  }
}

class SizeReportingRenderObject extends RenderProxyBox {
  SizeReportingRenderObject(this.onSizeChanged);

  ValueChanged<Size> onSizeChanged;
  Size? _reportedSize;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _reportedSize) return;
    _reportedSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onSizeChanged(size));
  }
}
