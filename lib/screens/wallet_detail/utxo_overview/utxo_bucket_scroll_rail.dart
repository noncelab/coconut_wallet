import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/model/utxo/utxo_bucket.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class UtxoBucketScrollRail extends StatelessWidget {
  final List<UtxoBucket> buckets;
  final ScrollController scrollController;
  final ValueListenable<int> activeIndexListenable;
  final ValueListenable<double> activeBucketY;

  const UtxoBucketScrollRail({
    super.key,
    required this.buckets,
    required this.scrollController,
    required this.activeIndexListenable,
    required this.activeBucketY,
  });

  static const double _indicatorHeight = 18.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final parentHeight = constraints.maxHeight;

        return ListenableBuilder(
          listenable: Listenable.merge([activeIndexListenable, activeBucketY]),
          builder: (_, __) {
            final targetY = activeBucketY.value;
            final maxTop = (parentHeight - _indicatorHeight).clamp(0.0, double.infinity);
            final top = (targetY - _indicatorHeight / 2).clamp(0.0, maxTop);

            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(child: Container(width: 1, color: CoconutColors.gray800)),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  top: top,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 8,
                      height: _indicatorHeight,
                      decoration: BoxDecoration(color: CoconutColors.gray500, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
