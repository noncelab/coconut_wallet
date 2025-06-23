import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/animated_qr/animated_qr_view.dart';
import 'package:coconut_wallet/widgets/animated_qr/view_data_handler/bc_ur_qr_view_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/view_data_handler/coconut_qr_view_handler.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/svg.dart';

class UnsignedTransactionQrScreen extends StatefulWidget {
  final String walletName;

  const UnsignedTransactionQrScreen({super.key, required this.walletName});

  @override
  State<UnsignedTransactionQrScreen> createState() => _UnsignedTransactionQrScreenState();
}

class _UnsignedTransactionQrScreenState extends State<UnsignedTransactionQrScreen> {
  late final String _psbtBase64;
  late final bool _isMultisig;
  late final WalletImportSource _walletImportSource;
  late bool _isFastMode = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const deviceMmWidth = 75.6; // 갤럭시 S21+ 실제 가로 mm
    const targetMmSize = 62.8 * 0.8; // 폴드1에서의 QR mm 크기

    // 테스트용(갤폴드에서 보이는 QR사이즈)
    final qrSize = screenWidth * (targetMmSize / deviceMmWidth);
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      backgroundColor: CoconutColors.black,
      appBar: CoconutAppBar.buildWithNext(
          title: t.send,
          context: context,
          usePrimaryActiveColor: true,
          onNextPressed: () {
            Navigator.pushNamed(context, '/signed-psbt-scanner');
          }),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            width: MediaQuery.of(context).size.width,
            padding: Paddings.container,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                      top: 8,
                      left: CoconutLayout.defaultPadding,
                      right: CoconutLayout.defaultPadding),
                  child: _buildToolTip(),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 40),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: CoconutColors.white, borderRadius: BorderRadius.circular(8)),
                  child: AnimatedQrView(
                    key: ValueKey(_isFastMode),
                    qrSize: MediaQuery.sizeOf(context).width * 0.8,
                    // 테스트용(갤폴드에서 보이는 QR사이즈)
                    // qrSize: qrSize,
                    isFastMode: _isFastMode,
                    qrViewDataHandler: BcUrQrViewHandler(
                      _psbtBase64,
                      _isFastMode,
                      {'urType': 'crypto-psbt'},
                    ),
                  ),
                ),
                CoconutLayout.spacing_800h,
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.unsigned_tx_qr_screen.fast_scan_mode,
                            style: CoconutTypography.body3_12_Bold,
                          ),
                          Text(
                            _isFastMode
                                ? t.unsigned_tx_qr_screen.high_density_qr_scan
                                : t.unsigned_tx_qr_screen.low_density_qr_scan,
                            style: CoconutTypography.body3_12.setColor(
                              CoconutColors.gray400,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        width: 50,
                        child: FittedBox(
                          fit: BoxFit.fitWidth,
                          child: CupertinoSwitch(
                            value: _isFastMode,
                            activeColor: CoconutColors.gray100,
                            trackColor: CoconutColors.gray600,
                            thumbColor: CoconutColors.gray800,
                            onChanged: (value) {
                              setState(() {
                                _isFastMode = value;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                CoconutLayout.spacing_500h,
                if (_isFastMode && _walletImportSource == WalletImportSource.seedSigner)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: CoconutLayout.defaultPadding),
                    child: Text(
                      textAlign: TextAlign.center,
                      t.unsigned_tx_qr_screen.fast_scan_mode_seedsigner_guide,
                      style: CoconutTypography.body3_12.setColor(
                        CoconutColors.gray600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final sendInfoProvider = Provider.of<SendInfoProvider>(context, listen: false);
    _psbtBase64 = sendInfoProvider.txWaitingForSign!;
    _isMultisig = sendInfoProvider.isMultisig!;
    _walletImportSource = sendInfoProvider.walletImportSource!;
    _isFastMode = _walletImportSource != WalletImportSource.seedSigner;
  }

  Widget _buildToolTip() {
    // TODO: 코코넛 지갑인 경우 UI는 볼트와 한꺼번에 수정합니다.
    if (_walletImportSource == WalletImportSource.coconutVault) {
      return CoconutToolTip(
          baseBackgroundColor: CoconutColors.white.withOpacity(0.95),
          tooltipType: CoconutTooltipType.fixed,
          richText: RichText(
            text: TextSpan(
              text: '[1] ',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.bold,
                fontSize: 15,
                height: 1.4,
                letterSpacing: 0.5,
                color: CoconutColors.black,
              ),
              children: <TextSpan>[
                TextSpan(
                  text: t.tooltip.unsigned_tx_qr.in_vault,
                  style: const TextStyle(
                    fontWeight: FontWeight.normal,
                  ),
                ),
                TextSpan(
                  text: ' ${t.tooltip.unsigned_tx_qr.select_wallet(name: widget.walletName)} '
                      '\'${_isMultisig ? t.sign_multisig : t.sign}\'',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: t.tooltip.unsigned_tx_qr.scan_qr_below,
                  style: const TextStyle(
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          showIcon: true);
    } else {
      return CoconutToolTip(
        backgroundColor: CoconutColors.gray900,
        borderColor: CoconutColors.gray900,
        icon: SvgPicture.asset(
          'assets/svg/circle-info.svg',
          colorFilter: const ColorFilter.mode(
            CoconutColors.white,
            BlendMode.srcIn,
          ),
        ),
        tooltipType: CoconutTooltipType.fixed,
        richText: RichText(
          text: TextSpan(
            style: CoconutTypography.body3_12,
            children: _getGuideTextSpan(),
          ),
        ),
      );
    }
  }

  List<TextSpan> _getGuideTextSpan() {
    switch (_walletImportSource) {
      case WalletImportSource.seedSigner:
        {
          return [
            TextSpan(
                text:
                    '${t.third_party.seed_signer} ${t.unsigned_tx_qr_screen.hardware_wallet_screen_guide}\n'),
            TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_seedsigner.step1} '),
            _em(t.unsigned_tx_qr_screen.guide_seedsigner.step1_em),
            TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_seedsigner.step1_end}\n'),
            TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_seedsigner.step2}'),
          ];
        }
      case WalletImportSource.keystone:
        {
          return [
            TextSpan(
                text:
                    '${t.third_party.keystone} ${t.unsigned_tx_qr_screen.hardware_wallet_screen_guide}\n'),
            TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_keystone.step1} '),
            _em(t.unsigned_tx_qr_screen.guide_keystone.step1_em),
            TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_keystone.step1_end}\n'),
            TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_keystone.step2}'),
          ];
        }
      // case WalletImportSource.coconutVault: TODO: 추후 BC_UR QR로 변경합니다.
      default:
        return [TextSpan(text: t.unsigned_tx_qr_screen.guide_hardware_wallet.step1)];
    }
  }

  TextSpan _em(String text) => TextSpan(
        text: text,
        style: CoconutTypography.body3_12_Bold,
      );
}
