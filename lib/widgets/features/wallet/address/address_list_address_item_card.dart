import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/cupertino.dart';

class AddressItemCard extends StatelessWidget {
  final VoidCallback onPressed;

  final String address;
  final String derivationPath;
  final bool isUsed;
  final bool isWatched;
  final int? balanceInSats;
  final BitcoinUnit currentUnit;
  const AddressItemCard({
    super.key,
    required this.onPressed,
    required this.address,
    required this.derivationPath,
    required this.isUsed,
    required this.isWatched,
    required this.currentUnit,
    this.balanceInSats,
  });

  @override
  Widget build(BuildContext context) {
    var path = derivationPath.split('/');
    var index = path[path.length - 1];

    return CupertinoButton(
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      pressedOpacity: 0.8,
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: context.coconutColors.surface),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: context.coconutColors.surfaceInset,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isWatched) ...[_WatchedGlowDot(color: context.coconutColors.success), const SizedBox(width: 4)],
                  Text(
                    index,
                    style: CoconutTypography.caption_10
                        .setColor(context.coconutColors.secondaryText)
                        .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${address.substring(0, 10)}...${address.substring(address.length - 10, address.length)}',
                      style: CoconutTypography.body1_16_Number.setColor(
                        isUsed ? context.coconutColors.primaryText : context.coconutColors.mutedText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentUnit.displayBitcoinAmount(balanceInSats, withUnit: true),
                      style: CoconutTypography.body2_14_Number
                          .setColor(
                            balanceInSats == 0 ? context.coconutColors.mutedText : context.coconutColors.primaryText,
                          )
                          .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  ],
                ),
              ),
            ),
            CoconutLayout.spacing_200w,
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: context.coconutColors.surfaceInfoChip,
                ),
                child: Text(
                  isUsed ? t.status_used : t.status_unused,
                  style: CoconutTypography.caption_10.setColor(
                    isUsed ? context.coconutColors.accentForeground : context.coconutColors.secondaryText,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchedGlowDot extends StatefulWidget {
  final Color color;
  const _WatchedGlowDot({required this.color});

  @override
  State<_WatchedGlowDot> createState() => _WatchedGlowDotState();
}

class _WatchedGlowDotState extends State<_WatchedGlowDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.2 + 0.4 * t),
                blurRadius: 1 + 3 * t,
                spreadRadius: 0.5 + 1.5 * t,
              ),
            ],
          ),
        );
      },
    );
  }
}
