import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar, CoconutToast;
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ark/ark_receive_view_model.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_receive_amount_sheet.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/common/amount/bitcoin_amount_unit.dart';
import 'package:coconut_wallet/widgets/common/amount/fiat_price.dart';
import 'package:coconut_wallet/widgets/common/buttons/copy_text_container.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/features/ccos/ark/ark_box_text.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/qr/input_and_share_overlay.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/activity_widget_views.dart';
import 'package:coconut_wallet/widgets/features/qr/qrcode_info.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

/// 아크 지갑 받기. QR 하나에 받는 방법을 고르고, 금액을 넣으면 라이트닝 인보이스를 함께 담음
class ArkReceiveScreen extends StatelessWidget {
  const ArkReceiveScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: AnalyticsScreenNames.ccosArkWalletReceive),
      builder: (_) => const ArkReceiveScreen(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ArkReceiveViewModel(context.read<ArkWalletProvider>()),
      child: const _ArkReceiveView(),
    );
  }
}

class _ArkReceiveView extends StatefulWidget {
  const _ArkReceiveView();

  @override
  State<_ArkReceiveView> createState() => _ArkReceiveViewState();
}

class _ArkReceiveViewState extends State<_ArkReceiveView> {
  final GlobalKey _shareButtonKey = GlobalKey();

  String _title(ArkReceiveFormat format) => switch (format) {
    ArkReceiveFormat.paymentRequest => t.ark_wallet.format_payment_request,
    ArkReceiveFormat.lightningInvoice => t.ark_wallet.format_lightning,
    ArkReceiveFormat.arkAddress => t.ark_wallet.format_ark,
  };

  String _caption(ArkReceiveFormat format) => switch (format) {
    ArkReceiveFormat.paymentRequest => t.ark_wallet.format_payment_request_caption,
    ArkReceiveFormat.lightningInvoice => t.ark_wallet.format_lightning_caption,
    ArkReceiveFormat.arkAddress => t.ark_wallet.format_ark_caption,
  };

  Future<void> _enterAmount(ArkReceiveViewModel viewModel) async {
    final result = await ArkReceiveAmountSheet.show(
      context: context,
      initialAmountSats: viewModel.amountSats,
      initialMemo: viewModel.invoiceMemo,
      screenName: AnalyticsScreenNames.ccosArkWalletReceiveAmount,
    );
    if (!mounted || result == null || !result.didEdit) return;
    await viewModel.setAmount(result.amountInSats, memo: result.memo);
  }

  Future<void> _share(ArkReceiveViewModel viewModel) async {
    final data = viewModel.qrData;
    if (data == null) return;
    final box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    AppGuard.disablePrivacyScreen();
    try {
      await SharePlus.instance.share(
        ShareParams(text: data, sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size),
      );
    } finally {
      AppGuard.enablePrivacyScreen();
    }
  }

