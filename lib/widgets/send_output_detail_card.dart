import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/send_output_detail_row.dart';
import 'package:flutter/material.dart';

class OutputDetailItem {
  final String label;
  final String address;
  final int amountSats;
  final bool isChange;

  const OutputDetailItem({
    required this.label,
    required this.address,
    required this.amountSats,
    required this.isChange,
  });
}

class SendOutputDetailCard extends StatefulWidget {
  final List<OutputDetailItem> items;
  final bool initiallyExpanded;

  const SendOutputDetailCard({
    super.key,
    required this.items,
    this.initiallyExpanded = true,
  });

  @override
  State<SendOutputDetailCard> createState() => _SendOutputDetailCardState();
}

class _SendOutputDetailCardState extends State<SendOutputDetailCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: MyColors.transparentWhite_06),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.send_confirm_screen.output_detail_title,
                  style: CoconutTypography.body3_12_Bold.copyWith(color: CoconutColors.white),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: ScaleTransition(scale: animation, child: child));
                    },
                    child: Icon(
                      _isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                      key: ValueKey(_isExpanded),
                      color: CoconutColors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 12),
            ...List.generate(widget.items.length, (index) {
              final item = widget.items[index];
              final isLast = index == widget.items.length - 1;
              return Column(
                children: [
                  SendOutputDetailRow(
                    label: item.label,
                    address: item.address,
                    amountSats: item.amountSats,
                    isChange: item.isChange,
                  ),
                  if (!isLast) ...[
                    const SizedBox(height: 16),
                    const Divider(color: CoconutColors.gray700, height: 1),
                    const SizedBox(height: 16),
                  ],
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}
