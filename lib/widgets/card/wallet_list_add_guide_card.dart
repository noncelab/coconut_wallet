import 'package:coconut_wallet/styles.dart';
import 'package:flutter/cupertino.dart';

class WalletListAddGuideCard extends StatefulWidget {
  final VoidCallback onPressed;

  const WalletListAddGuideCard({
    super.key,
    required this.onPressed,
  });

  @override
  State<WalletListAddGuideCard> createState() => _WalletListAddGuideCardState();
}

class _WalletListAddGuideCardState extends State<WalletListAddGuideCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.maxFinite,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: MyColors.transparentWhite_12),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.only(top: 26, bottom: 24, left: 26, right: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '보기 전용 지갑을 추가해 주세요',
            style: Styles.title5,
          ),
          const Text(
            '오른쪽 위 + 버튼을 눌러도 추가할 수 있어요',
            style: Styles.label,
          ),
          const SizedBox(height: 16),
          CupertinoButton(
            onPressed: widget.onPressed,
            borderRadius: BorderRadius.circular(10),
            padding: EdgeInsets.zero,
            color: MyColors.primary,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 12,
              ),
              child: Text(
                '바로 추가하기',
                style: Styles.label.merge(
                  const TextStyle(
                    color: MyColors.black,
                    fontWeight: FontWeight.w700,
                    // fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
