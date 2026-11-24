import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_board.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/design_system/tokens/coconut_colors.dart' as tokens;
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_expiry_text.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 아크 알아보기
class ArkAboutScreen extends StatefulWidget {
  const ArkAboutScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: AnalyticsScreenNames.ccosArkWalletAbout),
      builder: (_) => const ArkAboutScreen(),
    ),
  );

  @override
  State<ArkAboutScreen> createState() => _ArkAboutScreenState();
}

class _ArkAboutScreenState extends State<ArkAboutScreen> {
  ArkBoardTerms? _terms;

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  /// 서버마다 다른 숫자, 못 받으면 숫자 없는 문장
  Future<void> _loadTerms() async {
    try {
      final terms = await context.read<ArkWalletProvider>().boardTerms();
      if (mounted) setState(() => _terms = terms);
    } catch (error) {
      Logger.error('ArkAboutScreen: board terms failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final unit = context.select<ArkWalletProvider, BitcoinUnit>((wallet) => wallet.unit);
    final terms = _terms;
    final lifetime = terms?.vtxoLifetimeBlocks;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(context: context, backgroundColor: colors.background, title: t.ark_wallet.about_row),
      body: Column(
        children: [
          ValueListenableBuilder<double>(
            valueListenable: _readProgress,
            builder:
                (context, progress, _) => LinearProgressIndicator(
                  key: const Key('ark-about-progress'),
                  value: progress,
                  minHeight: 2,
                  backgroundColor: colors.divider,
                  color: colors.primaryText,
                ),
          ),
          Expanded(
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: (notification) {
                _updateProgress(notification.metrics);
                return false;
              },
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  _updateProgress(notification.metrics);
                  return false;
                },
                child: _content(colors, unit, terms, lifetime),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 읽은 만큼, 끝까지 내리면 1
  final _readProgress = ValueNotifier<double>(0);

  void _updateProgress(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return;
    _readProgress.value = metrics.maxScrollExtent <= 0 ? 1 : (metrics.pixels / metrics.maxScrollExtent).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _readProgress.dispose();
    super.dispose();
  }

  Widget _content(tokens.CoconutColors colors, BitcoinUnit unit, ArkBoardTerms? terms, int? lifetime) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        _Section(
          title: t.ark_wallet.about_intro_title,
          paragraphs: [
            t.ark_wallet.about_intro_1,
            t.ark_wallet.about_intro_2,
            t.ark_wallet.about_intro_key,
            t.ark_wallet.about_intro_3,
          ],
        ),
        _Section(title: t.ark_wallet.about_shared_title, paragraphs: [t.ark_wallet.about_shared_1]),
        _Section(
          title: t.ark_wallet.about_vtxo_title,
          paragraphs: [t.ark_wallet.about_vtxo_1, t.ark_wallet.about_vtxo_2],
          diagramsAfter: const {0: _SharedUtxoDiagram(), 1: _TxChainDiagram()},
        ),
        _Section(
          title: t.ark_wallet.about_expiry_title,
          paragraphs: [
            t.ark_wallet.about_expiry_1,
            t.ark_wallet.about_expiry_3,
            lifetime == null
                ? t.ark_wallet.about_expiry_2_plain
                : t.ark_wallet.about_expiry_2(time: arkBlocksText(lifetime)),
          ],
          diagram: const _ExpiryDiagram(),
        ),
        _Section(
          title: t.ark_wallet.about_fill_title,
          paragraphs: [
            terms == null
                ? t.ark_wallet.about_fill_1_plain
                : t.ark_wallet.about_fill_1(
                  n: terms.requiredConfirmations,
                  amount: unit.displayBitcoinAmount(terms.minimumSats, withUnit: true),
                ),
            t.ark_wallet.about_fill_2,
          ],
        ),
        _Section(
          title: t.ark_wallet.about_out_title,
          paragraphs: [t.ark_wallet.about_out_1, t.ark_wallet.about_out_2, t.ark_wallet.about_out_3],
        ),
        _Section(
          title: t.ark_wallet.about_ln_title,
          paragraphs: [t.ark_wallet.about_ln_1, t.ark_wallet.about_ln_2, t.ark_wallet.about_ln_3],
          last: true,
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.paragraphs,
    this.diagram,
    this.diagramsAfter = const {},
    this.last = false,
  });

  final String title;
  final List<String> paragraphs;
  final Widget? diagram;

  /// 문단 번호 뒤에 넣는 그림
  final Map<int, Widget> diagramsAfter;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: CoconutTypography.body1_16_Bold.setColor(colors.primaryText)),
          CoconutLayout.spacing_300h,
          for (final (index, paragraph) in paragraphs.indexed) ...[
            if (index > 0) CoconutLayout.spacing_300h,
            _richText(paragraph, colors),
            if (diagramsAfter[index] case final diagram?) ...[
              CoconutLayout.spacing_600h,
              diagram,
              CoconutLayout.spacing_300h,
            ],
          ],
          if (diagram != null) ...[CoconutLayout.spacing_600h, diagram!],
        ],
      ),
    );
  }
}

