import 'dart:convert';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/bbqr/bbqr_encoder.dart';
import 'package:coconut_wallet/utils/print_util.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/animated_qr/animated_qr_view.dart';
import 'package:coconut_wallet/widgets/animated_qr/view_data_handler/bc_ur_qr_view_handler.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/svg.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:convert/convert.dart';

enum QrScanDensity { slow, normal, fast }

class UnsignedTransactionQrScreen extends StatefulWidget {
  final String walletName;

  const UnsignedTransactionQrScreen({super.key, required this.walletName});

  @override
  State<UnsignedTransactionQrScreen> createState() => _UnsignedTransactionQrScreenState();
}

class _UnsignedTransactionQrScreenState extends State<UnsignedTransactionQrScreen> {
  int? _lastSnappedValue;
  late final SendInfoProvider _sendInfoProvider;
  late final String _psbtBase64;
  late final bool _isMultisig;
  late final WalletImportSource _walletImportSource;
  late QrScanDensity _qrScanDensity;
  late double _sliderValue;
  late bool? _isDonation;

  @override
  void initState() {
    super.initState();
    _sendInfoProvider = Provider.of<SendInfoProvider>(context, listen: false);
    _psbtBase64 = _sendInfoProvider.txWaitingForSign!;
    _isMultisig = _sendInfoProvider.isMultisig!;
    _walletImportSource = _sendInfoProvider.walletImportSource!;
    _isDonation = _sendInfoProvider.isDonation;

    // [spacedHex] psbt파일로 저장해서 콜드카드 시뮬레이터에서 인식될 때 사용됨
    // [.psbt 파일 경로] firmware/unix/work/MicroSD/
    // 주의할 점: psbt 확장자여야 하며, 일반 txt파일을 psbt로 확장자명을 변환하면 인식이 안될 수도 있음
    // -> Sparrow에서 트랜잭션 생성, File - Save PSBT - As Binary로 저장 후 Sublime Text 앱으로 열어서 수정 후 저장
    // -> [ColdCard Q1] Ready To Sign -> (Enter) -> Sending Amount, fee 등 정보 맞는지 확인
    // -> (Enter) -> (QR 버튼)

    final hexStr = hex.encode(base64.decode(_psbtBase64));
    final spacedHex = hexStr.replaceAllMapped(RegExp(r'.{4}'), (match) => '${match.group(0)} ');
    printLongString('psbtBase64:::::: $spacedHex');
    debugPrint('bbqr:::::: ${BbqrEncoder().encodeBase64(_psbtBase64)}');
    // 스패로우 BBQR
    // B$ZP0100FMUE4KXZZ7EFBSGEYDAMBOGE2IVXLWJGI3NWYRTP2Z7ULZK4F6VJZJLT5JWBW3Y2PIS32PMYO
    // 2NQCBH673777H3JGY3ZRTJAYYQFE47XJ2JHJITG6LR5YDNPVWL3AX2LHWYFJYD5FIRUZ6SWRLE65R3NG4
    // XFZN6QP4W3BOVR3I2HVQYGZZD24DH6RQWKN3PHTF4RU7JUDOACVZO7FQ5PYI7TPGFK3VU3XBVITQ726PJ
    // RRXRMHZI65EKXZVX7N2WXDV36NE2L7NTE52EI7R5FJ7OUZMDW5U3YNYPD47TO74FQ5C6AKN5XYVME2M2Q
    // L6CZGOOUGGAYDKADNAYMNRQGAZEUW6WYJO7DUPQND75JJ6VHPPFZ3VNJZ2DY7HLY3RJ2XGGMYLBAPESTM
    // ZW7Y4H75LXRCRUP74BR6TC6PXKSDWZ4HZ24TBWVI3T6N6OXD2Q72WRJ6EXIU2B7IVMDRRLGEYRW3P2PRU
    // 5PNPV2VYY26RXV7KGLRFHUTL3WXJSHDZWJ3KMSX7TVDU6LUG2DGNEN62UIMYTNLXWFUKGP65QYCVU67XL
    // LH2QSSJTK6X66SJTZTSF3Y3TMNO55QUM5RLK6MGUQMYAA

    // 코코넛 월렛 BBQR
    // B$ZP0100FMUE4KXZZ7EFBSGEYDAMBOGE2IVXLWJGI3NWYRTP2Z7ULZK4F6VJZJLT5JWBW3Y2PIS32PMYO
    // 2NQCBH677777H3JGY3ZRTJAYYQFE47XJ2JHJITG6LR5YDNPVWL3AX2LHWYFJYD5FIRUZ6SWRLE65R3NG4
    // XFZN6QP4W3BOVR3I2HVQYGSCKD6I4LNH5XSZU6IYP42BQGAYDPSN4LB374Q7E6MKV7KJVOLLRLB7X4GSD
    // DPC2PSR56IVPTTO67U5OHTX46JUV6TEJTUIV7DZKT75PSQHNTJHU3Q6HZ7W77QLBSF4GUDZPRLYLUJUAX
    // 5VSM44IANBQGUDGSAAY3DAMBTZLNFPQ656BIPD2H72UT5IOW63VXCYTTUXX6OVR3CTROEMZQWSC6RGG5T
    // 57RQO7WWPAF3I7XYDD56F43OVGH5TYDSF3GDOKZXX23M6OPUR5V5CTQJOXJEB65KYFTSWMJQVD3C6FTF7
    // W3MFKKJPLXV74YJJUYVDK7PJ434RYS54V2WGW62YSHOUVFNXJVEDGQA===

    // 스패로우 PSBT base64
    // cHNidP8BAHECAAAAAaQ5SmWmsgE9awFLBf5ydwroekMbbH49gdkxSmLtwWbbAAAAAAD9////ApsLAAAAA
    // AAAFgAUfN3cYhthKWPjbbDrO6QH1mXApRDvZQEAAAAAABYAFNpkNLvjhtjQ1zgv6xCrgXs1W7CwCeJFAE
    // 8BBDWHzwMMgUwpgAAAAB/sosP4aedkPSrsXnsYwy+fZgDso8h3SG57Dzbq+txHA8mljpmQiFn1xSfK6eB
    // GlgzZw8fOv+gIOFHKvE0kE2cpEA8FaUNUAACAAQAAgAAAAIAAAQEfPXkBAAAAAAAWABTxEcX/ZeR7uOzb
    // hXNhQdP62KMsbQEDBAEAAAAiBgNN4+D9rEkQh/DxVejzuxqIm1ec0JsydzferjNl/CVy+RgPBWlDVAAAg
    // AEAAIAAAACAAQAAAHsAAAAAIgIDNrLj8vrWrntegC/b0H5sX2Rne0LSOMzkrZmo/orBxbsYDwVpQ1QAAI
    // ABAACAAAAAgAAAAACrAAAAACICAiWNoxUB/rgyciu9vTeQglxaq9+XNG4JokrYtobRiHtlGA8FaUNUAAC
    // AAQAAgAAAAIABAAAAfAAAAAA=

    // 코코넛 월렛 PSBT base64
    // cHNidP8BAHECAAAAAaQ5SmWmsgE9awFLBf5ydwroekMbbH49gdkxSmLtwWbbAAAAAAD/////ApsLAAAAA
    // AAAFgAUfN3cYhthKWPjbbDrO6QH1mXApRDvZQEAAAAAABYAFNpkNLvjhtjQ1zgv6xCrgXs1W7CwAAAAAE
    // 8BBDWHzwMMgUwpgAAAAB/sosP4aedkPSrsXnsYwy+fZgDso8h3SG57Dzbq+txHA8mljpmQiFn1xSfK6eB
    // GlgzZw8fOv+gIOFHKvE0kE2cpEA8FaUNUAACAAQAAgAAAAIAAAQEfPXkBAAAAAAAWABTxEcX/ZeR7uOzb
    // hXNhQdP62KMsbQEDBAEAAAAiBgNN4+D9rEkQh/DxVejzuxqIm1ec0JsydzferjNl/CVy+RgPBWlDVAAAg
    // AEAAIAAAACAAQAAAHsAAAAAACICAiWNoxUB/rgyciu9vTeQglxaq9+XNG4JokrYtobRiHtlGA8FaUNUAA
    // CAAQAAgAAAAIABAAAAfAAAAAA=
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    //  (QR스캔성능)    일반 화면        갤폴드 접은 화면
    //     볼트           상                상
    //    키스톤           상                상
    //   시드사이너         상                하
    //    제이드          중상                하
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrowScreen = screenWidth < 360;

    switch (_walletImportSource) {
      case WalletImportSource.coconutVault:
      case WalletImportSource.keystone:
        // 볼트와 키스톤은 스캔 성능이 우수하기 때문에 일반/좁은 화면 모두 _qrScanDensity: fast, padding: 16으로 설정
        _qrScanDensity = QrScanDensity.fast;
        break;
      case WalletImportSource.seedSigner:
      case WalletImportSource.extendedPublicKey:
        // 시드사이너는 좁은 화면에서 _qrScanDensity slow가 안정적임
        _qrScanDensity = isNarrowScreen ? QrScanDensity.slow : QrScanDensity.fast;
        break;
      case WalletImportSource.jade:
        // 제이드는 카메라 성능 최악
        _qrScanDensity = isNarrowScreen ? QrScanDensity.slow : QrScanDensity.normal;
        break;
      default:
        _qrScanDensity = QrScanDensity.normal;
        break;
    }
    _sliderValue = _qrScanDensity.index * 5;
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
          title: (_isDonation ?? false) ? t.donation.donate : t.send,
          context: context,
          usePrimaryActiveColor: true,
          nextButtonTitle: t.next,
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
                  // width: qrSize, // 테스트용(갤폴드에서 보이는 QR사이즈)
                  // height: qrSize, // 테스트용(갤폴드에서 보이는 QR사이즈)
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                      color: CoconutColors.white, borderRadius: BorderRadius.circular(8)),
                  child: Center(
                    child: _isBbQrType()
                        ? QrImageView(
                            data: BbqrEncoder().encodeBase64(_psbtBase64).first,
                            version: QrVersions.auto,
                          )
                        : AnimatedQrView(
                            key: ValueKey(_qrScanDensity),
                            qrScanDensity: _qrScanDensity,
                            qrViewDataHandler: BcUrQrViewHandler(
                                _psbtBase64, _qrScanDensity, {'urType': 'crypto-psbt'}),
                          ),
                  ),
                ),
                if (!_isBbQrType()) ...[
                  CoconutLayout.spacing_800h,
                  _buildDensitySliderWidget(context),
                ],
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

  bool _isBbQrType() {
    // BbQR이 지원되면 추가 되어야 함
    return _sendInfoProvider.walletImportSource == WalletImportSource.coldCard;
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
    if (_sendInfoProvider.isDonation == true) {
      return Padding(
        padding: const EdgeInsets.only(
          top: 24,
        ),
        child: Center(
          child: Text(
            t.donation.unsigned_qr_tooltip,
            style: CoconutTypography.body2_14_Bold,
          ),
        ),
      );
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
    final currentLanguage = Provider.of<PreferenceProvider>(context, listen: false).language;
    final isKorean = currentLanguage == 'kr';

    switch (_walletImportSource) {
      case WalletImportSource.coconutVault:
        {
          if (isKorean) {
            return [
              TextSpan(
                text: '[1] ',
                style: CoconutTypography.body2_14_Bold.copyWith(height: 1),
              ),
              TextSpan(
                text: t.tooltip.unsigned_tx_qr.open_vault,
                style: CoconutTypography.body2_14.copyWith(height: 1),
              ),
              TextSpan(
                text: ' ${t.tooltip.unsigned_tx_qr.select_wallet(name: widget.walletName)} ',
                style: CoconutTypography.body2_14_Bold.copyWith(height: 1),
              ),
              TextSpan(
                text:
                    ' ${t.tooltip.unsigned_tx_qr.select_menu(menu: '\'${_isMultisig ? t.sign_multisig : t.sign}\'')}',
                style: CoconutTypography.body2_14_Bold.copyWith(height: 1),
              ),
              TextSpan(
                text: t.tooltip.unsigned_tx_qr.scan_qr_below,
                style: CoconutTypography.body2_14.copyWith(height: 1.4),
              ),
            ];
          } else {
            return [
              TextSpan(
                text: '[1] ',
                style: CoconutTypography.body2_14_Bold.copyWith(height: 1),
              ),
              TextSpan(
                text: t.tooltip.unsigned_tx_qr.open_vault,
                style: CoconutTypography.body2_14.copyWith(height: 1),
              ),
              TextSpan(
                text: ', ',
                style: CoconutTypography.body2_14.copyWith(height: 1),
              ),
              TextSpan(
                text: ' ${t.tooltip.unsigned_tx_qr.select_wallet(name: widget.walletName)} ',
                style: CoconutTypography.body2_14_Bold.copyWith(height: 1),
              ),
              TextSpan(
                text: ', ',
                style: CoconutTypography.body2_14.copyWith(height: 1),
              ),
              TextSpan(
                text:
                    ' ${t.tooltip.unsigned_tx_qr.select_menu(menu: '\'${_isMultisig ? t.sign_multisig : t.sign}\'')}',
                style: CoconutTypography.body2_14_Bold.copyWith(height: 1),
              ),
              TextSpan(
                text: ', ',
                style: CoconutTypography.body2_14.copyWith(height: 1),
              ),
              TextSpan(
                text: t.tooltip.unsigned_tx_qr.scan_qr_below,
                style: CoconutTypography.body2_14.copyWith(height: 1.4),
              ),
            ];
          }
        }
      case WalletImportSource.seedSigner:
        {
          if (isKorean) {
            return [
              TextSpan(
                  text:
                      '${t.third_party.seed_signer} ${t.unsigned_tx_qr_screen.hardware_wallet_screen_guide}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_seedsigner.step1} '),
              _em(t.unsigned_tx_qr_screen.guide_seedsigner.step1_em),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_seedsigner.step1_end}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_seedsigner.step2}'),
            ];
          } else {
            return [
              TextSpan(
                  text:
                      '${t.third_party.seed_signer} ${t.unsigned_tx_qr_screen.hardware_wallet_screen_guide}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_seedsigner.step1}'),
              TextSpan(text: '${t.unsigned_tx_qr_screen.guide_seedsigner.step1_end} '),
              _em('${t.unsigned_tx_qr_screen.guide_seedsigner.step1_em}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_seedsigner.step2}'),
            ];
          }
        }
      case WalletImportSource.keystone:
        {
          if (isKorean) {
            return [
              TextSpan(
                  text:
                      '${t.third_party.keystone} ${t.unsigned_tx_qr_screen.hardware_wallet_screen_guide}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_keystone.step1} '),
              _em(t.unsigned_tx_qr_screen.guide_keystone.step1_em),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_keystone.step1_end}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_keystone.step2}'),
            ];
          } else {
            return [
              TextSpan(
                  text:
                      '${t.third_party.keystone} ${t.unsigned_tx_qr_screen.hardware_wallet_screen_guide}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_keystone.step1}'),
              TextSpan(text: '${t.unsigned_tx_qr_screen.guide_keystone.step1_end} '),
              _em('${t.unsigned_tx_qr_screen.guide_keystone.step1_em}\n'),
              TextSpan(text: ' ${t.unsigned_tx_qr_screen.guide_keystone.step2}'),
            ];
          }
        }
      case WalletImportSource.jade:
        {
          if (isKorean) {
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
          } else {
            return [
              TextSpan(
                  text:
                      '${t.third_party.jade} ${t.unsigned_tx_qr_screen.hardware_wallet_screen_guide}\n'),
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
            TextSpan(
                text:
                    '${t.third_party.cold_card} ${t.unsigned_tx_qr_screen.hardware_wallet_screen_guide}\n'),
            TextSpan(text: t.unsigned_tx_qr_screen.guide_coldcard.step1_preposition),
            _em(t.unsigned_tx_qr_screen.guide_coldcard.step1_em),
            TextSpan(text: t.unsigned_tx_qr_screen.guide_coldcard.step1_end),
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
