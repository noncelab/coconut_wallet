import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/card/taproot_participant_card.dart';
import 'package:flutter/material.dart';

class TaprootSetupSummaryCard extends StatelessWidget {
  static const double _guideLineX = 18;
  static const double _sectionIndent = 32;
  static const double _cardSpacing = 4;
  static const double _sectionSpacing = 25;
  static const double _sectionTitleSpacing = 8;

  final List<TaprootParticipantCard> itemList;
  final TaprootSetupSummaryCardType taprootSetupSummaryCardType; // 카드 타입, 트리 타입, 컬럼 타입 중 선택(default: 카드타입)

  const TaprootSetupSummaryCard({
    super.key,
    required this.itemList,
    this.taprootSetupSummaryCardType = TaprootSetupSummaryCardType.card,
  });

  @override
  Widget build(BuildContext context) {
    final isCardType = taprootSetupSummaryCardType == TaprootSetupSummaryCardType.card;
    final processedList = isCardType ? itemList.map((item) => item.copyWith(useNewline: true)).toList() : itemList;

    final signerItems = processedList.where((item) => item.locktime == null).toList();
    final inheritanceItems = processedList.where((item) => item.locktime != null).toList();

    if (taprootSetupSummaryCardType == TaprootSetupSummaryCardType.card) {
      return _buildCardTypeLayout(signerItems, inheritanceItems);
    }
    if (taprootSetupSummaryCardType == TaprootSetupSummaryCardType.tree) {
      return _buildTreeTypeLayout(signerItems, inheritanceItems);
    }
    return _buildColumnTypeLayout(signerItems, inheritanceItems);
  }

  Widget _buildCardTypeLayout(List<TaprootParticipantCard> signerItems, List<TaprootParticipantCard> inheritanceItems) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Container(
        decoration: BoxDecoration(
          color: CoconutColors.gray850,
          border: Border.all(color: CoconutColors.gray850, width: 1),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: CoconutColors.black.withValues(alpha: 0.02),
              offset: const Offset(2, 2),
              blurRadius: 4,
              spreadRadius: 6,
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: _buildColumnTypeLayout(signerItems, inheritanceItems),
      ),
    );
  }

  Widget _buildTreeTypeLayout(List<TaprootParticipantCard> signerItems, List<TaprootParticipantCard> inheritanceItems) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _GuideSpacer(height: 20, showGuideLine: true),
        _SummarySection(
          title: t.taproot.setup_summary_card.signer_configuration,
          isLastSection: inheritanceItems.isEmpty,
          showGuideLine: true,
          children: signerItems,
        ),
        if (inheritanceItems.isNotEmpty) ...[
          const _GuideSpacer(height: _sectionSpacing, showGuideLine: true),
          _SummarySection(
            title: t.taproot.setup_summary_card.inheritance_condition,
            isLastSection: true,
            showGuideLine: true,
            children: inheritanceItems,
          ),
        ],
      ],
    );
  }

  Widget _buildColumnTypeLayout(
    List<TaprootParticipantCard> signerItems,
    List<TaprootParticipantCard> inheritanceItems,
  ) {
    return Column(
      children: [
        _SummarySection(
          title: t.taproot.setup_summary_card.signer_configuration,
          isLastSection: inheritanceItems.isEmpty,
          children: signerItems,
        ),
        CoconutLayout.spacing_400h,
        const Divider(height: 1, color: CoconutColors.gray800),
        if (inheritanceItems.isNotEmpty) ...[
          CoconutLayout.spacing_400h,
          _SummarySection(
            title: t.taproot.setup_summary_card.inheritance_condition,
            isLastSection: true,
            children: inheritanceItems,
          ),
        ],
      ],
    );
  }
}

class _GuideContentRow extends StatelessWidget {
  final Widget child;
  final bool showGuideLine;
  final bool showBranch;
  final bool isLastGuideRow;

  const _GuideContentRow({
    required this.child,
    this.showGuideLine = false,
    this.showBranch = false,
    this.isLastGuideRow = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showGuideLine || showBranch)
            SizedBox(
              width: TaprootSetupSummaryCard._sectionIndent,
              child: CustomPaint(
                painter: _GuideRailPainter(
                  showGuideLine: showGuideLine,
                  showBranch: showBranch,
                  drawBottom: !isLastGuideRow,
                  isRoundedEnd: isLastGuideRow,
                ),
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  final String title;
  final List<TaprootParticipantCard> children;
  final bool isLastSection;
  final bool showGuideLine;

  const _SummarySection({
    required this.title,
    required this.children,
    this.isLastSection = false,
    this.showGuideLine = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GuideContentRow(
          showGuideLine: showGuideLine,
          child: Text(title, style: CoconutTypography.body3_12_Bold.setColor(CoconutColors.white)),
        ),
        _GuideSpacer(height: TaprootSetupSummaryCard._sectionTitleSpacing, showGuideLine: showGuideLine),
        for (int index = 0; index < children.length; index++) ...[
          if (index > 0) _GuideSpacer(height: TaprootSetupSummaryCard._cardSpacing, showGuideLine: showGuideLine),
          _GuideContentRow(
            showGuideLine: showGuideLine,
            showBranch: showGuideLine,
            isLastGuideRow: isLastSection && index == children.length - 1,
            child: children[index],
          ),
        ],
      ],
    );
  }
}

class _GuideSpacer extends StatelessWidget {
  final double height;
  final bool showGuideLine;

  const _GuideSpacer({required this.height, this.showGuideLine = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: TaprootSetupSummaryCard._sectionIndent,
            child: CustomPaint(painter: _GuideRailPainter(showGuideLine: showGuideLine)),
          ),
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

class _GuideRailPainter extends CustomPainter {
  static const double _cornerRadius = 14;

  final bool showGuideLine;
  final bool showBranch;
  final bool drawBottom;
  final bool isRoundedEnd;

  const _GuideRailPainter({
    this.showGuideLine = false,
    this.showBranch = false,
    this.drawBottom = true,
    this.isRoundedEnd = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!showGuideLine && !showBranch) {
      return;
    }

    final paint =
        Paint()
          ..color = CoconutColors.gray200
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;

    const lineX = TaprootSetupSummaryCard._guideLineX;
    const branchEndX = TaprootSetupSummaryCard._sectionIndent;
    final centerY = size.height / 2;

    if (isRoundedEnd && showBranch) {
      final radius = _cornerRadius.clamp(0, centerY);
      final path =
          Path()
            ..moveTo(lineX, 0)
            ..lineTo(lineX, centerY - radius)
            ..quadraticBezierTo(lineX, centerY, lineX + radius, centerY)
            ..lineTo(branchEndX, centerY);
      canvas.drawPath(path, paint);
      return;
    }

    if (showGuideLine) {
      canvas.drawLine(const Offset(lineX, 0), Offset(lineX, drawBottom ? size.height : centerY), paint);
    }

    if (showBranch) {
      canvas.drawLine(Offset(lineX, centerY), Offset(branchEndX, centerY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GuideRailPainter oldDelegate) {
    return oldDelegate.showGuideLine != showGuideLine ||
        oldDelegate.showBranch != showBranch ||
        oldDelegate.drawBottom != drawBottom ||
        oldDelegate.isRoundedEnd != isRoundedEnd;
  }
}

enum TaprootSetupSummaryCardType { card, tree, column }