/// `**`로 감싼 부분은 굵게
Widget _richText(String text, tokens.CoconutColors colors) => Text.rich(
  TextSpan(
    children: [
      for (final (index, part) in text.split('**').indexed)
        TextSpan(
          text: TextUtils.preventLineBreakInsideWords(part),
          style: index.isOdd ? CoconutTypography.body2_14_Bold.setColor(colors.primaryText) : null,
        ),
    ],
  ),
  style: CoconutTypography.body2_14.setColor(colors.secondaryTextStrong),
);

/// 그림을 담는 칸
class _DiagramCard extends StatelessWidget {
  const _DiagramCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: context.coconutColors.surface, borderRadius: BorderRadius.circular(16)),
      child: child,
    );
  }
}

/// 나눠 쓰는 UTXO 하나와 그 안의 내 VTXO
class _SharedUtxoDiagram extends StatelessWidget {
  const _SharedUtxoDiagram();

  static const _shares = [3, 1, 4, 2];
  static const _gap = 4.0;
  static const _boxPadding = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final accent = colors.primary;
    return _DiagramCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inner = constraints.maxWidth - _boxPadding * 2 - _gap * (_shares.length - 1);
          final mine = inner * _shares.first / _shares.reduce((a, b) => a + b);
          final arrowX = _boxPadding + mine / 2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.ark_wallet.about_diagram_utxo, style: CoconutTypography.body3_12.setColor(colors.tertiaryText)),
              CoconutLayout.spacing_200h,
              Container(
                padding: const EdgeInsets.all(_boxPadding),
                decoration: BoxDecoration(
                  color: colors.surfaceInset,
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    for (final (index, share) in _shares.indexed) ...[
                      if (index > 0) const SizedBox(width: _gap),
                      Expanded(
                        flex: share,
                        child: Container(
                          height: 32,
                          decoration: BoxDecoration(
                            color: index == 0 ? accent : colors.border,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: arrowX - 1),
                child: Row(
                  children: [
                    CustomPaint(size: const Size(2, 56), painter: _DashedArrowPainter(color: accent)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.ark_wallet.about_diagram_my_vtxo,
                            style: CoconutTypography.body3_12_Bold.setColor(accent),
                          ),
                          CoconutLayout.spacing_50h,
                          Text(
                            t.ark_wallet.about_diagram_exit,
                            style: CoconutTypography.body3_12.setColor(colors.secondaryText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: _boxPadding),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.surfaceInset,
                    border: Border.all(color: accent),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    t.ark_wallet.about_diagram_my_address,
                    style: CoconutTypography.body3_12.setColor(colors.primaryText),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 보낸 사람의 VTXO에서 이어진 내 VTXO와 꺼내는 길
class _TxChainDiagram extends StatelessWidget {
  const _TxChainDiagram();

  static const _shares = [3, 1, 4, 2];
  static const _gap = 4.0;
  static const _boxPadding = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final accent = colors.primary;
    return _DiagramCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inner = constraints.maxWidth - _boxPadding * 2 - _gap * (_shares.length - 1);
          final first = inner * _shares.first / _shares.reduce((a, b) => a + b);
          final x = _boxPadding + first / 2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.ark_wallet.about_diagram_utxo, style: CoconutTypography.body3_12.setColor(colors.tertiaryText)),
              CoconutLayout.spacing_200h,
              Container(
                padding: const EdgeInsets.all(_boxPadding),
                decoration: BoxDecoration(
                  color: colors.surfaceInset,
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    for (final (index, share) in _shares.indexed) ...[
                      if (index > 0) const SizedBox(width: _gap),
                      Expanded(
                        flex: share,
                        child: Container(
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: index == 0 ? colors.secondaryText : colors.border,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:
                              index == 0
                                  ? FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      t.ark_wallet.about_diagram_sender,
                                      style: CoconutTypography.caption_10_Bold.setColor(colors.background),
                                    ),
                                  )
                                  : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _edge(x, colors.secondaryText, t.ark_wallet.about_diagram_tx, colors.secondaryText, dashed: false),
              _node(
                t.ark_wallet.about_diagram_my_vtxo,
                accent,
                CoconutTypography.body3_12_Bold.setColor(accent),
                colors,
              ),
              _edge(x, accent, t.ark_wallet.about_diagram_exit, colors.secondaryText, dashed: true),
              _node(
                t.ark_wallet.about_diagram_my_address,
                accent,
                CoconutTypography.body3_12.setColor(colors.primaryText),
                colors,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _edge(double x, Color color, String label, Color labelColor, {required bool dashed}) => Padding(
    padding: EdgeInsets.only(left: x - 1),
    child: Row(
      children: [
        CustomPaint(size: const Size(2, 48), painter: _DashedArrowPainter(color: color, dashed: dashed)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: CoconutTypography.body3_12.setColor(labelColor))),
      ],
    ),
  );

  Widget _node(String label, Color border, TextStyle style, tokens.CoconutColors colors) => Padding(
    padding: const EdgeInsets.only(left: _boxPadding),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceInset,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: style),
    ),
  );
}

/// 위에서 아래로 내려가는 화살표
class _DashedArrowPainter extends CustomPainter {
  _DashedArrowPainter({required this.color, this.dashed = true});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
    final x = size.width / 2;
    final end = size.height - 6;
    if (dashed) {
      for (double y = 4; y < end; y += 8) {
        canvas.drawLine(Offset(x, y), Offset(x, (y + 4).clamp(0, end)), paint);
      }
    } else {
      canvas.drawLine(Offset(x, 0), Offset(x, end), paint);
    }
    canvas.drawLine(Offset(x - 5, size.height - 9), Offset(x, size.height - 3), paint);
    canvas.drawLine(Offset(x + 5, size.height - 9), Offset(x, size.height - 3), paint);
  }

  @override
  bool shouldRepaint(_DashedArrowPainter oldDelegate) => oldDelegate.color != color || oldDelegate.dashed != dashed;
}

/// 갱신한 경우와 안 한 경우의 기한
class _ExpiryDiagram extends StatelessWidget {
  const _ExpiryDiagram();

  static const _before = 6;
  static const _after = 4;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final accent = colors.primary;
    return _DiagramCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(
            colors,
            label: t.ark_wallet.about_diagram_renewed,
            after: accent.withValues(alpha: 0.45),
            afterLabel: t.ark_wallet.about_diagram_extended,
            afterLabelColor: accent,
            accent: accent,
          ),
          CoconutLayout.spacing_500h,
          _row(
            colors,
            label: t.ark_wallet.about_diagram_not_renewed,
            after: colors.border,
            afterLabel: t.ark_wallet.about_diagram_server_can_take,
            afterLabelColor: colors.tertiaryText,
            accent: accent,
          ),
        ],
      ),
    );
  }

  Widget _row(
    tokens.CoconutColors colors, {
    required String label,
    required Color after,
    required String afterLabel,
    required Color afterLabelColor,
    required Color accent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: CoconutTypography.body3_12_Bold.setColor(colors.secondaryText)),
        CoconutLayout.spacing_200h,
        Row(
          children: [
            Expanded(flex: _before, child: _bar(accent)),
            const SizedBox(width: 4),
            Expanded(flex: _after, child: _bar(after)),
          ],
        ),
        CoconutLayout.spacing_100h,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(flex: _before),
            const SizedBox(width: 4),
            Expanded(
              flex: _after,
              child: Text(afterLabel, style: CoconutTypography.body3_12.setColor(afterLabelColor)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bar(Color color) =>
      Container(height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)));
}
