import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

class P2PCalculatorScreen extends StatefulWidget {
  const P2PCalculatorScreen({super.key});

  @override
  State<P2PCalculatorScreen> createState() => _P2PCalculatorScreenState();
}

class _P2PCalculatorScreenState extends State<P2PCalculatorScreen> {
  static const double _maxBtc = 21000000;
  final Color keyboardToolbarGray = const Color(0xFF2E2E2E);

  bool isOfflineMode = false; // TODO: viewModel로 이동
  bool isInputChanged = false;
  int? fiatPrice; // TODO: viewModel로 이동
  bool isBtcUnit = true;
  int? _fixedBtcPrice; // 화면 진입 시점의 BTC 가격 (고정)

  bool isSwitched = false;
  bool _isUpdatingAmounts = false; // Amount 컨트롤러 업데이트 중인지 여부
  bool _isUpdatingOnFeeChange = false; // 수수료 변경으로 인한 업데이트 중인지 여부

  // Premium 입력 필드용
  late final TextEditingController _feeController;
  late final FocusNode _feeFocusNode;
  String _previousFeeValue = ''; // 검증을 위한 이전 값 저장
  bool _isValidatingFee = false; // 무한 루프 방지 플래그

  // Amount 입력 필드용 FocusNode 및 Controller
  late final FocusNode _fiatAmountFocusNode;
  late final FocusNode _btcAmountFocusNode;
  late final TextEditingController _fiatAmountController;
  late final TextEditingController _btcAmountController;
  late final DateTime _referenceDateTime;

  late FiatCode _currentFiatUnit;

  double get keyboardHeight => MediaQuery.of(context).viewInsets.bottom;

