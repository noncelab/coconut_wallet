import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/extensions/string_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/view_model/utility/p2p_calculator_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_home_screen.dart';
import 'package:coconut_wallet/screens/send/select_wallet_bottom_sheet.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/clipboard_copy_util.dart';
import 'package:coconut_wallet/config/number_format_config.dart';
import 'package:coconut_wallet/utils/numeric_input_formatters.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/ripple_effect.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class P2PCalculatorScreen extends StatefulWidget {
  const P2PCalculatorScreen({super.key});

  @override
  State<P2PCalculatorScreen> createState() => _P2PCalculatorScreenState();
}

class _P2PCalculatorScreenState extends State<P2PCalculatorScreen> with TickerProviderStateMixin {
  static const double _maxBtc = 21000000;
  static const int _maxSats = 2100000000000000; // 21M BTC
  static const double _offlineBottomCardSwapThreshold = 0.4;
  final GlobalKey _shareButtonKey = GlobalKey();

  late P2PCalculatorViewModel _viewModel;

  late final TextEditingController _premiumController;
  late final TextEditingController _inputController;

  late final FocusNode _premiumFocusNode;
  late final FocusNode _premiumMirrorFocusNode;
  late final FocusNode _inputFocusNode;
  late final FocusNode _inputMirrorFocusNode; // 오프라인 상단 더미 카드용

  bool _isUpdatingController = false; // 무한 루프 방지 플래그

  final GlobalKey _billCaptureKey = GlobalKey(); // 거래 계산서 캡처용

  late final AnimationController _lottieController;
  late final AnimationController _flipController;
  late final ScrollController _scrollController;
  @override
  void initState() {
    super.initState();
    _premiumController = TextEditingController(text: _formatLocaleDecimalText('1.0'));
    _inputController = TextEditingController();
    _scrollController = ScrollController();

    _premiumFocusNode = FocusNode();
    _premiumMirrorFocusNode = FocusNode(debugLabel: 'offline_premium_mirror')..canRequestFocus = false;
    _inputFocusNode = FocusNode();
    _inputMirrorFocusNode = FocusNode(debugLabel: 'offline_input_mirror');

    _premiumFocusNode.addListener(_onPremiumFocusChanged);
    _inputFocusNode.addListener(_onInputFocusChanged);

    _lottieController = AnimationController(vsync: this);
    _flipController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _flipController.addListener(_onFlipChanged);
  }

  void _resetCalculator() {
    _isUpdatingController = true;
    _inputController.clear();
    _premiumController.text = _formatLocaleDecimalText('1.0');
    _isUpdatingController = false;
    _viewModel.resetInput();
  }

  @override
  void dispose() {
    _lottieController.dispose();
    _flipController.removeListener(_onFlipChanged);
    _flipController.dispose();
    _premiumController.dispose();
    _inputController.dispose();
    _premiumFocusNode.removeListener(_onPremiumFocusChanged);
    _inputFocusNode.removeListener(_onInputFocusChanged);
    _premiumFocusNode.dispose();
    _premiumMirrorFocusNode.dispose();
    _inputFocusNode.dispose();
    _inputMirrorFocusNode.dispose();
    super.dispose();
  }

