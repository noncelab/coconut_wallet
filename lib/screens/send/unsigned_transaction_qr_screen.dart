import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/unsigned_transaction_view_model.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/animated_qr/animated_qr_view.dart';
import 'package:coconut_wallet/widgets/animated_qr/view_data_handler/bc_ur_qr_view_handler.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/svg.dart';
import 'package:qr_flutter/qr_flutter.dart';

class UnsignedTransactionQrScreen extends StatefulWidget {
  final String walletName;

  const UnsignedTransactionQrScreen({super.key, required this.walletName});

  @override
  State<UnsignedTransactionQrScreen> createState() => _UnsignedTransactionQrScreenState();
}

class _UnsignedTransactionQrScreenState extends State<UnsignedTransactionQrScreen> {
  late final SendInfoProvider _sendInfoProvider;
  late final String _psbtBase64;
  late final bool _isMultisig;
  late final WalletImportSource _walletImportSource;
  late bool? _isDonation;

  @override
  void initState() {
    super.initState();
    _sendInfoProvider = Provider.of<SendInfoProvider>(context, listen: false);
    _psbtBase64 = _sendInfoProvider.txWaitingForSign!;
    _isMultisig = _sendInfoProvider.isMultisig!;
    _walletImportSource = _sendInfoProvider.walletImportSource!;
    _isDonation = _sendInfoProvider.isDonation;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ViewModel 초기화
    final viewModel = UnsignedTransactionQrViewModel();
    final screenWidth = MediaQuery.of(context).size.width;
    viewModel.initializeQrScanDensity(_walletImportSource, screenWidth);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final viewModel = UnsignedTransactionQrViewModel();
        // BBQR 초기화 (QR 스캔 밀도는 didChangeDependencies에서 초기화)
        viewModel.initializeBbqr(_psbtBase64, _walletImportSource);
        return viewModel;
      },
      child: Consumer<UnsignedTransactionQrViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
            backgroundColor: CoconutColors.black,
            appBar: CoconutAppBar.build(title: (_isDonation ?? false) ? t.donation.donate : t.send, context: context),
            body: SafeArea(
              child: Stack(
                children: [
                  SafeArea(
                    child: SingleChildScrollView(
                      child: Container(
                        width: MediaQuery.of(context).size.width,
                        padding: Paddings.container,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Padding(padding: const EdgeInsets.only(top: 8), child: _buildToolTip()),
                            Container(
                              margin: const EdgeInsets.only(top: 40),
                              // width: qrSize, // 테스트용(갤폴드에서 보이는 QR사이즈)
                              // height: qrSize, // 테스트용(갤폴드에서 보이는 QR사이즈)
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                              decoration: BoxDecoration(
                                color: CoconutColors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child:
                                    viewModel.isBbqrType && viewModel.hasBbqrParts
                                        ? QrImageView(
                                          data: viewModel.bbqrParts[viewModel.currentBbqrIndex],
                                          version: QrVersions.auto,
                                        )
                                        : AnimatedQrView(
                                          key: ValueKey(viewModel.qrScanDensity),
                                          qrScanDensity: viewModel.qrScanDensity,
                                          qrViewDataHandler: BcUrQrViewHandler(_psbtBase64, viewModel.qrScanDensity, {
                                            'urType': 'crypto-psbt',
                                          }),
                                        ),
                              ),
                            ),
                            if (!viewModel.isBbqrType) ...[
                              CoconutLayout.spacing_800h,
                              _buildDensitySliderWidget(context),
                            ],
                            Container(height: 150),
                          ],
                        ),
                      ),
                    ),
                  ),
                  FixedBottomButton(
                    onButtonClicked: () {
                      Navigator.pushNamed(context, '/signed-psbt-scanner');
                    },
                    subWidget: CoconutUnderlinedButton(
                      text: viewModel.isBbqrType ? t.unsigned_tx_qr_screen.view_ur : t.unsigned_tx_qr_screen.view_bbqr,
                      onTap: () {
                        viewModel.encodeBbqr(_psbtBase64);
                        viewModel.toggleBbqrType();
                      },
                    ),
                    text: t.next,
                    backgroundColor: CoconutColors.gray100,
                    pressedBackgroundColor: CoconutColors.gray500,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDensitySliderWidget(BuildContext context) {
    return Consumer<UnsignedTransactionQrViewModel>(
      builder: (context, viewModel, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 100),
                child: Text(
                  t.unsigned_tx_qr_screen.low_density_qr,
                  style: CoconutTypography.body3_12,
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: CoconutColors.gray700,
                    inactiveTrackColor: CoconutColors.gray700,
                    trackHeight: 8,
                    thumbColor: CoconutColors.gray400,
                    overlayColor: CoconutColors.gray700.withOpacity(0.2),
                    trackShape: const RoundedRectSliderTrackShape(),
                  ),
                  child: Slider(
                    value: viewModel.sliderValue,
                    min: 0,
                    max: 10.0,
                    divisions: 100,
                    onChanged: (double value) {
                      viewModel.updateSliderValue(value);
                    },
                    onChangeEnd: (double value) {
                      vibrateExtraLight();
                      viewModel.onSliderChangeEnd(value);
                    },
                  ),
                ),
              ),
              Container(
                constraints: const BoxConstraints(maxWidth: 100),
                child: Text(
                  t.unsigned_tx_qr_screen.high_density_qr,
                  style: CoconutTypography.body3_12,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolTip() {
    if (_sendInfoProvider.isDonation == true) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Center(child: Text(t.donation.unsigned_qr_tooltip, style: CoconutTypography.body2_14_Bold)),
      );
    } else {
      return CoconutToolTip(
        backgroundColor: CoconutColors.gray900,
        borderColor: CoconutColors.gray900,
        icon: SvgPicture.asset(
          'assets/svg/circle-info.svg',
          width: 20,
          colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
        ),
        tooltipType: CoconutTooltipType.fixed,
        richText: RichText(
          text: TextSpan(style: CoconutTypography.body2_14.copyWith(height: 1.3), children: _getGuideTextSpan()),
        ),
      );
    }
  }

  List<TextSpan> _getGuideTextSpan() {
    final isEnglish = context.read<PreferenceProvider>().isEnglish;

    switch (_walletImportSource) {
      case WalletImportSource.coconutVault:
        {
          if (!isEnglish) {
            return [
              TextSpan(
                text: t.tooltip.unsigned_tx_qr.open_vault,
                style: CoconutTypography.body2_14.copyWith(height: 1.2),
              ),
              TextSpan(
                text: ' ${t.tooltip.unsigned_tx_qr.select_wallet(name: widget.walletName)}',
                style: CoconutTypography.body2_14_Bold.copyWith(height: 1.2),
              ),
              TextSpan(
                text: ' ${t.tooltip.unsigned_tx_qr.select_menu(menu: '\'${_isMultisig ? t.sign_multisig : t.sign}\'')}',
                style: CoconutTypography.body2_14_Bold.copyWith(height: 1.2),
              ),
              TextSpan(
                text: t.tooltip.unsigned_tx_qr.scan_qr_below,
                style: CoconutTypography.body2_14.copyWith(height: 1.2),
              ),
            ];
          } else {
            return [
              TextSpan(
                text: t.tooltip.unsigned_tx_qr.open_vault,
                style: CoconutTypography.body2_14.copyWith(height: 1.2),
              ),
              TextSpan(text: ', ', style: CoconutTypography.body2_14.copyWith(height: 1.2)),
              TextSpan(
                text: ' ${t.tooltip.unsigned_tx_qr.select_wallet(name: widget.walletName)}',
                style: CoconutTypography.body2_14_Bold.copyWith(height: 1.2),
              ),
              TextSpan(text: ', ', style: CoconutTypography.body2_14.copyWith(height: 1.2)),
              TextSpan(
                text: t.tooltip.unsigned_tx_qr.select_menu(menu: '\'${_isMultisig ? t.sign_multisig : t.sign}\''),
                style: CoconutTypography.body2_14_Bold.copyWith(height: 1.2),
              ),
              TextSpan(text: ', ', style: CoconutTypography.body2_14.copyWith(height: 1.2)),
              TextSpan(
                text: t.tooltip.unsigned_tx_qr.scan_qr_below,
                style: CoconutTypography.body2_14.copyWith(height: 1.2),
              ),
            ];
          }
        }
      case WalletImportSource.seedSigner:
        {
          if (!isEnglish) {
            return [
              TextSpan(text: '${t.third_party.seed_signer} ${t.unsigned_tx_qr_screen.hardware_wallet_screen_guide}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_seedsigner.step1} '),
              _em(t.unsigned_tx_qr_screen.guide_seedsigner.step1_em),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_seedsigner.step1_end}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_seedsigner.step2}'),
            ];
          } else {
            return [
              TextSpan(text: '${t.third_party.seed_signer} ${t.unsigned_tx_qr_screen.hardware_wallet_screen_guide}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_seedsigner.step1}'),
              TextSpan(text: '${t.unsigned_tx_qr_screen.guide_seedsigner.step1_end} '),
              _em('${t.unsigned_tx_qr_screen.guide_seedsigner.step1_em}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_seedsigner.step2}'),
            ];
          }
        }
      case WalletImportSource.keystone:
        {
          if (!isEnglish) {
            return [
              TextSpan(text: '${t.third_party.keystone} ${t.unsigned_tx_qr_screen.hardware_wallet_screen_guide}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_keystone.step1} '),
              _em(t.unsigned_tx_qr_screen.guide_keystone.step1_em),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_keystone.step1_end}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_keystone.step2}'),
            ];
          } else {
            return [
              TextSpan(text: '${t.third_party.keystone} ${t.unsigned_tx_qr_screen.hardware_wallet_screen_guide}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_keystone.step1}'),
              TextSpan(text: '${t.unsigned_tx_qr_screen.guide_keystone.step1_end} '),
              _em('${t.unsigned_tx_qr_screen.guide_keystone.step1_em}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_keystone.step2}'),
            ];
          }
        }
      case WalletImportSource.jade:
        {
          if (!isEnglish) {
            return [
              TextSpan(text: '${t.third_party.jade} ${t.unsigned_tx_qr_screen.hardware_wallet_screen_guide}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_jade.step0}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_jade.step1}'),
              _em(t.unsigned_tx_qr_screen.guide_jade.step1_em),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_jade.step1_end}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_jade.step2}'),
            ];
          } else {
            return [
              TextSpan(text: '${t.third_party.jade} ${t.unsigned_tx_qr_screen.hardware_wallet_screen_guide}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_jade.step0}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_jade.step1}'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_jade.step1_end} '),
              _em('${t.unsigned_tx_qr_screen.guide_jade.step1_em}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_jade.step2}'),
            ];
          }
        }
      case WalletImportSource.coldCard:
        {
          return [
            TextSpan(text: '${t.third_party.cold_card} ${t.unsigned_tx_qr_screen.hardware_wallet_screen_guide}\n'),
            TextSpan(text: t.unsigned_tx_qr_screen.guide_coldcard.step1_preposition),
            _em(t.unsigned_tx_qr_screen.guide_coldcard.step1_em),
            TextSpan(text: t.unsigned_tx_qr_screen.guide_coldcard.step1_end),
          ];
        }
      case WalletImportSource.krux:
        {
          if (!isEnglish) {
            return [
              TextSpan(text: '${t.third_party.krux} ${t.unsigned_tx_qr_screen.hardware_wallet_screen_guide}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_krux.step1} '),
              _em(t.unsigned_tx_qr_screen.guide_krux.step1_em),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_krux.select}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_krux.step2}'),
              _em(t.unsigned_tx_qr_screen.guide_krux.step2_em),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_krux.select}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_krux.step3}'),
              _em(t.unsigned_tx_qr_screen.guide_krux.step3_em),
            ];
          } else {
            return [
              TextSpan(text: '${t.third_party.krux} ${t.unsigned_tx_qr_screen.hardware_wallet_screen_guide}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_krux.step1}'),
              TextSpan(text: '${t.unsigned_tx_qr_screen.guide_krux.select} '),
              _em('${t.unsigned_tx_qr_screen.guide_krux.step1_em}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_krux.step2}'),
              TextSpan(text: '${t.unsigned_tx_qr_screen.guide_krux.select} '),
              _em('${t.unsigned_tx_qr_screen.guide_krux.step2_em}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_krux.step3}'),
              _em(t.unsigned_tx_qr_screen.guide_krux.step3_em),
            ];
          }
        }
      default:
        return [TextSpan(text: t.unsigned_tx_qr_screen.guide_hardware_wallet.step1)];
    }
  }

  TextSpan _em(String text) => TextSpan(text: text, style: CoconutTypography.body2_14_Bold.copyWith(height: 1.3));
}