  @override
  initState() {
    super.initState();
    _referenceDateTime = DateTime.now();
    isBtcUnit = context.read<PreferenceProvider>().isBtcUnit; // TODO: vm으로 이동
    _currentFiatUnit = context.read<PreferenceProvider>().selectedFiat;

    // 화면 진입 시점에 한 번만 BTC 가격 가져오기
    final priceProvider = context.read<PriceProvider>();
    _fixedBtcPrice = priceProvider.currentBitcoinPrice;

    _feeController = TextEditingController(text: '1.0');
    _feeFocusNode = FocusNode();
    _previousFeeValue = '1.0';

    _fiatAmountFocusNode = FocusNode();
    _btcAmountFocusNode = FocusNode();
    _fiatAmountController = TextEditingController();
    _btcAmountController = TextEditingController();

    _feeFocusNode.addListener(() {
      if (!_feeFocusNode.hasFocus && !_isValidatingFee) {
        var text = _feeController.text;
        if (text.isNotEmpty && !text.contains('.')) {
          _isValidatingFee = true;
          final newText = '$text.0';
          _feeController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          );
          _previousFeeValue = newText;
          _isValidatingFee = false;
        }
      }

      if (mounted) {
        setState(() {});
      }
    });
    _fiatAmountFocusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _btcAmountFocusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    _feeController.addListener(() {
      if (_isValidatingFee) return;

      var text = _feeController.text;

      if (text == '.') {
        _isValidatingFee = true;
        const newText = '0.';
        _feeController.value = const TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        );
        _previousFeeValue = newText;
        _isValidatingFee = false;
        return;
      }

      // 정수 2자리, 소수점 이하 1자리만 허용하는 검증
      final regex = RegExp(r'^\d{0,2}(\.\d{0,1})?$');
      if (!regex.hasMatch(text)) {
        // 유효하지 않은 입력이면 이전 값으로 되돌림
        _isValidatingFee = true;
        _feeController.value = TextEditingValue(
          text: _previousFeeValue,
          selection: TextSelection.collapsed(offset: _previousFeeValue.length),
        );
        _isValidatingFee = false;
        return;
      }

      // 정수 부분이 두 자리 이상이고 0으로 시작하면 앞의 0 제거
      if (text.contains('.')) {
        // 소수점이 있는 경우
        final parts = text.split('.');
        final integerPart = parts[0];
        final decimalPart = parts[1];

        // 정수 부분이 두 자리 이상이고 0으로 시작하면 앞의 0 제거
        if (integerPart.length >= 2 && integerPart.startsWith('0')) {
          final cleanedInteger = integerPart.replaceFirst(RegExp(r'^0+'), '');
          text = cleanedInteger.isEmpty ? '0.$decimalPart' : '$cleanedInteger.$decimalPart';
        }
      } else {
        // 소수점이 없는 경우
        // 정수 부분이 두 자리 이상이고 0으로 시작하면 앞의 0 제거
        if (text.length >= 2 && text.startsWith('0')) {
          final cleaned = text.replaceFirst(RegExp(r'^0+'), '');
          text = cleaned.isEmpty ? '0' : cleaned;
        }
      }

      // 값이 변경되었으면 업데이트
      if (text != _feeController.text) {
        _isValidatingFee = true;
        final newLength = text.length;
        _feeController.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: newLength));
        _isValidatingFee = false;
      }

      // 유효한 값이면 이전 값 업데이트
      _previousFeeValue = text;

      // 커서를 마지막으로 이동
      if (text.isNotEmpty) {
        _feeController.selection = TextSelection.fromPosition(TextPosition(offset: text.length));
      }

      // fee가 변경되면 위쪽 위젯 기준으로 아래쪽 위젯 값 업데이트
      if (mounted) {
        debugPrint('feeController.text: ${_feeController.text}');
        _updateAmountsOnFeeChange();
      }
    });
  }

  @override
  void dispose() {
    _feeController.dispose();
    _feeFocusNode.dispose();
    _fiatAmountFocusNode.dispose();
    _btcAmountFocusNode.dispose();
    _fiatAmountController.dispose();
    _btcAmountController.dispose();
    super.dispose();
  }

  /// 위쪽 위젯(기준값)은 유지하고, 아래쪽 위젯만 업데이트
  void _updateAmountControllers() {
    _isUpdatingAmounts = true;
    if (isSwitched) {
      // 위쪽: BTC/Sats 유지, 아래쪽: Fiat 업데이트
      _fiatAmountController.text = getAmountString(isFiat: true);
    } else {
      // 위쪽: Fiat 유지, 아래쪽: BTC/Sats 업데이트
      _btcAmountController.text = getAmountString(isFiat: false);
    }
    _isUpdatingAmounts = false;
  }

  /// 스위치 토글, 단위 변경 시: 위쪽 위젯 기준으로 아래쪽 위젯 값을 새로 계산
  void _updateBothAmountControllers() {
    if (!isInputChanged || fiatPrice == null || fiatPrice == 0) {
      _isUpdatingAmounts = true;
      _fiatAmountController.text = '';
      _btcAmountController.text = '';
      _isUpdatingAmounts = false;
      return;
    }

    _isUpdatingAmounts = true;

    if (isSwitched) {
      // 위쪽: BTC/Sats, 아래쪽: Fiat
      // BTC/Sats 값 기준으로 fiatPrice 새로 계산 (× (1 + fee))
      final btcText = _btcAmountController.text.replaceAll(RegExp(r'[^0-9.]'), '');
      if (btcText.isNotEmpty) {
        double btc;
        if (isBtcUnit) {
          btc = double.tryParse(btcText) ?? 0;
        } else {
          final sats = int.tryParse(btcText) ?? 0;
          btc = sats / 100000000;
        }
        fiatPrice = _calculateFiatFromBtc(btc);
      }
      _fiatAmountController.text = getAmountString(isFiat: true);
    } else {
      // 위쪽: Fiat, 아래쪽: BTC/Sats
      // fiatPrice 유지, BTC/Sats만 새로 계산 (× (1 - fee))
      _btcAmountController.text = getAmountString(isFiat: false);
    }

    _isUpdatingAmounts = false;
  }

  /// 현재 입력 중인 필드를 제외한 반대쪽 필드만 업데이트
  void _updateAmountController(bool isFiatInput) {
    _isUpdatingAmounts = true;
    if (isFiatInput) {
      // fiat 입력 중이면 BTC 필드만 업데이트
      _btcAmountController.text = getAmountString(isFiat: false);
    } else {
      // BTC/sats 입력 중이면 fiat 필드만 업데이트
      _fiatAmountController.text = getAmountString(isFiat: true);
    }
    _isUpdatingAmounts = false;
  }

  /// 입력값에서 허용되지 않는 문자를 제거
  String _sanitizeInput(String value, bool isFiat) {
    if (isFiat || !isBtcUnit) {
      // fiat 또는 sats: 숫자만 허용
      return value.replaceAll(RegExp(r'[^0-9]'), '');
    } else {
      // BTC 단위: 숫자와 소수점 하나만 허용
      final buffer = StringBuffer();
      bool dotSeen = false;
      for (final ch in value.split('')) {
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

  /// Amount 입력 변경 처리 메인 핸들러
  void _handleAmountInputChanged(String value, bool isFiat, bool isUpsideWidget) {
    if (_isUpdatingAmounts) return;

    final sanitized = _sanitizeInput(value, isFiat);
    debugPrint('sanitized: $sanitized');

    // 불허 문자가 섞여 있었으면, 정제된 값으로 즉시 UI에 반영
    if (sanitized != value) {
      _isUpdatingAmounts = true;
      final controller = isFiat ? _fiatAmountController : _btcAmountController;
      controller.value = TextEditingValue(
        text: sanitized,
        selection: TextSelection.collapsed(offset: sanitized.length),
      );
      _isUpdatingAmounts = false;
    }

    // 빈 문자열이면 초기화
    if (sanitized.isEmpty) {
      setState(() {
        fiatPrice = 0;
        isInputChanged = false;
        _updateAmountController(isFiat);
      });
      return;
    }

    // 분기 처리
    if (isFiat) {
      _processFiatInput(sanitized);
    } else if (isBtcUnit) {
      _processBtcInput(sanitized, isUpsideWidget);
    } else {
      _processSatsInput(sanitized);
    }
  }

  /// Fiat 입력 처리
  void _processFiatInput(String sanitized) {
    var intVal = int.tryParse(sanitized) ?? 0;

    // 최대 BTC 제한 체크
    if (_fixedBtcPrice != null && _fixedBtcPrice != 0) {
      final btcFromFiat = intVal / _fixedBtcPrice!;
      if (btcFromFiat > _maxBtc) {
        intVal = (_maxBtc * _fixedBtcPrice!).round();
      }
    }

    setState(() {
      fiatPrice = intVal;
      isInputChanged = true;
      _updateAmountController(true);
    });

    // fiat 입력 필드도 세 자리마다 콤마가 붙도록 포맷팅
    _isUpdatingAmounts = true;
    final formattedFiat = intVal.toThousandsSeparatedString();
    _fiatAmountController.value = TextEditingValue(
      text: formattedFiat,
      selection: TextSelection.collapsed(offset: formattedFiat.length),
    );
    _isUpdatingAmounts = false;
  }

  /// BTC 입력 처리
  void _processBtcInput(String sanitized, bool isUpsideWidget) {
    var btcText = sanitized;

    // 사용자가 '.'만 입력한 경우 → '0.' 으로 보이게 처리
    if (btcText == '.') {
      btcText = '0.';
      if (isUpsideWidget) {
        _isUpdatingAmounts = true;
        _btcAmountController.value = const TextEditingValue(text: '0.', selection: TextSelection.collapsed(offset: 2));
        _isUpdatingAmounts = false;
      }
    }

    // 소수점 이하 8자리까지만 허용
    if (btcText.contains('.')) {
      final parts = btcText.split('.');
      final intPart = parts[0];
      var decPart = parts.length > 1 ? parts[1] : '';
      if (decPart.length > 8) {
        decPart = decPart.substring(0, 8);
        btcText = '$intPart.$decPart';
      }
    }

    var btc = double.tryParse(btcText) ?? 0;

    // 최대 BTC 제한 체크
    if (btc > _maxBtc) {
      btc = _maxBtc;
      _isUpdatingAmounts = true;
      final formattedInt = _maxBtc.toInt().toThousandsSeparatedString();
      _btcAmountController.value = TextEditingValue(
        text: formattedInt,
        selection: TextSelection.collapsed(offset: formattedInt.length),
      );
      _isUpdatingAmounts = false;
      btcText = _maxBtc.toStringAsFixed(0);
    }

    // isUpsideWidget이면서 BTC 단위일 때는 정수 부분에 콤마 포맷 적용
    if (isUpsideWidget && btc <= _maxBtc) {
      final formattedBtcText = _formatBtcTextWithCommas(btcText);
      _isUpdatingAmounts = true;
      _btcAmountController.value = TextEditingValue(
        text: formattedBtcText,
        selection: TextSelection.collapsed(offset: formattedBtcText.length),
      );
      _isUpdatingAmounts = false;
    }

    // fiatPrice 계산
    final fiat = _calculateFiatFromBtc(btc);

    setState(() {
      fiatPrice = fiat;
      isInputChanged = true;
      _updateAmountController(false);
    });
  }

  /// Sats 입력 처리
  void _processSatsInput(String sanitized) {
    var sats = int.tryParse(sanitized) ?? 0;

    // 최대 2,100조 sats (2,100만 BTC)
    const maxSats = 2100000000000000; // 21,000,000 * 100,000,000
    if (sats > maxSats) {
      sats = maxSats;
      _isUpdatingAmounts = true;
      final clampedText = sats.toThousandsSeparatedString();
      _btcAmountController.value = TextEditingValue(
        text: clampedText,
        selection: TextSelection.collapsed(offset: clampedText.length),
      );
      _isUpdatingAmounts = false;
    }

    final btc = sats / 100000000;
    final cappedBtc = btc > _maxBtc ? _maxBtc : btc;

    // fiatPrice 계산
    final fiat = _calculateFiatFromBtc(cappedBtc);

    // 현재 편집 중인 sats 필드도 콤마 기준으로 다시 포맷팅
    _isUpdatingAmounts = true;
    final formattedSats = sats.toThousandsSeparatedString();
    _btcAmountController.value = TextEditingValue(
      text: formattedSats,
      selection: TextSelection.collapsed(offset: formattedSats.length),
    );
    _isUpdatingAmounts = false;

    setState(() {
      fiatPrice = fiat;
      isInputChanged = true;
      _updateAmountController(false);
    });
  }

  /// BTC 금액으로부터 Fiat 금액 계산 (수수료 및 네트워크 상태 반영)
  /// 공식 사이트 방식: fiat = round(btc × price × (1 + fee))
  int _calculateFiatFromBtc(double btc) {
    final isNetworkOn = context.read<ConnectivityProvider>().isNetworkOn;
    final feeValue = double.tryParse(_feeController.text) ?? 1.0;
    final feeRate = feeValue / 100.0;
    final premiumMultiplier = 1.0 + feeRate;

    if (isNetworkOn) {
      if (_fixedBtcPrice == null || _fixedBtcPrice == 0) return 0;
      // fiat = round(btc * price * (1 + fee))
      return (btc * _fixedBtcPrice! * premiumMultiplier).round();
    } else {
      final selectedFiat = context.read<PreferenceProvider>().selectedFiat;
      int btcPriceInFiat;
      switch (selectedFiat) {
        case FiatCode.KRW:
          btcPriceInFiat = 26000000;
          break;
        case FiatCode.USD:
          btcPriceInFiat = 20000;
          break;
        case FiatCode.JPY:
          btcPriceInFiat = 3000000;
          break;
      }
      return (btc * btcPriceInFiat * premiumMultiplier).round();
    }
  }

  /// BTC 텍스트의 정수 부분에 콤마 포맷 적용
  String _formatBtcTextWithCommas(String btcText) {
    final parts = btcText.split('.');
    final rawIntPart = parts[0].isEmpty ? '0' : parts[0];
    final hasDotOnly = parts.length == 2 && parts[1].isEmpty; // 예: '0.'
    final decPart = parts.length > 1 ? parts[1] : '';
    final intVal = int.tryParse(rawIntPart) ?? 0;
    final formattedInt = intVal.toThousandsSeparatedString();

    if (hasDotOnly) {
      // '0.' 처럼 끝에 점만 있는 경우 점 유지
      return '$formattedInt.';
    } else if (decPart.isEmpty) {
      return formattedInt;
    } else {
      return '$formattedInt.$decPart';
    }
  }

  /// 수수료 변경 시 위쪽 위젯 기준으로 아래쪽 위젯 값 업데이트
  void _updateAmountsOnFeeChange() {
    if (!isInputChanged) return;

    // 수수료 변경 중 플래그 설정 (addPostFrameCallback에서 _updateAmountControllers 호출 방지)
    _isUpdatingOnFeeChange = true;

    // 현재 위쪽 위젯의 값을 먼저 저장
    final currentFiatText = _fiatAmountController.text;
    final currentBtcText = _btcAmountController.text;

    if (isSwitched) {
      // 위쪽 위젯이 btc/sats인 경우: btc/sats 값 기준으로 fiatPrice 역계산
      final btcText = currentBtcText.replaceAll(RegExp(r'[^0-9.]'), '');
      if (btcText.isEmpty) {
        _isUpdatingOnFeeChange = false;
        return;
      }

      double btc;
      if (isBtcUnit) {
        btc = double.tryParse(btcText) ?? 0;
      } else {
        // sats인 경우
        final sats = int.tryParse(btcText) ?? 0;
        btc = sats / 100000000;
      }

      // fiatPrice 역계산
      final fiat = _calculateFiatFromBtc(btc);

      setState(() {
        fiatPrice = fiat;
        _isUpdatingAmounts = true;
        // 위쪽(btc/sats)은 현재 값 유지, 아래쪽(fiat)만 업데이트
        _btcAmountController.text = currentBtcText;
        _fiatAmountController.text = fiatPrice!.toThousandsSeparatedString();
        _isUpdatingAmounts = false;
      });
    } else {
      // 위쪽 위젯이 fiat인 경우: fiatPrice 유지, btc/sats만 새 수수료로 재계산
      setState(() {
        _isUpdatingAmounts = true;
        // 위쪽(fiat)은 현재 값 유지, 아래쪽(btc/sats)만 업데이트
        _fiatAmountController.text = currentFiatText;
        _btcAmountController.text = getAmountString(isFiat: false);
        _isUpdatingAmounts = false;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isUpdatingOnFeeChange = false;
    });
  }

  void _onShowTransactionBill() {
    FiatCode selectedFiat = context.read<PreferenceProvider>().selectedFiat;
    String referenceDatetime =
        '${_referenceDateTime.year}-${_referenceDateTime.month.toString().padLeft(2, '0')}-${_referenceDateTime.day.toString().padLeft(2, '0')} ${_referenceDateTime.hour.toString().padLeft(2, '0')}:${_referenceDateTime.minute.toString().padLeft(2, '0')}:${_referenceDateTime.second.toString().padLeft(2, '0')}';
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
              decoration: BoxDecoration(color: CoconutColors.gray900, borderRadius: BorderRadius.circular(20)),
              child: Stack(
                children: [
                  Column(
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
                      if (isSwitched) ...[
                        transactionBillRowWidget(
                          isBtcUnit ? t.btc : t.sats,
                          _btcAmountController.text,
                          canCopyText: true,
                          isFiat: false,
                        ),
                        const SizedBox(height: 8),
                        transactionBillRowWidget(
                          selectedFiat.code,
                          _fiatAmountController.text,
                          canCopyText: true,
                          isFiat: true,
                        ),
                      ] else ...[
                        transactionBillRowWidget(
                          selectedFiat.code,
                          _fiatAmountController.text,
                          canCopyText: true,
                          isFiat: true,
                        ),
                        const SizedBox(height: 8),
                        transactionBillRowWidget(
                          isBtcUnit ? t.btc : t.sats,
                          _btcAmountController.text,
                          canCopyText: true,
                          isFiat: false,
                        ),
                      ],
                      const SizedBox(height: 24),
                      const Divider(color: CoconutColors.gray700, height: 1),
                      const SizedBox(height: 24),
                      transactionBillRowWidget(
                        t.utility.p2p_calculator.reference_price,
                        '${selectedFiat.symbol} ${_fixedBtcPrice?.toThousandsSeparatedString() ?? '-'} / ${isBtcUnit ? t.btc : t.sats}',
                        rightTextStyle: CoconutTypography.body2_14_Number.copyWith(height: 1.4, letterSpacing: -0.28),
                      ),
                      const SizedBox(height: 20),
                      transactionBillRowWidget(
                        t.utility.p2p_calculator.reference_datetime,
                        referenceDatetime,
                        rightTextStyle: CoconutTypography.body2_14.copyWith(height: 1, letterSpacing: -0.14),
                      ),
                      const SizedBox(height: 20),
                      transactionBillRowWidget(
                        t.utility.p2p_calculator.transaction_fee,
                        '${_feeController.text} %',
                        rightTextStyle: CoconutTypography.body2_14.copyWith(
                          height: 1,
                          letterSpacing: -0.14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 20.0),
                          child: Text(
                            '수수료 fiat 값 출력', // TODO: 수수료 fiat 계산 후 출력
                            style: CoconutTypography.body3_12_Number.copyWith(
                              color: CoconutColors.gray500,
                              height: 1.4,
                              letterSpacing: -0.24, //
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 34),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ShrinkAnimationButton(
                            borderRadius: 8,
                            pressedColor: CoconutColors.gray850,
                            onPressed: () {
                              // TODO: 전체 복사 로직, 토스트 출력
                            },
                            child: Container(
                              width: 120,
                              padding: const EdgeInsets.only(top: 14, bottom: 14),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(
                                    'assets/svg/copy.svg',
                                    colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
                                    width: 14,
                                    height: 14,
                                  ),
                                  CoconutLayout.spacing_200w,
                                  Text(
                                    t.utility.p2p_calculator.copy_all,
                                    style: CoconutTypography.body3_12.setColor(CoconutColors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          CoconutLayout.spacing_300w,
                          ShrinkAnimationButton(
                            borderRadius: 8,
                            pressedColor: CoconutColors.gray850,
                            onPressed: () {
                              // TODO: 공유 로직
                            },
                            child: Container(
                              width: 120,
                              padding: const EdgeInsets.only(top: 14, bottom: 14),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(
                                    'assets/svg/export.svg',
                                    colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
                                    width: 14,
                                    height: 14,
                                  ),
                                  CoconutLayout.spacing_200w,
                                  Text(
                                    t.utility.p2p_calculator.share,
                                    style: CoconutTypography.body3_12.setColor(CoconutColors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      CoconutLayout.spacing_600h,
                    ],
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    child: IconButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: SvgPicture.asset(
                        'assets/svg/close.svg',
                        colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
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

  String _getPlaceholderText(bool isFiat, FiatCode selectedFiat) {
    // isFiat일 때: 선택한 법정화폐에 따라 고정값 반환
    if (isFiat) {
      switch (selectedFiat) {
        case FiatCode.KRW:
          return '50,000';
        case FiatCode.USD:
          return '50';
        case FiatCode.JPY:
          return '5000';
      }
    }

    // isFiat이 아닐 때: 네트워크 연결 상태에 따라 계산
    final isNetworkOn = context.read<ConnectivityProvider>().isNetworkOn;

    // baseFiatPrice: 선택한 법정화폐에 따른 기본값
    var baseFiatPrice = 0;
    switch (selectedFiat) {
      case FiatCode.KRW:
        baseFiatPrice = 50000;
      case FiatCode.USD:
        baseFiatPrice = 50;
      case FiatCode.JPY:
        baseFiatPrice = 5000;
    }

    final feeValue = double.tryParse(_feeController.text) ?? 1.0;
    final feeRate = feeValue / 100.0;
    final discountMultiplier = 1.0 - feeRate;

    // BTC 가격 결정 및 계산
    double btcAmount = 0;
    if (isNetworkOn) {
      // 네트워크 ON: 기준시세(_fixedBtcPrice) 사용
      if (_fixedBtcPrice == null || _fixedBtcPrice == 0) {
        return isBtcUnit ? '0.00000000' : '0';
      }

      // sats = (fiat / price) * (1 - fee)
      // btc  = (fiat / price) * (1 - fee)
      btcAmount = (baseFiatPrice * discountMultiplier) / _fixedBtcPrice!;
    } else {
      // 네트워크 OFF: 20K BTC 가격 사용
      // 20,000 USD per BTC를 기준으로 선택한 법정화폐에 맞게 변환
      int btcPriceInFiat;
      switch (selectedFiat) {
        case FiatCode.KRW:
          // 20,000 USD ≈ 26,000,000 KRW (1 USD ≈ 1,300 KRW 가정)
          btcPriceInFiat = 26000000;
          break;
        case FiatCode.USD:
          btcPriceInFiat = 20000;
          break;
        case FiatCode.JPY:
          // 20,000 USD ≈ 3,000,000 JPY (1 USD ≈ 150 JPY 가정)
          btcPriceInFiat = 3000000;
          break;
      }
      // 네트워크 OFF에서도 동일하게 (1 - fee)를 곱해줌
      btcAmount = (baseFiatPrice * discountMultiplier) / btcPriceInFiat;
    }

    // 단위에 따라 반환
    if (isBtcUnit) {
      debugPrint('btcAmount: ${btcAmount.toStringAsFixed(8)}');

      return btcAmount.toStringAsFixed(8);
    } else {
      final satsAmount = (btcAmount * 100000000).round();
      debugPrint('satsAmount: $satsAmount');
      return satsAmount.toString();
    }
  }

  void _onFiatUnitChange() {
    vibrateExtraLight();
    setState(() {
      switch (_currentFiatUnit) {
        case FiatCode.KRW:
          _currentFiatUnit = FiatCode.USD;
          break;
        case FiatCode.USD:
          _currentFiatUnit = FiatCode.JPY;
          break;
        default:
          _currentFiatUnit = FiatCode.KRW;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // build 시점에 controller 텍스트 동기화 (입력 중이 아닐 때만)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 포커스가 없고, 입력이 변경되었을 때만 업데이트 (초기에는 placeholder 표시)
      // 단, 수수료 입력 중이거나 수수료 변경 중에는 업데이트하지 않음
      if (!_fiatAmountFocusNode.hasFocus &&
          !_btcAmountFocusNode.hasFocus &&
          !_feeFocusNode.hasFocus &&
          isInputChanged &&
          !_isUpdatingOnFeeChange) {
        _updateAmountControllers();
      }
    });

    // usableHeight: height - safeArea - toolbar
    final usableHeight =
        MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom -
        56; // CoconutAppBar height

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: CoconutColors.black,
        appBar: CoconutAppBar.build(
          context: context,
          title: t.utility.p2p_calculator.calculator,
          actionButtonList: [
            // 오프라인 모드 버튼
            // IconButton(
            //   onPressed: () {
            //     setState(() {
            //       isOfflineMode = !isOfflineMode;
            //       _updateAmountControllers();
            //     });
            //   },
            //   icon:
            //       isOfflineMode
            //           ? SvgPicture.asset('assets/svg/online-mode.svg')
            //           : SvgPicture.asset('assets/svg/offline-mode.svg'),
            //   color: CoconutColors.white,
            // ),
            IconButton(
              onPressed: () {
                _onShowTransactionBill();
              },
              icon: SvgPicture.asset(
                'assets/svg/hand-shake.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
              ),
            ),
          ],
        ),
        body: SizedBox(
          height: usableHeight,
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Stack(
                  children: [
                    Container(
                      width: MediaQuery.sizeOf(context).width,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CoconutLayout.spacing_400h,
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              currentBtcPriceWidget(),
                              ShrinkAnimationButton(
                                onPressed: () {
                                  _onFiatUnitChange();
                                },
                                defaultColor: CoconutColors.gray800,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  constraints: const BoxConstraints(minWidth: 65),
                                  child: Center(
                                    child: Text(
                                      _currentFiatUnit.name,
                                      style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Column(
                                children: [
                                  amountInputWidget(isFiat: !isSwitched, isOfflineMode: isOfflineMode),
                                  CoconutLayout.spacing_400h,
                                  amountInputWidget(isFiat: isSwitched, isOfflineMode: isOfflineMode),
                                ],
                              ),
                              ShrinkAnimationButton(
                                onPressed: () {
                                  setState(() {
                                    isSwitched = !isSwitched;
                                    _updateBothAmountControllers();
                                  });
                                },
                                defaultColor: CoconutColors.gray900,
                                pressedColor: CoconutColors.gray850,
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  decoration: const BoxDecoration(shape: BoxShape.circle),
                                  child: SvgPicture.asset('assets/svg/arrow-top-down.svg'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_feeFocusNode.hasFocus) buildKeyboardToolbar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildKeyboardToolbar(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Positioned(
      bottom: keyboardHeight,
      child: GestureDetector(
        onTap: () {}, // ignore
        child: Container(
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          color: keyboardToolbarGray,
          child: Row(
            children: [
              Flexible(
                fit: FlexFit.tight,
                child: ShrinkAnimationButton(
                  onPressed: () {},
                  borderWidth: 1,
                  borderGradientColors: const [CoconutColors.gray600, CoconutColors.gray600],
                  borderRadius: 8,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      '+0.1 %',
                      style: CoconutTypography.body3_12.setColor(CoconutColors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              CoconutLayout.spacing_50w,
              Flexible(
                fit: FlexFit.tight,
                child: ShrinkAnimationButton(
                  onPressed: () {},
                  borderWidth: 1,
                  borderGradientColors: const [CoconutColors.gray600, CoconutColors.gray600],
                  borderRadius: 8,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      '+0.5 %',
                      style: CoconutTypography.body3_12.setColor(CoconutColors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              CoconutLayout.spacing_50w,
              Flexible(
                fit: FlexFit.tight,
                child: ShrinkAnimationButton(
                  onPressed: () {},
                  borderWidth: 1,
                  borderGradientColors: const [CoconutColors.gray600, CoconutColors.gray600],
                  borderRadius: 8,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      '+1.0 %',
                      style: CoconutTypography.body3_12.setColor(CoconutColors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              CoconutLayout.spacing_50w,
              Flexible(
                fit: FlexFit.tight,
                child: ShrinkAnimationButton(
                  onPressed: () {},
                  borderWidth: 1,
                  borderGradientColors: const [CoconutColors.gray600, CoconutColors.gray600],
                  borderRadius: 8,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      '+5.0 %',
                      style: CoconutTypography.body3_12.setColor(CoconutColors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 거래소 시세 위젯
  Widget currentBtcPriceWidget() {
    // 화면 진입 시점의 시세로 고정 (매번 갱신하지 않음)
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child:
          isOfflineMode
              ? const SizedBox.shrink()
              : Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 7.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          '${t.utility.p2p_calculator.one_btc} = ',
                          style: CoconutTypography.body1_16_Number.setColor(CoconutColors.white),
                        ),
                        if (_fixedBtcPrice != null) ...[
                          Consumer<PreferenceProvider>(
                            builder: (context, preferenceProvider, child) {
                              // 고정된 BTC 가격으로 직접 계산
                              final fiatAmount = FiatUtil.calculateFiatAmount(100000000, _fixedBtcPrice!);
                              final formattedAmount = fiatAmount.toThousandsSeparatedString();
                              final symbol = preferenceProvider.selectedFiat.symbol;
                              return Text(
                                '$symbol $formattedAmount',
                                style: CoconutTypography.body1_16_Number.setColor(CoconutColors.white),
                              );
                            },
                          ),
                        ] else ...[
                          // TODO: 1BTC = 1BTC
                          Text('-', style: CoconutTypography.body1_16_Number.setColor(CoconutColors.white)),
                        ],
                      ],
                    ),
                    // TODO: 언어별 거래소 변경
                    // TODO: 네트워크 연결 상태에 따라 다른 텍스트 표시 + TS/TC에 나와있는 기대결과 확인
                    // Online: (거래소) 기준 시세, offline: 시세를 가져올 수 없어요
                    Text(
                      t.utility.p2p_calculator.upbit_price,
                      style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget amountInputWidget({bool isFiat = false, bool isOfflineMode = false}) {
    bool isUpsideWidget = (isFiat && !isSwitched) || (!isFiat && isSwitched);
    debugPrint('isUpsideWidget: $isUpsideWidget');
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.2)),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (isUpsideWidget) {
            if (isFiat) {
              _fiatAmountFocusNode.requestFocus();
            } else {
              _btcAmountFocusNode.requestFocus();
            }
            // 커서를 마지막으로 이동
            final text = _feeController.text;
            if (text.isNotEmpty) {
              _feeController.selection = TextSelection.fromPosition(TextPosition(offset: text.length));
            }
          } else {
            // isUpsideWidget이 false일 때는 focus를 받지 않음
            if (!isFiat && !isOfflineMode) {
              // BTC/sats 위젯을 누르면 단위 토글
              FocusScope.of(context).unfocus();

              setState(() {
                isBtcUnit = !isBtcUnit;
                _updateBothAmountControllers();
              });
            }
          }
        },
        child: Stack(
          children: [
            Consumer<PreferenceProvider>(
              builder: (context, preferenceProvider, child) {
                return Container(
                  constraints: const BoxConstraints(minHeight: 175),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: CoconutColors.gray800),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isFiat) ...[
                            // TODO: 설정된 법정 화폐에 따라 다르게 표시
                            Text(
                              '${preferenceProvider.selectedFiat.symbol} ',
                              style: CoconutTypography.heading2_28_Bold.setColor(getInputTextColor()),
                            ),
                          ],
                          Flexible(
                            child: IgnorePointer(
                              ignoring: !isUpsideWidget,
                              child: IntrinsicWidth(
                                child: CoconutTextField(
                                  key: ValueKey(
                                    'amount_${isFiat ? 'fiat' : (isBtcUnit ? 'btc' : 'sats')}_${isUpsideWidget ? 'up' : 'down'}',
                                  ),
                                  maxLines: 1,
                                  controller: isFiat ? _fiatAmountController : _btcAmountController,
                                  focusNode: isFiat ? _fiatAmountFocusNode : _btcAmountFocusNode,
                                  placeholderText: _getPlaceholderText(isFiat, preferenceProvider.selectedFiat),
                                  textInputFormatter:
                                      isFiat || !isBtcUnit
                                          ? [FilteringTextInputFormatter.digitsOnly]
                                          : [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                  onChanged: (value) => _handleAmountInputChanged(value, isFiat, isUpsideWidget),
                                  textInputType:
                                      isFiat || !isBtcUnit
                                          ? TextInputType.number
                                          : const TextInputType.numberWithOptions(signed: false, decimal: true),
                                  textInputAction: TextInputAction.done,
                                  enableInteractiveSelection: false,
                                  isVisibleBorder: false,
                                  textAlign: TextAlign.center,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                                ),
                              ),
                            ),
                          ),
                          if (!isFiat) ...[
                            // TODO: 설정된 단위에 따라 다르게 표시
                            Text(
                              ' ${isBtcUnit ? t.btc : t.sats}',
                              textAlign: TextAlign.center,
                              style: CoconutTypography.heading2_28_Bold.setColor(getInputTextColor()),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            if (isUpsideWidget) ...[
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      // Premium Container를 누르면 premium 필드에 focus
                      _feeFocusNode.requestFocus();
                      // 커서를 마지막으로 이동
                      final text = _feeController.text;
                      if (text.isNotEmpty) {
                        _feeController.selection = TextSelection.fromPosition(TextPosition(offset: text.length));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: CoconutColors.gray900),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '${t.utility.p2p_calculator.fee} ',
                            style: CoconutTypography.body2_14.setColor(CoconutColors.white),
                          ),
                          SizedBox(
                            width: 40,
                            child: CoconutTextField(
                              controller: _feeController,
                              focusNode: _feeFocusNode,
                              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                              maxLines: 1,
                              height: 22,
                              textInputAction: TextInputAction.done,
                              textInputType: TextInputType.number,
                              onChanged: (value) {},
                              textAlign: TextAlign.end,
                              isVisibleBorder: false,
                            ),
                          ),
                          Text('%', style: CoconutTypography.body2_14.setColor(CoconutColors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget transactionBillRowWidget(
    String leftText,
    String rightText, {
    TextStyle? rightTextStyle,
    bool canCopyText = false,
    bool isFiat = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            leftText,
            style: CoconutTypography.body3_12.copyWith(
              height: 1.0,
              letterSpacing: -0.12, // 12 * -0.01
              fontWeight: FontWeight.w500,
            ),
          ),
          if (canCopyText) ...[
            GestureDetector(
              onTap: () {
                // TODO: 복사 로직
                debugPrint('복사 로직');
              },
              child: Row(
                children: [
                  Text(
                    () {
                      final raw = rightText.replaceAll(',', '').trim();
                      if (raw.isEmpty) return rightText;

                      if (isFiat) {
                        final value = int.tryParse(raw);
                        if (value == null) return rightText;
                        return value.toThousandsSeparatedString();
                      }

                      if (isBtcUnit) {
                        final btc = double.tryParse(raw);
                        if (btc == null) return rightText;
                        final sats = UnitUtil.convertBitcoinToSatoshi(btc);
                        // 예: 0.00001000 BTC (1000 sats) -> "0.0000 1000"
                        return BalanceFormatUtil.formatSatoshiToReadableBitcoin(sats);
                      }

                      // sats 등 기타 문자열은 그대로 사용
                      return int.parse(rightText).toThousandsSeparatedString();
                    }(),
                    style:
                        rightTextStyle ??
                        CoconutTypography.body1_16_Number.copyWith(
                          color: CoconutColors.white,
                          height: 1.4,
                          letterSpacing: -0.32, // 16 * -0.02
                        ),
                  ),
                  CoconutLayout.spacing_100w,
                  SvgPicture.asset(
                    'assets/svg/copy.svg',
                    colorFilter: const ColorFilter.mode(CoconutColors.gray600, BlendMode.srcIn),
                    width: 16,
                    height: 16,
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              rightText,
              style:
                  rightTextStyle ??
                  CoconutTypography.body2_14_Number.copyWith(
                    color: CoconutColors.white,
                    height: 1.4,
                    letterSpacing: -0.28, // 14 * -0.02
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Color getInputTextColor() {
    return isInputChanged ? CoconutColors.white : CoconutColors.gray600;
  }

  String getAmountString({bool isFiat = false}) {
    // 입력이 변경되지 않았거나 fiatPrice가 없으면 빈 문자열 반환 (placeholder 표시)
    if (!isInputChanged || fiatPrice == null || fiatPrice == 0) {
      return '';
    }

    if (isFiat) {
      // fiat은 항상 세 자리마다 콤마를 붙여서 표시
      return fiatPrice!.toThousandsSeparatedString();
    } else {
      // 수수료 및 네트워크 상태를 고려하여 BTC/sats로 환산
      final isNetworkOn = context.read<ConnectivityProvider>().isNetworkOn;
      final selectedFiat = context.read<PreferenceProvider>().selectedFiat;

      final feeValue = double.tryParse(_feeController.text) ?? 1.0;
      final feeRate = feeValue / 100.0;
      final discountMultiplier = 1.0 - feeRate;

      double btcAmount;
      if (isNetworkOn) {
        // 네트워크 ON: 기준시세(_fixedBtcPrice) 사용
        if (_fixedBtcPrice == null || _fixedBtcPrice == 0) {
          return '';
        }

        // (fiat / price) * (1 - fee)
        btcAmount = (fiatPrice! * discountMultiplier) / _fixedBtcPrice!;
      } else {
        // 네트워크 OFF: 20K BTC 가격 사용 (법정화폐별 상수)
        int btcPriceInFiat;
        switch (selectedFiat) {
          case FiatCode.KRW:
            btcPriceInFiat = 26000000;
            break;
          case FiatCode.USD:
            btcPriceInFiat = 20000;
            break;
          case FiatCode.JPY:
            btcPriceInFiat = 3000000;
            break;
        }
        btcAmount = (fiatPrice! * discountMultiplier) / btcPriceInFiat;
      }

      if (isBtcUnit) {
        final satsAmount = (btcAmount * 100000000).round();
        // BTC 단위로 표시 (소수점 8자리)
        return BalanceFormatUtil.formatSatoshiToReadableBitcoin(satsAmount, forceEightDecimals: true);
      } else {
        // sats 단위로 표시 (정수)
        final satsAmount = (btcAmount * 100000000).round();
        return satsAmount.toThousandsSeparatedString();
      }
    }
  }
}