  void _onFlipChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onPremiumFocusChanged() {
    if (_premiumFocusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!_scrollController.hasClients) return;
        await Future.delayed(const Duration(milliseconds: 600));
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    } else {
      _formatPremiumOnFocusLost();
    }
    setState(() {});
  }

  void _onInputFocusChanged() {
    if (_inputFocusNode.hasFocus && _viewModel.isOfflineMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 600));
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    } else {
      // 포커스를 잃었을 때 - BTC 단위면 readable 형식으로 변환 (소수부 4자리씩 공백)
      if (_viewModel.inputAssetType == InputAssetType.btc && !_viewModel.currentUnit.isBasedOnSatoshi) {
        final currentInput = _viewModel.inputAmount;
        if (currentInput != null && currentInput > 0) {
          final formatted = BalanceFormatUtil.formatSatoshiToReadableBitcoin(currentInput, forceEightDecimals: false);

          _isUpdatingController = true;
          _inputController.value = TextEditingValue(
            text: formatted,
            selection: TextSelection.collapsed(offset: formatted.length),
          );
          _isUpdatingController = false;
        }
      }
    }
    setState(() {});
  }

  void _formatPremiumOnFocusLost() {
    var text = _normalizeLocaleDecimalText(_premiumController.text);

    if (text.isEmpty) {
      text = '0';
    } else if (text.endsWith('.')) {
      text = '${text}0';
    } else if (!text.contains('.')) {
      text = '$text.0';
    }

    _premiumController.text = _formatLocaleDecimalText(text);
    _viewModel.setPremiumRate(text.toDoubleSafe() ?? 0);
  }

  void _handlePremiumInputChanged(String value) {
    _viewModel.setPremiumRate(value.toDoubleSafe() ?? 0);
    _updateResultOnPremiumChange();
  }

  /// 현재 입력 필드가 소수점 입력을 허용해야 하는지 여부
  /// - fiat: 통화의 소수 자리수(decimalDigits)가 0보다 클 때 (예: USD, EUR)
  /// - btc: sats/BIP-177 기반이 아닌 BTC 단위일 때
  bool get _amountInputAllowsDecimal {
    if (_viewModel.inputAssetType == InputAssetType.fiat) {
      return _viewModel.fiatCode.decimalDigits > 0;
    }
    return !_viewModel.currentUnit.isBasedOnSatoshi;
  }

  List<TextInputFormatter> _amountInputFormatters() {
    if (_viewModel.inputAssetType == InputAssetType.fiat) {
      final decimalDigits = _viewModel.fiatCode.decimalDigits;
      return decimalDigits > 0
          ? [FiatAmountInputFormatter(decimalPlaces: decimalDigits)]
          : [FilteringTextInputFormatter.digitsOnly];
    }
    if (!_viewModel.currentUnit.isBasedOnSatoshi) {
      return [const BtcAmountInputFormatter()];
    }
    return [FilteringTextInputFormatter.digitsOnly];
  }

  void _handleAmountInputChanged(String value) {
    if (_isUpdatingController) return; // 무한 루프 방지

    final sanitized = _sanitizeInput(value, _amountInputAllowsDecimal);

    if (sanitized.isEmpty) {
      _viewModel.setInputAmount(null);
      if (!_isUpdatingController) {
        _isUpdatingController = true;
        _inputController.clear();
        _isUpdatingController = false;
      }
      setState(() {});
      return;
    }

    final shouldUpdateController = value != _inputController.text;

    if (_viewModel.inputAssetType == InputAssetType.fiat) {
      _processFiatInput(sanitized, shouldUpdateController: shouldUpdateController);
    } else if (_viewModel.currentUnit.isBasedOnSatoshi) {
      _processSatsInput(sanitized);
    } else {
      _processBtcInput(sanitized, shouldUpdateController: shouldUpdateController);
    }

    setState(() {});
  }

  void _processFiatInput(String sanitized, {required bool shouldUpdateController}) {
    final fiatCode = _viewModel.fiatCode;
    var fiatText = filterNumericInput(sanitized, decimalPlaces: fiatCode.decimalDigits);
    var minorUnits = _parseFiatTextToMinorUnits(fiatText);

    if (_viewModel.btcPrice != null && _viewModel.btcPrice! > 0) {
      final minorUnitsPrice = _viewModel.btcPrice! * fiatCode.minorUnitsPerWhole;
      final btcFromFiat = minorUnits / minorUnitsPrice;
      if (btcFromFiat > _maxBtc) {
        minorUnits = (_maxBtc * minorUnitsPrice).round();
        fiatText = (minorUnits / fiatCode.minorUnitsPerWhole).toStringAsFixed(fiatCode.decimalDigits);
      }
    }

    // decimalDigits==0인 통화(KRW/JPY)는 입력 필드에 digitsOnly 포매터만 붙어 있어
    // 그룹 구분자(,)를 스스로 넣어주지 않으므로 매 입력마다 직접 그룹 포맷을 적용해야 한다.
    // decimalDigits>0인 통화(USD/EUR)는 FiatAmountInputFormatter가 이미 타이핑 중에
    // 그룹/소수점을 실시간으로 처리하므로, 프로그래매틱 갱신(Quick Add 등)일 때만 갱신한다.
    if (fiatCode.decimalDigits == 0 || shouldUpdateController) {
      final formatted = _formatFiatInputText(fiatText);
      _isUpdatingController = true;
      _inputController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
      _isUpdatingController = false;
    }

    _viewModel.setInputAmount(minorUnits);
  }

  /// fiatText(예: "50.25")를 통화 최소단위(minor unit, 예: cent) 정수로 변환
  int _parseFiatTextToMinorUnits(String fiatText) {
    if (fiatText.isEmpty || fiatText == '.') return 0;
    final value = fiatText.toDoubleSafe() ?? 0;
    return (value * _viewModel.fiatCode.minorUnitsPerWhole).round();
  }

  String _formatFiatInputText(String fiatText) {
    final decimalDigits = _viewModel.fiatCode.decimalDigits;
    final displayText = _formatLocaleDecimalText(fiatText);
    return FiatAmountInputFormatter(decimalPlaces: decimalDigits)
        .formatEditUpdate(
          const TextEditingValue(),
          TextEditingValue(text: displayText, selection: TextSelection.collapsed(offset: displayText.length)),
        )
        .text;
  }

  void _processBtcInput(String sanitized, {required bool shouldUpdateController}) {
    var btcText = filterNumericInput(sanitized, decimalPlaces: 8);
    var sats =
        BalanceFormatUtil.parseAmountTextToSats(
          currentUnit: _viewModel.currentUnit,
          inputText: _formatLocaleDecimalText(btcText),
        ) ??
        0;

    if (sats > _maxSats) {
      sats = _maxSats;
      btcText = _maxBtc.toInt().toString();
    }

    if (shouldUpdateController) {
      final formatted = _formatBtcInputText(btcText);
      _isUpdatingController = true;
      _inputController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
      _isUpdatingController = false;
    }

    _viewModel.setInputAmount(sats);
  }

  String _formatBtcInputText(String btcText) {
    final displayText = _formatLocaleDecimalText(btcText);
    return const BtcAmountInputFormatter()
        .formatEditUpdate(
          const TextEditingValue(),
          TextEditingValue(text: displayText, selection: TextSelection.collapsed(offset: displayText.length)),
        )
        .text;
  }

  void _processSatsInput(String sanitized) {
    var sats = sanitized.toIntSafe() ?? 0;

    if (sats > _maxSats) {
      sats = _maxSats;
    }

    _viewModel.setInputAmount(sats);

    final formatted = sats.toThousandsSeparatedString();
    _isUpdatingController = true;
    _inputController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    _isUpdatingController = false;
  }

  void _updateResultOnPremiumChange() {
    setState(() {});
  }

  Future<void> _captureAndShareBill() async {
    try {
      final RenderRepaintBoundary boundary =
          _billCaptureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/transaction_bill.png');
      await file.writeAsBytes(pngBytes);

      // 버튼 위치 계산
      final box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
      final Rect sharePositionOrigin =
          box != null ? box.localToGlobal(Offset.zero) & box.size : const Rect.fromLTWH(0, 400, 300, 50); // fallback

      AppGuard.disablePrivacyScreen();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: t.utility.p2p_calculator.transaction_bill,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    } catch (e, stack) {
      debugPrint('Failed to capture and share: $e');
      debugPrint('Stack: $stack');
    } finally {
      AppGuard.enablePrivacyScreen();
    }
  }

  void _onSendButtonPressed(int satsAmount) {
    final walletLength = _viewModel.wallets.length;
    switch (walletLength) {
      case 0:
        {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return CoconutPopup(
                languageCode: context.read<PreferenceProvider>().language,
                title: t.utility.p2p_calculator.no_wallet,
                description: t.utility.p2p_calculator.no_wallet_description,
                onTapRight: () {
                  // popup 닫고 홈으로 이동
                  Navigator.of(context).pop();
                  Navigator.of(context).popUntil((route) => route.isFirst);

                  Future.delayed(const Duration(milliseconds: 500), () {
                    WalletHomeScreen.openAddWalletIfActive(); // 홈에서 지갑 추가 바텀시트 열기
                  });
                },
                onTapLeft: () {
                  Navigator.of(context).pop();
                },
                rightButtonText: t.utility.p2p_calculator.add_wallet,
                leftButtonText: t.cancel,
              );
            },
          );
          break;
        }
      case 1:
        {
          final walletId = _viewModel.wallets[0].id;
          Navigator.pushNamed(
            context,
            '/send',
            arguments: {
              'walletId': walletId,
              'sendEntryPoint': SendEntryPoint.home,
              'transactionDraftId': null,
              'initialSatsFromP2P': satsAmount,
            },
          );
          break;
        }

      default:
        {
          CommonBottomSheets.showDraggableBottomSheet(
            context: context,
            childBuilder:
                (scrollController) => P2PSelectWalletBottomSheet(
                  showOnlyMfpWallets: false,
                  scrollController: scrollController,
                  currentUnit: _viewModel.currentUnit,
                  onWalletSelected: (walletId) {
                    debugPrint('satsAmount: $satsAmount');

                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      '/send',
                      arguments: {
                        'walletId': walletId,
                        'sendEntryPoint': SendEntryPoint.home,
                        'transactionDraftId': null,
                        'initialSatsFromP2P': satsAmount,
                      },
                    );
                  },
                ),
          );
          break;
        }
    }
  }

  void _changeInputAsset() {
    final currentInput = _viewModel.inputAmount;

    // 입력값이 있으면 계산 결과를 새로운 입력으로 설정
    if (currentInput != null && currentInput > 0) {
      final calculatedResult = _viewModel.calculate(currentInput);

      // 입력 타입 토글
      _viewModel.toggleInputAssetType();

      // 계산된 결과를 새로운 입력으로 설정
      _viewModel.setInputAmount(calculatedResult);
      // 컨트롤러 업데이트
      _updateControllerWithResult(calculatedResult);
    } else {
      // 입력값이 없으면 그냥 토글만
      _viewModel.toggleInputAssetType();
      _inputController.clear();
      _inputFocusNode.unfocus();
    }

    setState(() {});
  }

  /// BTC/Sats 단위 토글 시 입력 컨트롤러 업데이트
  void _onBtcUnitToggle() {
    final currentInput = _viewModel.inputAmount;
    final prevIsBasedOnSatoshi = _viewModel.currentUnit.isBasedOnSatoshi;
    FocusScope.of(context).unfocus();
    // 단위 토글
    _viewModel.cycleBtcUnit();

    // 입력값이 있으면 컨트롤러를 새 단위로 재포맷
    if (currentInput != null && currentInput > 0 && _viewModel.inputAssetType == InputAssetType.btc) {
      _isUpdatingController = true;

      if (prevIsBasedOnSatoshi && !_viewModel.currentUnit.isBasedOnSatoshi) {
        // Sats → BTC 전환 (readable bitcoin 형식)
        final formatted = _viewModel.formatBtc(currentInput);
        _inputController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      } else if (!prevIsBasedOnSatoshi && _viewModel.currentUnit.isBasedOnSatoshi) {
        // BTC → Sats 전환
        final formatted = currentInput.toThousandsSeparatedString();
        _inputController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }

      _isUpdatingController = false;
    } else {
      // 입력값이 없으면 focus 해제하여 placeholder가 보이도록
      _inputFocusNode.unfocus();
    }

    setState(() {});
  }

  /// 토글 후 컨트롤러를 결과값으로 업데이트
  void _updateControllerWithResult(int result) {
    _isUpdatingController = true;

    if (_viewModel.inputAssetType == InputAssetType.fiat) {
      // BTC → Fiat로 전환: result는 통화 최소단위(minor unit) 정수
      final formatted = _viewModel.formatFiatResult(result);
      _inputController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    } else {
      // Fiat → BTC로 전환
      if (_viewModel.currentUnit.isBasedOnSatoshi) {
        // Sats 단위: 정수 포맷
        final formatted = result.toThousandsSeparatedString();
        _inputController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      } else {
        // BTC 단위: readable bitcoin 형식 (trailing zero 제거)
        final formatted = _viewModel.formatBtc(result);
        _inputController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }

    _isUpdatingController = false;
  }

  String _sanitizeInput(String value, bool allowDecimal) {
    if (!allowDecimal) {
      return value.replaceAll(RegExp(r'[^0-9]'), '');
    } else {
      final normalizedValue = normalizeNumTextForNumParsing(value);
      final buffer = StringBuffer();
      bool dotSeen = false;
      for (final ch in normalizedValue.split('')) {
        if (ch == '.' && !dotSeen) {
          buffer.write('.');
          dotSeen = true;
        } else if (RegExp(r'[0-9]').hasMatch(ch)) {
          buffer.write(ch);
        }
      }
      return buffer.toString();
    }
  }

  String formatResultAmount(int result) {
    if (_viewModel.inputAssetType == InputAssetType.fiat) {
      return _viewModel.formatSatsResult(result);
    } else {
      return _viewModel.formatFiatResult(result);
    }
  }

  String _formatLocaleDecimalText(String text) {
    return text.replaceAll('.', NumberFormatConfig.instance.decimalSeparator);
  }

  String _normalizeLocaleDecimalText(String text) {
    return text.replaceAll(NumberFormatConfig.instance.decimalSeparator, '.');
  }

  double _parsePremiumRate() {
    return _premiumController.text.toDoubleSafe() ?? 0;
  }

  String _formatPremiumAmount(double amount) {
    final fixedText = amount.toStringAsFixed(2);
    final parts = fixedText.split('.');
    final integerText = (parts[0].toIntSafe() ?? 0).toThousandsSeparatedString();
    final decimalText = parts.length > 1 ? parts[1] : '';

    if (decimalText == '00') {
      return integerText;
    }

    return '$integerText${NumberFormatConfig.instance.decimalSeparator}$decimalText';
  }

  void _onShowTransactionBill() {
    if (!_viewModel.isNetworkOn) {
      CoconutToast.showToast(context: context, text: t.errors.network_error, isVisibleIcon: true);
      return;
    }
    final input = _viewModel.inputAmount;
    if (input == null || input == 0) {
      CoconutToast.showToast(
        context: context,
        text: t.utility.p2p_calculator.enter_amount_first,
        iconPath: 'assets/svg/triangle-warning.svg',
        level: CoconutToastLevel.warning,
        isVisibleIcon: true,
      );
      return;
    }

    final int result = _viewModel.calculate(input);
    final referenceDateTime = DateTime.now();
    final referenceDateTimeString =
        '${referenceDateTime.year.toString().substring(2)}-${referenceDateTime.month.toString().padLeft(2, '0')}-${referenceDateTime.day.toString().padLeft(2, '0')} ${referenceDateTime.hour.toString().padLeft(2, '0')}:${referenceDateTime.minute.toString().padLeft(2, '0')}:${referenceDateTime.second.toString().padLeft(2, '0')}';

    final btcPriceStr = _viewModel.btcPrice?.toThousandsSeparatedString() ?? '-';
    final fiatAmountStr =
        _viewModel.inputAssetType == InputAssetType.fiat
            ? _viewModel.formatFiatResult(input)
            : _viewModel.formatFiatResult(result);
    final btcAmountStr =
        _viewModel.inputAssetType == InputAssetType.fiat
            ? _viewModel.formatSatsResult(result)
            : _viewModel.formatSatsResult(input);
    final premiumRateValueStr = _formatLocaleDecimalText(_premiumController.text);
    final premiumRateStr = '$premiumRateValueStr%';

    final premiumRate = _parsePremiumRate();
    // input/result는 통화 최소단위(minor unit) 정수이므로, whole unit(달러/원 등)으로 환산한 뒤 프리미엄을 계산한다.
    final fiatMinorUnitsAmount = _viewModel.inputAssetType == InputAssetType.fiat ? input : result;
    final fiatWholeUnitsAmount = fiatMinorUnitsAmount / _viewModel.fiatCode.minorUnitsPerWhole;
    final double premiumAmount = fiatWholeUnitsAmount * premiumRate / 100;

    // premiumAmount를 BTC 가격으로 변환하여 sats로 표시
    final btcPrice = _viewModel.btcPrice ?? 0;
    final premiumSats = btcPrice > 0 ? ((premiumAmount / btcPrice) * 100000000).round() : 0;

    final premiumAmountStr = _formatPremiumAmount(premiumAmount);
    final premiumSatsStr = premiumSats.toThousandsSeparatedString();

    vibrateLight();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width,
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: context.coconutColors.popupBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RepaintBoundary(
                        key: _billCaptureKey,
                        child: Container(
                          color: context.coconutColors.popupBackground,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CoconutLayout.spacing_1000h,
                              Align(
                                alignment: Alignment.center,
                                child: Text(
                                  t.utility.p2p_calculator.transaction_bill,
                                  style: CoconutTypography.heading3_21_Bold,
                                ),
                              ),
                              CoconutLayout.spacing_900h,
                              // 입력값
                              _buildBillRow(
                                _viewModel.inputAssetType == InputAssetType.fiat
                                    ? _viewModel.fiatCode.code
                                    : _viewModel.currentUnit.symbol,
                                _viewModel.inputAssetType == InputAssetType.fiat
                                    ? _viewModel.formatFiatResult(input)
                                    : _viewModel.formatSatsResult(input),
                                canCopy: true,
                              ),
                              const SizedBox(height: 8),
                              // 결과값
                              _buildBillRow(
                                _viewModel.inputAssetType == InputAssetType.fiat
                                    ? _viewModel.currentUnit.symbol
                                    : _viewModel.fiatCode.code,
                                _viewModel.inputAssetType == InputAssetType.fiat
                                    ? _viewModel.formatSatsResult(result)
                                    : _viewModel.formatFiatResult(result),
                                canCopy: true,
                              ),
                              const SizedBox(height: 24),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 15),
                                child: Divider(color: context.coconutColors.primaryText.withAlpha(50), height: 1),
                              ),
                              const SizedBox(height: 24),
                              _buildBillRow(
                                t.utility.p2p_calculator.reference_price,
                                '${_viewModel.fiatCode.symbol} ${_viewModel.btcPrice?.toThousandsSeparatedString() ?? '-'} / BTC',
                              ),
                              const SizedBox(height: 20),
                              _buildBillRow(
                                t.utility.p2p_calculator.reference_datetime,
                                referenceDateTimeString,
                                valueLineHeight: 1.0,
                              ),
                              const SizedBox(height: 20),
                              _buildBillRow(
                                t.utility.p2p_calculator.transaction_premium,
                                '$premiumRateValueStr %',
                                valueLineHeight: 1.0,
                              ),
                              const SizedBox(height: 2),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${_viewModel.fiatCode.symbol} $premiumAmountStr ($premiumSatsStr sats)',
                                      style: CoconutTypography.body3_12_Number.copyWith(
                                        color: context.coconutColors.mutedText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              CoconutLayout.spacing_800h,
                            ],
                          ),
                        ),
                      ),
                      _buildBillActions(
                        btcPriceStr,
                        fiatAmountStr,
                        btcAmountStr,
                        referenceDateTimeString,
                        premiumRateStr,
                        premiumAmountStr,
                        premiumSatsStr,
                        _viewModel.inputAssetType == InputAssetType.fiat ? result : input,
                      ),
                      CoconutLayout.spacing_600h,
                    ],
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      color: context.coconutColors.primaryText,
                      icon: SvgPicture.asset(
                        'assets/svg/close.svg',
                        colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBillRow(String label, String value, {bool canCopy = false, double valueLineHeight = 1.4}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: CoconutTypography.body3_12.copyWith(
              height: 1.0,
              letterSpacing: -0.12,
              fontWeight: FontWeight.w500,
              color: context.coconutColors.secondaryText,
            ),
          ),
          if (canCopy)
            _CopyableText(value: value)
          else
            Text(
              value,
              style: CoconutTypography.body2_14_Number.copyWith(
                color: context.coconutColors.primaryText,
                height: valueLineHeight,
                letterSpacing: -0.28,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBillActions(
    String btcPriceStr,
    String fiatAmountStr,
    String btcAmountStr,
    String referenceDateTime,
    String premiumRateStr,
    String premiumAmountStr,
    String premiumSatsStr,
    int satsAmount,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          CoconutUnderlinedButton(
            text: t.utility.p2p_calculator.copy_all,
            textStyle: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText),
            onTap: () async {
              final textToCopy = _viewModel.generateTransactionBill(
                btcPriceStr,
                fiatAmountStr,
                btcAmountStr,
                referenceDateTime,
                premiumRateStr,
                premiumAmountStr,
                premiumSatsStr,
              );
              await ClipboardCopyUtil.copyWithToast(context, text: textToCopy);
            },
          ),
          CoconutLayout.spacing_200h,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: ShrinkAnimationButton(
                  borderRadius: 8,
                  pressedColor: context.coconutColors.surfacePressed,
                  onPressed: () {
                    _onSendButtonPressed(satsAmount);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/svg/send-plane.svg',
                          colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
                          width: 14,
                          height: 14,
                        ),
                        CoconutLayout.spacing_200w,
                        Text(
                          t.utility.p2p_calculator.send,
                          style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              CoconutLayout.spacing_300w,
              Expanded(
                child: ShrinkAnimationButton(
                  borderRadius: 8,
                  pressedColor: context.coconutColors.surfacePressed,
                  onPressed: () {
                    _captureAndShareBill();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/svg/export.svg',
                          colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
                          width: 14,
                          height: 14,
                        ),
                        CoconutLayout.spacing_200w,
                        Text(
                          t.utility.p2p_calculator.share,
                          style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final usableHeight = mediaQuery.size.height - mediaQuery.padding.top - mediaQuery.padding.bottom - 56;

    return ChangeNotifierProvider<P2PCalculatorViewModel>(
      create:
          (context) => P2PCalculatorViewModel(
            context.read<PreferenceProvider>(),
            context.read<ConnectivityProvider>(),
            context.read<PriceProvider>(),
            context.read<WalletProvider>(),
          ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: context.coconutColors.background,
          appBar: CoconutAppBar.build(
            context: context,
            title: t.utility.p2p_calculator.calculator,
            actionButtonList: [
              IconButton(
                onPressed: () {
                  _viewModel.toggleP2PMode();
                  if (_viewModel.isOfflineMode) {
                    _lottieController.forward();
                    _flipController.forward();
                  } else {
                    _lottieController.reverse();
                    _flipController.reverse();
                  }
                },
                icon: Lottie.asset(
                  'assets/lottie/online-offline-switch.json',
                  width: 24,
                  height: 24,
                  controller: _lottieController,
                  delegates: LottieDelegates(
                    values: [
                      ValueDelegate.colorFilter([
                        '**',
                      ], value: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcATop)),
                    ],
                  ),
                  onLoaded: (composition) {
                    _lottieController.duration = composition.duration;
                  },
                ),
              ),
              IconButton(
                onPressed: _onShowTransactionBill,
                icon: SvgPicture.asset(
                  'assets/svg/hand-shake.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
                ),
              ),
            ],
            isBottom: true,
          ),
          body: Consumer<P2PCalculatorViewModel>(
            builder: (context, viewModel, child) {
              _viewModel = viewModel;
              if (!viewModel.isNetworkOn && _inputController.text.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _resetCalculator();
                });
              }
              return SizedBox(
                height: usableHeight,
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      controller: _scrollController,
                      child: Container(
                        width: MediaQuery.sizeOf(context).width,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CoconutLayout.spacing_400h,
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              alignment: Alignment.topCenter,
                              child: SizedBox(
                                height: viewModel.isOfflineMode ? 0 : null,
                                child: _buildPriceHeader(isVisible: !viewModel.isOfflineMode),
                              ),
                            ),
                            _buildCalculatorCards(viewModel, usableHeight),
                            CoconutLayout.spacing_2500h,
                          ],
                        ),
                      ),
                    ),
                    _buildKeyboardToolbar(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPriceHeader({bool isVisible = true, bool isFiatButtonVisible = true}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildCurrentPriceWidget(isVisible),
        if (_viewModel.isNetworkOn && isFiatButtonVisible)
          ShrinkAnimationButton(
            pressedColor: context.coconutColors.surfacePressed,
            onPressed: () async {
              await _viewModel.onFiatUnitChange();
              _resetCalculator();
              _inputFocusNode.unfocus();
            },
            defaultColor: context.coconutColors.surface,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              constraints: const BoxConstraints(minWidth: 60),
              child: Center(
                child: Text(
                  _viewModel.fiatCode.name,
                  style: CoconutTypography.body2_14_Bold.copyWith(
                    color: context.coconutColors.primaryText,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCurrentPriceWidget(bool isVisible) {
    if (!isVisible) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 7.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.2)),
            child: Row(
              children: [
                Text(
                  '${t.utility.p2p_calculator.one_btc} = ',
                  style: CoconutTypography.body1_16_Number.setColor(context.coconutColors.primaryText),
                ),
                Text(
                  _viewModel.formattedOneBtcPrice,
                  style: CoconutTypography.body1_16_Number.setColor(context.coconutColors.primaryText),
                ),
              ],
            ),
          ),
          _buildExchangePriceLabel(),
        ],
      ),
    );
  }

  Widget _buildExchangePriceLabel() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        final isOutgoing = animation.status == AnimationStatus.reverse;
        final slideAnimation = Tween<Offset>(
          begin: isOutgoing ? const Offset(0, -0.5) : const Offset(0, 0.5),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));
        return ClipRect(
          child: FadeTransition(opacity: animation, child: SlideTransition(position: slideAnimation, child: child)),
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.centerLeft,
          children: [...previousChildren, if (currentChild != null) currentChild],
        );
      },
      child:
          _viewModel.isBtcPriceAvailable
              ? Text(
                _getExchangeLabel(_viewModel.fiatCode),
                key: ValueKey('exchange_${_viewModel.fiatCode.name}'),
                style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
              )
              : Text(
                t.utility.p2p_calculator.offline_price_unavailable,
                key: const ValueKey('offline'),
                style: CoconutTypography.body3_12.setColor(context.coconutColors.danger),
              ),
    );
  }

  String _getExchangeLabel(FiatCode fiatCode) {
    switch (fiatCode) {
      case FiatCode.KRW:
        return t.utility.p2p_calculator.upbit_price;
      case FiatCode.USD:
        return t.utility.p2p_calculator.binance_price;
      case FiatCode.JPY:
        return t.utility.p2p_calculator.bitflyer_price;
      case FiatCode.EUR:
        return t.utility.p2p_calculator.binance_price;
    }
  }

  Widget _buildCalculatorCards(P2PCalculatorViewModel viewModel, double usableHeight) {
    final hasInput = viewModel.inputAmount != null && viewModel.inputAmount! > 0;
    final result = hasInput ? viewModel.calculate(viewModel.inputAmount!) : 0;
    final placeholder = viewModel.getPlaceholder(isInputCard: true);
    final isOffline = viewModel.isOfflineMode;
    // 가격 조회가 불가능하면(오프라인 등) '-'로 표시
    final isResultActive = hasInput && viewModel.isBtcPriceAvailable;
    final resultText =
        !viewModel.isBtcPriceAvailable
            ? '-'
            : hasInput
            ? formatResultAmount(result)
            : viewModel.getPlaceholder(isInputCard: false);
    final expandedHeight = (usableHeight) / 2 - kToolbarHeight;
    final cardHeight = isOffline ? expandedHeight : 175.0;

    Widget frontCard = _buildInputCardWidget(
      controller: _inputController,
      focusNode: _inputFocusNode,
      placeholderText: placeholder,
      prefix: viewModel.inputCardPrefix,
      postfix: viewModel.inputCardPostfix,
      premiumController: _premiumController,
      premiumFocusNode: _premiumFocusNode,
      onUnitToggle: viewModel.inputAssetType == InputAssetType.btc ? _onBtcUnitToggle : null,
      fixedHeight: cardHeight,
    );

    // onTap이 동작해야 하는 조건:
    // - isOfflineMode인 경우에는 항상
    // - isOfflineMode가 아니면, inputAssetType이 fiat일 때만
    final bool shouldHandleUnitToggle = isOffline || viewModel.inputAssetType == InputAssetType.fiat;
    final bool showOfflineBottomCard = isOffline && _flipController.value >= _offlineBottomCardSwapThreshold;
    final bool showOfflineBackCard = _flipController.value >= _offlineBottomCardSwapThreshold;

    final backContent =
        showOfflineBackCard
            ? _buildOfflineCardWidget(
              enablePremiumInput: false,
              enableInput: false,
              resultText: resultText,
              isActive: isResultActive,
              prefix: viewModel.resultCardPrefix,
              postfix: viewModel.resultCardPostfix,
              isFiatButtonVisible: false,
            )
            : _buildResultCardWidget(
              isActive: isResultActive,
              resultText: resultText,
              prefix: viewModel.resultCardPrefix,
              postfix: viewModel.resultCardPostfix,
              onTap: null,
            );

    // backCard: 오프라인 모드에서 뒤집힌 카드
    final backCard = _buildCardShell(fixedHeight: cardHeight, child: backContent, onTap: null);

    final frontCardShell = _buildCardShell(
      fixedHeight: cardHeight,
      child: frontCard,
      onTap: viewModel.inputAssetType == InputAssetType.btc ? _onBtcUnitToggle : null,
    );

    Widget flippingCard = AnimatedBuilder(
      animation: _flipController,
      child: frontCardShell,
      builder: (context, child) {
        final angle = _flipController.value * math.pi;
        final isBack = _flipController.value > 0.5;

        final visible =
            isBack
                ? Transform(
                  alignment: Alignment.center,
                  transform:
                      Matrix4.identity()
                        ..rotateX(math.pi)
                        ..rotateZ(math.pi),
                  child: backCard,
                )
                : child!;

        return Transform(
          alignment: Alignment.center,
          transform:
              Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(angle),
          child: visible,
        );
      },
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        Column(
          children: [
            flippingCard,
            CoconutLayout.spacing_400h,
            _buildCardShell(
              fixedHeight: cardHeight,
              child:
                  showOfflineBottomCard
                      ? _buildOfflineCardWidget(
                        enablePremiumInput: true,
                        enableInput: true,
                        resultText: resultText,
                        isActive: isResultActive,
                        prefix: viewModel.resultCardPrefix,
                        postfix: viewModel.resultCardPostfix,
                      )
                      : _buildResultCardWidget(
                        isActive: isResultActive,
                        resultText: resultText,
                        prefix: viewModel.resultCardPrefix,
                        postfix: viewModel.resultCardPostfix,
                        onTap: shouldHandleUnitToggle ? _onBtcUnitToggle : null,
                      ),
              onTap: shouldHandleUnitToggle ? _onBtcUnitToggle : null,
            ),
          ],
        ),
        AnimatedScale(
          scale: isOffline ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          child: _buildChangeInputAssetButton(),
        ),
      ],
    );
  }

  Widget _buildChangeInputAssetButton() {
    if (_viewModel.isOfflineMode) {
      return ShrinkAnimationButton(
        onPressed: _changeInputAsset,
        defaultColor: context.coconutColors.surfaceButton,
        pressedColor: context.coconutColors.surfacePressed,
        borderRadius: 8,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: SvgPicture.asset(
              'assets/svg/arrow-top-down.svg',
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(context.coconutColors.iconSubDefault, BlendMode.srcIn),
            ),
          ),
        ),
      );
    }
    return ShrinkAnimationButton(
      onPressed: _changeInputAsset,
      defaultColor: context.coconutColors.surfaceButton,
      pressedColor: context.coconutColors.surfacePressed,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Center(
          child: SvgPicture.asset(
            'assets/svg/arrow-top-down.svg',
            width: 32,
            height: 32,
            colorFilter: ColorFilter.mode(context.coconutColors.iconSubDefault, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }

  Widget _buildInputCardWidget({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String placeholderText,
    TextEditingController? premiumController,
    FocusNode? premiumFocusNode,
    String? prefix,
    String? postfix,
    VoidCallback? onUnitToggle,
    double? fixedHeight,
    bool hidePlaceholderOnFocus = true,
  }) {
    final hasInput = _viewModel.inputAmount != null;
    final textColor = hasInput ? context.coconutColors.primaryText : context.coconutColors.tertiaryText;
    // focus가 있고 입력값이 비어있으면 placeholder 숨김 (단, controller.text가 있으면 표시)
    final shouldHidePlaceholder = hidePlaceholderOnFocus && focusNode.hasFocus && controller.text.isEmpty;
    final effectivePlaceholder = shouldHidePlaceholder ? '' : placeholderText;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.2)),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: focusNode.hasFocus ? null : onUnitToggle,
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              constraints: BoxConstraints(minHeight: fixedHeight ?? 175),
              height: fixedHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: context.coconutColors.inputSurface,
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (prefix != null)
                        Text('$prefix ', style: CoconutTypography.heading2_28_Bold.setColor(textColor)),
                      Flexible(
                        child: IntrinsicWidth(
                          child: CoconutTextField(
                            key: ValueKey('input_textfield_$placeholderText'),
                            placeholderColor: context.coconutColors.tertiaryText,
                            enabled: _viewModel.isNetworkOn,
                            maxLines: 1,
                            controller: controller,
                            focusNode: focusNode,
                            placeholderText: effectivePlaceholder,
                            textInputFormatter: _amountInputFormatters(),
                            onChanged: _handleAmountInputChanged,
                            textInputType:
                                _amountInputAllowsDecimal
                                    ? const TextInputType.numberWithOptions(signed: false, decimal: true)
                                    : TextInputType.number,
                            textInputAction: TextInputAction.done,
                            enableInteractiveSelection: false,
                            isVisibleBorder: false,
                            textAlign: TextAlign.center,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (postfix != null)
                        Text(' $postfix', style: CoconutTypography.heading2_28_Bold.setColor(textColor)),
                    ],
                  ),
                ),
              ),
            ),
            if (premiumController != null && premiumFocusNode != null && _viewModel.isNetworkOn)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildPremiumInputWidget(
                    premiumFocusNode: premiumFocusNode,
                    premiumController: premiumController,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumInputWidget({
    required FocusNode premiumFocusNode,
    required TextEditingController premiumController,
    bool isInteractive = true,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap:
          isInteractive
              ? () {
                if (!_viewModel.isNetworkOn) return;
                premiumFocusNode.requestFocus();
                final text = premiumController.text;
                if (text.isNotEmpty) {
                  premiumController.selection = TextSelection.fromPosition(TextPosition(offset: text.length));
                }
              }
              : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: context.coconutColors.surfaceSectionBreak,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${t.utility.p2p_calculator.premium} ',
              style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
            ),
            IntrinsicWidth(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 10),
                child: Transform.translate(
                  offset: const Offset(0, -1.5),
                  child: CoconutTextField(
                    enabled: _viewModel.isNetworkOn,
                    controller: premiumController,
                    focusNode: isInteractive ? premiumFocusNode : _premiumMirrorFocusNode,
                    padding: EdgeInsets.zero,
                    maxLines: 1,
                    height: 22,
                    textInputAction: TextInputAction.done,
                    textInputType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                    textInputFormatter: const [RateInputFormatter(integerPlaces: 2, decimalPlaces: 1)],
                    onChanged: _handlePremiumInputChanged,
                    textAlign: TextAlign.end,
                    isVisibleBorder: false,
                  ),
                ),
              ),
            ),
            Text('%', style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText)),
          ],
        ),
      ),
    );
  }

  Widget _buildCardShell({required double fixedHeight, required Widget child, VoidCallback? onTap}) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.2)),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          constraints: BoxConstraints(minHeight: fixedHeight),
          height: fixedHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: context.coconutColors.inputSurface),
          child: child,
        ),
      ),
    );
  }

  Widget _buildResultCardWidget({
    required bool isActive,
    required String resultText,
    String? prefix,
    String? postfix,
    VoidCallback? onTap,
  }) {
    final textColor = isActive ? context.coconutColors.primaryText : context.coconutColors.tertiaryText;

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (prefix != null) Text('$prefix ', style: CoconutTypography.heading2_28_Bold.setColor(textColor)),
            Text(resultText, style: CoconutTypography.heading2_28_Bold.setColor(textColor)),
            if (postfix != null) Text(' $postfix', style: CoconutTypography.heading2_28_Bold.setColor(textColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineCardWidget({
    required bool enablePremiumInput,
    required bool enableInput,
    required String resultText,
    required bool isActive,
    String? prefix,
    String? postfix,
    bool isFiatButtonVisible = true,
  }) {
    return IgnorePointer(
      ignoring: !enableInput,
      child: Column(
        children: [
          _buildPriceHeader(isFiatButtonVisible: isFiatButtonVisible),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInputCardWidget(
                    controller: _inputController,
                    focusNode: enableInput ? _inputFocusNode : _inputMirrorFocusNode,
                    placeholderText: _viewModel.getPlaceholder(isInputCard: true),
                    prefix: _viewModel.inputCardPrefix,
                    postfix: _viewModel.inputCardPostfix,
                    fixedHeight: 55,
                    hidePlaceholderOnFocus: false,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (enablePremiumInput)
                        Row(
                          children: [
                            _buildChangeInputAssetButton(),
                            CoconutLayout.spacing_100w,
                            if (_viewModel.isNetworkOn)
                              _buildPremiumInputWidget(
                                premiumFocusNode: _premiumFocusNode,
                                premiumController: _premiumController,
                              ),
                          ],
                        )
                      else
                        IgnorePointer(
                          ignoring: true,
                          child:
                              _viewModel.isNetworkOn
                                  ? _buildPremiumInputWidget(
                                    premiumFocusNode: _premiumFocusNode,
                                    premiumController: _premiumController,
                                    isInteractive: false,
                                  )
                                  : const SizedBox.shrink(),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
                    child: _buildResultCardWidget(
                      isActive: isActive,
                      resultText: resultText,
                      prefix: prefix,
                      postfix: postfix,
                      onTap: _viewModel.inputAssetType == InputAssetType.fiat ? _onBtcUnitToggle : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardToolbar() {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final hasFocus = _premiumFocusNode.hasFocus || _inputFocusNode.hasFocus;

    if (!hasFocus || keyboardHeight == 0) {
      return const SizedBox.shrink();
    }

    final buttonData = _getQuickAddAmounts();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          color: context.coconutColors.surfaceCard,
          child: Row(
            children: [
              for (int i = 0; i < buttonData.length; i++) ...[
                if (i > 0) const SizedBox(width: 3),
                Flexible(
                  fit: FlexFit.tight,
                  child: RippleEffect(
                    borderRadius: 8,
                    onTap: () {
                      _onToolbarButtonPressed(buttonData[i]['value']!);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: context.coconutColors.border, width: 1.2),
                        borderRadius: BorderRadius.circular(8),
                      ),

                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          buttonData[i]['label']!,
                          style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _onToolbarButtonPressed(String value) {
    if (_premiumFocusNode.hasFocus) {
      final currentPremium = _parsePremiumRate();
      final addValue = _formatLocaleDecimalText(value).toDoubleSafe() ?? 0;
      final newPremium = (currentPremium + addValue).clamp(0.0, 99.9);
      _premiumController.text = _formatLocaleDecimalText(newPremium.toStringAsFixed(1));
      _viewModel.setPremiumRate(newPremium);
      _updateResultOnPremiumChange();
    } else if (_inputFocusNode.hasFocus) {
      if (_viewModel.inputAssetType == InputAssetType.fiat) {
        final fiatCode = _viewModel.fiatCode;
        final currentMinorUnits = _viewModel.inputAmount ?? 0;
        final addMinorUnits = _parseFiatTextToMinorUnits(value); // value는 whole unit 기준 문자열 (예: "10000")
        final nextMinorUnits = currentMinorUnits + addMinorUnits;
        final nextWholeUnitsText = (nextMinorUnits / fiatCode.minorUnitsPerWhole).toStringAsFixed(
          fiatCode.decimalDigits,
        );
        _handleAmountInputChanged(nextWholeUnitsText);
      } else if (_viewModel.currentUnit.isBasedOnSatoshi) {
        final currentValue = _inputController.text.toIntSafe() ?? 0;
        final addValue = value.toIntSafe() ?? 0;
        _handleAmountInputChanged((currentValue + addValue).toString());
      } else {
        final currentSats = _viewModel.inputAmount ?? 0;
        final addSats =
            BalanceFormatUtil.parseAmountTextToSats(
              currentUnit: _viewModel.currentUnit,
              inputText: _formatLocaleDecimalText(value),
            ) ??
            0;
        final nextSats = (currentSats + addSats).clamp(0, _maxSats).toInt();
        _handleAmountInputChanged(BalanceFormatUtil.formatSatoshiToBtcInputText(nextSats));
      }
    }
  }

  /// Quick Add 버튼 데이터 반환
  List<Map<String, String>> _getQuickAddAmounts() {
    final isPremiumFocused = _premiumFocusNode.hasFocus;
    final isInputFocused = _inputFocusNode.hasFocus;
    if (isPremiumFocused) {
      return [
        {'label': '+${_formatLocaleDecimalText('0.1')} %', 'value': '0.1'},
        {'label': '+${_formatLocaleDecimalText('0.5')} %', 'value': '0.5'},
        {'label': '+${_formatLocaleDecimalText('1.0')} %', 'value': '1.0'},
        {'label': '+${_formatLocaleDecimalText('5.0')} %', 'value': '5.0'},
      ];
    }

    if (!isInputFocused) return [];

    if (_viewModel.inputAssetType == InputAssetType.fiat) {
      switch (_viewModel.fiatCode) {
        case FiatCode.KRW:
          return [
            {'label': '+${10000.toThousandsSeparatedString()}', 'value': '10000'},
            {'label': '+${50000.toThousandsSeparatedString()}', 'value': '50000'},
            {'label': '+${100000.toThousandsSeparatedString()}', 'value': '100000'},
            {'label': '+${500000.toThousandsSeparatedString()}', 'value': '500000'},
          ];
        case FiatCode.USD:
          return [
            {'label': '+10', 'value': '10'},
            {'label': '+50', 'value': '50'},
            {'label': '+100', 'value': '100'},
            {'label': '+500', 'value': '500'},
          ];
        case FiatCode.JPY:
          return [
            {'label': '+${1000.toThousandsSeparatedString()}', 'value': '1000'},
            {'label': '+${5000.toThousandsSeparatedString()}', 'value': '5000'},
            {'label': '+${10000.toThousandsSeparatedString()}', 'value': '10000'},
            {'label': '+${50000.toThousandsSeparatedString()}', 'value': '50000'},
          ];
        case FiatCode.EUR:
          return [
            {'label': '+10', 'value': '10'},
            {'label': '+50', 'value': '50'},
            {'label': '+100', 'value': '100'},
            {'label': '+500', 'value': '500'},
          ];
      }
    } else {
      // BTC/Sats 입력
      if (_viewModel.currentUnit.isBasedOnSatoshi) {
        return [
          {'label': '+${10000.toThousandsSeparatedString()}', 'value': '10000'},
          {'label': '+${50000.toThousandsSeparatedString()}', 'value': '50000'},
          {'label': '+${100000.toThousandsSeparatedString()}', 'value': '100000'},
          {'label': '+${500000.toThousandsSeparatedString()}', 'value': '500000'},
        ];
      } else {
        return [
          {'label': '+${_formatLocaleDecimalText('0.0001')}', 'value': '0.0001'},
          {'label': '+${_formatLocaleDecimalText('0.0005')}', 'value': '0.0005'},
          {'label': '+${_formatLocaleDecimalText('0.001')}', 'value': '0.001'},
          {'label': '+${_formatLocaleDecimalText('0.005')}', 'value': '0.005'},
        ];
      }
    }
  }
}

class _CopyableText extends StatefulWidget {
  final String value;

  const _CopyableText({required this.value});

  @override
  State<_CopyableText> createState() => _CopyableTextState();
}

class _CopyableTextState extends State<_CopyableText> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() {
          _isPressed = true;
        });
      },
      onTapUp: (_) {
        setState(() {
          _isPressed = false;
        });
        Clipboard.setData(ClipboardData(text: widget.value.replaceAll(',', '').replaceAll(' ', '')));
      },
      onTapCancel: () {
        setState(() {
          _isPressed = false;
        });
      },
      child: Container(
        constraints: BoxConstraints(minWidth: MediaQuery.sizeOf(context).width * 0.3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              widget.value,
              style: CoconutTypography.body1_16_Number.copyWith(
                color: _isPressed ? context.coconutColors.secondaryText : context.coconutColors.primaryText,
                height: 1.4,
                letterSpacing: -0.32,
              ),
            ),
            CoconutLayout.spacing_100w,
            SvgPicture.asset(
              'assets/svg/copy.svg',
              colorFilter: ColorFilter.mode(
                _isPressed ? context.coconutColors.secondaryText : context.coconutColors.primaryText,
                BlendMode.srcIn,
              ),
              width: 16,
              height: 16,
            ),
          ],
        ),
      ),
    );
  }
}
