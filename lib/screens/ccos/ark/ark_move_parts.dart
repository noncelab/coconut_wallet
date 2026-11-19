import 'package:coconut_design_system/coconut_design_system.dart'
    hide CoconutAppBar, CoconutToast, CoconutToastLevel, CoconutTextField;
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/config/number_format_config.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/common/flutter_hot_wallet_authenticator.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/numeric_input_formatters.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/widgets/common/info/info_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

/// 채우기·내보내기의 금액 칸(코코넛 입력칸). 바로 숫자를 입력, 안쪽 오른쪽에 [최대], 금액이 있으면 지우기
class ArkMoveAmountBox extends StatefulWidget {
  const ArkMoveAmountBox({
    super.key,
    this.label,
    required this.amountSats,
    required this.onAmount,
    required this.onMax,
    this.isError = false,
  });

  /// 없으면 금액 칸만, 채우기·내보내기 카드 안에서
  final String? label;
  final int? amountSats;

  /// 보내기 화면처럼 금액과 테두리를 경고 색으로
  final bool isError;
  final void Function(int? amountSats) onAmount;
  final VoidCallback onMax;

  @override
  State<ArkMoveAmountBox> createState() => _ArkMoveAmountBoxState();
}

class _ArkMoveAmountBoxState extends State<ArkMoveAmountBox> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  static int? _parse(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : int.tryParse(digits);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final unit = context.select<ArkWalletProvider, BitcoinUnit>((wallet) => wallet.unit);
    final amount = widget.amountSats;
    if (_parse(_controller.text) != amount) {
      _controller.text = amount == null ? '' : unit.displayBitcoinAmount(amount);
    }
    final unitStyle = CoconutTypography.body2_14_Number.setColor(
      widget.isError ? colors.dangerText : colors.primaryText,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
          CoconutLayout.spacing_200h,
        ],
        CoconutTextField(
          key: const Key('ark-move-amount'),
          controller: _controller,
          focusNode: _focusNode,
          textInputType: TextInputType.number,
          fontFamily: unitStyle.fontFamily!,
          textInputFormatter: const [SatoshiAmountInputFormatter()],
          onChanged: (text) {
            final sats = _parse(text);
            if (sats != widget.amountSats) widget.onAmount(sats);
          },
          placeholderText: t.ark_wallet.set_amount,
          maxLines: 1,
          isLengthVisible: false,
          padding: EdgeInsets.only(left: unit.isPrefixSymbol ? 0 : 16, right: 8),
          backgroundColor: colors.inputSurface,
          isError: widget.isError,
          textColor: widget.isError ? colors.dangerText : null,
          clearButtonVisibility: CoconutTextFieldClearButtonVisibility.whenNotEmpty,
          ghostText: unit.isPrefixSymbol || amount == null ? '' : ' ${unit.symbol}',
          ghostTextColor: unitStyle.color,
          onClear: () => widget.onAmount(null),
          prefix:
              unit.isPrefixSymbol
                  ? Padding(
                    padding: const EdgeInsets.only(left: 16, right: 4),
                    child: Transform.translate(offset: const Offset(0, -1), child: Text(unit.symbol, style: unitStyle)),
                  )
                  : null,
          suffix: CoconutButton(
            key: const Key('ark-move-max'),
            text: t.max,
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: widget.onMax,
            backgroundColor: colors.surfaceButton,
            foregroundColor: colors.surfaceButtonText,
          ),
        ),
      ],
    );
  }
}

/// 인증 → 실행. 성공하면 토스트를 띄우고 [returnRoute]까지 닫고, 실패하면 경고 토스트. [onRunning]은 실행 중 표시용
Future<void> runArkMove(
  BuildContext context, {
  required Future<bool> Function(BuildContext context) authenticate,
  required Future<void> Function() run,
  required String doneMessage,
  required String failedMessage,
  required void Function(bool running) onRunning,
  String returnRoute = AnalyticsScreenNames.ccosArkWalletHome,
}) async {
  if (!await authenticate(context) || !context.mounted) return;
  onRunning(true);
  try {
    await run();
  } catch (error) {
    Logger.error('runArkMove: failed: $error');
    if (!context.mounted) return;
    onRunning(false);
    CoconutToast.showToast(
      context: context,
      text: failedMessage,
      isVisibleIcon: true,
      iconPath: CommonStateIconPath.triangleWarning,
      level: CoconutToastLevel.warning,
    );
    return;
  }
  if (!context.mounted) return;
  // 토스트는 앱 전체 오버레이에 떠서 아크 지갑 홈으로 돌아가도 남음
  CoconutToast.showToast(context: context, text: doneMessage, isVisibleIcon: true);
  Navigator.of(context).popUntil((route) => route.settings.name == returnRoute || route.isFirst);
}

/// 패스프레이즈 없는 지갑의 인증(앱 잠금·생체)
Future<bool> authenticateArkMove(BuildContext context) =>
    AppGuard.runWithoutPrivacyScreen(() => FlutterHotWalletAuthenticator(context).authenticate());

/// 보내기 화면과 같이 다음 버튼 위에 띄우는 오류 문구
Widget arkMoveProblemText(BuildContext context, String message) => Text(
  TextUtils.preventLineBreakInsideWords(message),
  textAlign: TextAlign.center,
  style: CoconutTypography.body3_12.setColor(context.coconutColors.dangerText),
);

/// 보내기 화면과 같은 수수료율 표시, 예: 2.0 sat/vB
String arkFeeRateText(num satPerVb) =>
    '${satPerVb.toStringAsFixed(1).replaceAll('.', NumberFormatConfig.instance.decimalSeparator)} ${t.send_screen.fee_rate_suffix}';

