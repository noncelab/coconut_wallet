import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/animated_qr/animated_qr_view.dart';
import 'package:coconut_wallet/widgets/animated_qr/view_data_handler/bc_ur_qr_view_handler.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/svg.dart';

enum QrScanDensity { slow, normal, fast }

class UnsignedTransactionQrScreen extends StatefulWidget {
  final String walletName;

  const UnsignedTransactionQrScreen({super.key, required this.walletName});

  @override
  State<UnsignedTransactionQrScreen> createState() => _UnsignedTransactionQrScreenState();
}

class _UnsignedTransactionQrScreenState extends State<UnsignedTransactionQrScreen> {
  int? _lastSnappedValue;
  late final String _psbtBase64;
  late final bool _isMultisig;
  late final WalletImportSource _walletImportSource;
  late QrScanDensity _qrScanDensity;
  late double _sliderValue;
  late double _qrPaddingVertical;
  late double _qrSize;
  bool _isQrDensityInitialized = false;

  @override
  void initState() {
    super.initState();
    final sendInfoProvider = Provider.of<SendInfoProvider>(context, listen: false);
    _psbtBase64 = sendInfoProvider.txWaitingForSign!;
    _isMultisig = sendInfoProvider.isMultisig!;
    _walletImportSource = sendInfoProvider.walletImportSource!;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    //  (QR스캔성능)    일반 화면        갤폴드 접은 화면
    //     볼트           상                상
    //    키스톤           상                상
    //   시드사이너         상                하
    //    제이드          중상                하
    if (!_isQrDensityInitialized) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isNarrowScreen = screenWidth < 360;
      _qrSize = MediaQuery.sizeOf(context).width * 0.9;

      switch (_walletImportSource) {
        case WalletImportSource.coconutVault:
          _qrScanDensity = QrScanDensity.fast;
          _qrSize = MediaQuery.sizeOf(context).width * 0.8;
          _qrPaddingVertical = 0;
          break;
        case WalletImportSource.seedSigner:
          _qrScanDensity = isNarrowScreen ? QrScanDensity.slow : QrScanDensity.fast;
          _qrPaddingVertical = 60;
          break;
        case WalletImportSource.extendedPublicKey:
          _qrScanDensity = QrScanDensity.fast;
          _qrPaddingVertical = 60;
          break;
        default:
          _qrScanDensity = isNarrowScreen ? QrScanDensity.normal : QrScanDensity.fast;
          _qrPaddingVertical = 30;
          break;
      }
      _sliderValue = _qrScanDensity.index * 5;
      _isQrDensityInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const deviceMmWidth = 75.6; // 갤럭시 S21+ 실제 가로 mm
    const targetMmSize = 62.8 * 0.9; // 폴드1에서의 QR mm 크기

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
                  padding: EdgeInsets.symmetric(
                    vertical: _qrPaddingVertical,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                      color: CoconutColors.white, borderRadius: BorderRadius.circular(8)),
                  child: Center(
                    child: AnimatedQrView(
                      key: ValueKey(_qrScanDensity),
                      qrSize: _qrSize,
                      // qrSize: qrSize, // 테스트용(갤폴드에서 보이는 QR사이즈)
                      qrScanDensity: _qrScanDensity,
                      qrViewDataHandler:
                          BcUrQrViewHandler(_psbtBase64, _qrScanDensity, {'urType': 'crypto-psbt'}),
                    ),
                  ),
                ),
                CoconutLayout.spacing_800h,
                _buildDensitySliderWidget(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Padding _buildDensitySliderWidget(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            t.unsigned_tx_qr_screen.low_density_qr,
            style: CoconutTypography.body3_12,
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
                value: _sliderValue,
                min: 0,
                max: 10.0,
                divisions: 100,
                onChanged: (double value) {
                  setState(() {
                    _sliderValue = value;
                  });
                },
                onChangeEnd: (double value) {
                  final snapped = _getSnappedValue(value);
                  if (_lastSnappedValue != snapped) {
                    vibrateExtraLight();
                    _lastSnappedValue = snapped;
                  }
                  setState(() {
                    _sliderValue = snapped.toDouble();
                    _qrScanDensity = _mapValueToDensity(snapped);
                  });
                },
              ),
            ),
          ),
          Text(
            t.unsigned_tx_qr_screen.high_density_qr,
            style: CoconutTypography.body3_12,
          ),
        ],
      ),
    );
  }

  int _getSnappedValue(double value) {
    if (value <= 2.5) return 0;
    if (value <= 7.5) return 5;
    return 10;
  }

  QrScanDensity _mapValueToDensity(int val) {
    switch (val) {
      case 0:
        return QrScanDensity.slow;
      case 5:
        return QrScanDensity.normal;
      case 10:
      default:
        return QrScanDensity.fast;
    }
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
      case WalletImportSource.coconutVault:
        {
          return [
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
          ];
        }
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
      case WalletImportSource.jade:
        {
          return [
            TextSpan(
                text:
                    '${t.third_party.jade} ${t.unsigned_tx_qr_screen.hardware_wallet_screen_guide}\n'),
            TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_jade.step0}\n'),
            TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_jade.step1}'),
            _em(t.unsigned_tx_qr_screen.guide_jade.step1_em),
            TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_jade.step1_end}\n'),
            TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_jade.step2}'),
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