  void _showWays(ArkReceiveViewModel viewModel) {
    CommonBottomSheets.showBottomSheet<void>(
      context: context,
      title: t.ark_wallet.receive_ways,
      screenName: AnalyticsScreenNames.ccosArkWalletReceiveWays,
      showDragHandle: true,
      child: ChangeNotifierProvider.value(
        value: viewModel,
        child: Consumer<ArkReceiveViewModel>(
          builder: (context, viewModel, _) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final format in ArkReceiveFormat.values)
                    _WayRow(
                      key: ValueKey('ark-receive-way-${format.name}'),
                      title: _title(format),
                      value: viewModel.valueOf(format),
                      displayValue: viewModel.displayOf(format),
                      emptyText: t.ark_wallet.format_lightning_needs_amount,
                      selected: viewModel.format == format,
                      onTap: () {
                        viewModel.select(format);
                        Navigator.of(context).pop();
                      },
                    ),
                  CoconutLayout.spacing_400h,
                  Text(
                    t.ark_wallet.onchain_hint,
                    style: CoconutTypography.body3_12.setColor(context.coconutColors.tertiaryText),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final viewModel = context.watch<ArkReceiveViewModel>();
    final received = viewModel.receivedSats;
    if (received != null) return _ArkReceivedView(amountSats: received);
    final qrData = viewModel.qrData;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(
        context: context,
        backgroundColor: colors.background,
        title: t.receive,
        actionButtonList: [
          CupertinoButton(
            key: const Key('ark-receive-ways'),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onPressed: () => _showWays(viewModel),
            child: Text(t.ark_wallet.receive_ways, style: CoconutTypography.body2_14.setColor(colors.primaryText)),
          ),
        ],
      ),
      body: InputAndShareOverlay(
        shareButtonKey: _shareButtonKey,
        showBottomActions: !viewModel.isCreatingInvoice,
        onEnterAmountTap: () => _enterAmount(viewModel),
        onShareTap: () => _share(viewModel),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(10, 20, 10, 160),
            child: Column(
              children: [
                if (viewModel.isCreatingInvoice || qrData == null)
                  SizedBox(
                    height: 320,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: colors.primaryText),
                          if (viewModel.isCreatingInvoice) ...[
                            CoconutLayout.spacing_300h,
                            Text(
                              t.ark_wallet.invoice_creating,
                              style: CoconutTypography.body2_14.setColor(colors.secondaryText),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                else
                  QrCodeInfo(
                    key: ValueKey('ark-receive-qr-${viewModel.format.name}'),
                    qrData: qrData,
                    isAddress: viewModel.format == ArkReceiveFormat.arkAddress,
                    displayText: viewModel.displayOf(viewModel.format),
                    qrcodeTopWidget: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _title(viewModel.format),
                            style: CoconutTypography.body1_16.setColor(colors.primaryText),
                          ),
                          Text(
                            _caption(viewModel.format),
                            style: CoconutTypography.body2_14.setColor(colors.secondaryText),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (viewModel.needsScreenOpen) ...[
                  CoconutLayout.spacing_300h,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      t.ark_wallet.receive_keep_open,
                      textAlign: TextAlign.center,
                      style: CoconutTypography.body2_14.setColor(colors.secondaryText),
                    ),
                  ),
                ],
                if (viewModel.invoiceFailed) ...[
                  CoconutLayout.spacing_300h,
                  Text(t.ark_wallet.invoice_failed, style: CoconutTypography.body2_14.setColor(colors.danger)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WayRow extends StatelessWidget {
  const _WayRow({
    super.key,
    required this.title,
    required this.value,
    required this.displayValue,
    required this.emptyText,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String? value;
  final String? displayValue;
  final String emptyText;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final value = this.value;
    return Opacity(
      opacity: value == null ? 0.4 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              selected ? CupertinoIcons.largecircle_fill_circle : CupertinoIcons.circle,
              size: 20,
              color: colors.primaryText,
            ),
            CoconutLayout.spacing_300w,
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: value == null ? null : onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
                    if (value == null)
                      Text(emptyText, style: CoconutTypography.body3_12.setColor(colors.secondaryText))
                    else
                      DefaultTextHeightBehavior(
                        textHeightBehavior: arkBoxTextHeight,
                        child: CopyTextContainer(
                          text: displayValue ?? value,
                          copyText: value,
                          padding: const EdgeInsets.all(20),
                          textStyle: CoconutTypography.body3_12_Number.setColor(colors.secondaryText),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 띄워 둔 받기 화면에서 라이트닝 결제가 끝났을 때. 보내기 결과와 같은 배치
class _ArkReceivedView extends StatelessWidget {
  const _ArkReceivedView({required this.amountSats});

  final int amountSats;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final unit = context.select<ArkWalletProvider, BitcoinUnit>((wallet) => wallet.unit);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(context: context, backgroundColor: colors.background, title: ''),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              CoconutLayout.spacing_400h,
              Center(
                child: SvgPicture.asset(
                  FeatureArkIconPath.txLightningReceived,
                  key: const Key('ark-receive-received'),
                  width: 56,
                  height: 56,
                  colorFilter: monochromeIconFilter(colors.primaryText),
                ),
              ),
              CoconutLayout.spacing_400h,
              Text(
                t.ark_wallet.result_received,
                textAlign: TextAlign.center,
                style: CoconutTypography.body1_16_Bold.setColor(colors.primaryText),
              ),
              CoconutLayout.spacing_200h,
              Center(
                child: BitcoinAmountUnit(
                  currentUnit: unit,
                  unitStyle: CoconutTypography.heading4_18_Number.setColor(colors.primaryText),
                  spacing: CoconutLayout.spacing_100w,
                  child: Text(
                    unit.displayBitcoinAmount(amountSats),
                    style: CoconutTypography.heading2_28_NumberBold.setColor(colors.primaryText),
                  ),
                ),
              ),
              Center(child: FiatPrice(satoshiAmount: amountSats, textColor: colors.secondaryText)),
            ],
          ),
          FixedBottomButton(text: t.done, onButtonClicked: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}