/// 채우기·내보내기의 흐름. 위에서 아래로 보내는 지갑(금액 칸) → 수수료 → 받는 지갑(들어오는 금액)
class ArkMoveRoute extends StatelessWidget {
  /// 수수료 한 줄과 총 소요 금액 한 줄 높이. 계산 전후로 카드 사이가 벌어지지 않게 미리 잡아 둠
  static const double _feeMinHeight = 44;

  const ArkMoveRoute({
    super.key,
    required this.fromName,
    required this.fromBalance,
    this.onFromTap,
    required this.amount,
    this.total,
    required this.fees,
    this.feeExtra,
    this.toName,
    this.toBalance,
    this.toLabel,
    this.toInput,
    this.onToTap,
    this.toDetail,
    this.arrival,
    this.arrivalDetail,
    this.isEstimating = false,
  });

  final String fromName;
  final String fromBalance;

  /// 있으면 보내는 지갑 이름 옆 화살표, 눌러서 지갑을 바꿈
  final VoidCallback? onFromTap;

  /// 보내는 지갑 카드 안의 금액 칸
  final Widget amount;

  /// 수수료까지 보내는 지갑에서 빠지는 금액, 화살표 옆 수수료 아래
  final String? total;

  /// 화살표 옆 수수료 줄들
  final List<String> fees;

  /// 수수료 줄 아래 더 붙일 것, 예: 수수료 낼 지갑
  final Widget? feeExtra;

  /// 둘 다 없으면 받는 쪽 카드에 [toInput]만, 주소를 직접 넣을 때
  final String? toName;
  final String? toBalance;
  final VoidCallback? onToTap;

  /// 받는 쪽 카드 제목, 없으면 받는 지갑
  final String? toLabel;

  /// 받는 쪽 카드 안의 입력 칸, 예: 주소 입력
  final Widget? toInput;

  /// 받는 지갑 이름 아래 작은 글자, 예: 받는 주소
  final String? toDetail;

  /// 받는 지갑에 들어오는 금액, 아직 모르면 없음
  final String? arrival;
  final String? arrivalDetail;
  final bool isEstimating;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final secondary = CoconutTypography.body3_12.setColor(colors.secondaryText);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ArkMoveCard(
          label: t.ark_wallet.fill_from,
          name: fromName,
          balance: fromBalance,
          onTap: onFromTap,
          changeKey: const Key('ark-move-from-change'),
          children: [CoconutLayout.spacing_300h, amount],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              SvgPicture.asset(
                FeatureArkIconPath.receive,
                width: 24,
                colorFilter: ColorFilter.mode(colors.secondaryText, BlendMode.srcIn),
              ),
              CoconutLayout.spacing_300w,
              Expanded(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: _feeMinHeight),
                    child:
                        isEstimating
                            ? Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox.square(
                                dimension: 12,
                                child: CircularProgressIndicator(strokeWidth: 2, color: colors.secondaryText),
                              ),
                            )
                            : Align(
                              alignment: Alignment.centerLeft,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final fee in fees) Text(fee, style: secondary),
                                  if (total != null) ...[
                                    CoconutLayout.spacing_100h,
                                    Row(
                                      children: [
                                        Text(
                                          t.ark_wallet.move_total,
                                          style: CoconutTypography.body2_14.setColor(colors.secondaryText),
                                        ),
                                        CoconutLayout.spacing_200w,
                                        Text(
                                          total!,
                                          key: const Key('ark-move-total'),
                                          style: CoconutTypography.body2_14_Number.setColor(colors.primaryText),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (feeExtra != null) feeExtra!,
                                ],
                              ),
                            ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _ArkMoveCard(
          label: toLabel ?? t.ark_wallet.export_to,
          name: toName,
          balance: toBalance,
          onTap: onToTap,
          changeKey: const Key('ark-move-to-change'),
          children: [
            if (toInput != null) ...[CoconutLayout.spacing_200h, toInput!],
            if (toDetail != null) ...[
              CoconutLayout.spacing_100h,
              Text(toDetail!, style: CoconutTypography.body3_12_Number.setColor(colors.secondaryText)),
            ],
            if (arrival != null) ...[
              CoconutLayout.spacing_300h,
              Text(
                '+ $arrival',
                key: const Key('ark-move-arrival'),
                style: CoconutTypography.heading4_18_NumberBold.setColor(colors.primaryText),
              ),
              if (arrivalDetail != null) ...[CoconutLayout.spacing_100h, Text(arrivalDetail!, style: secondary)],
            ],
          ],
        ),
      ],
    );
  }
}

class _ArkMoveCard extends StatelessWidget {
  const _ArkMoveCard({
    required this.label,
    required this.name,
    required this.balance,
    required this.children,
    this.onTap,
    this.changeKey,
  });

  final String label;

  /// 없으면 이름·잔액 줄 없이 [children]만, 예: 주소 직접 입력
  final String? name;
  final String? balance;
  final List<Widget> children;
  final VoidCallback? onTap;
  final Key? changeKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(CoconutStyles.radius_400), color: colors.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
          CoconutLayout.spacing_100h,
          if (name != null)
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap,
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(name!, style: CoconutTypography.body1_16_Bold.setColor(colors.primaryText)),
                        ),
                        if (onTap != null) ...[CoconutLayout.spacing_100w, InfoRowArrow(key: changeKey)],
                      ],
                    ),
                  ),
                ),
                if (balance != null)
                  Text(
                    t.ark_wallet.wallet_balance(amount: balance!),
                    style: CoconutTypography.body3_12_Number.setColor(colors.secondaryText),
                  ),
              ],
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topLeft,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ],
      ),
    );
  }
}
