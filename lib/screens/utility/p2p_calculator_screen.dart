import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/view_model/utility/p2p_calculator_view_model.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
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

  late P2PCalculatorViewModel _viewModel;

  // Controller
  late final TextEditingController _feeController;
  late final TextEditingController _fiatAmountController;
  late final TextEditingController _btcAmountController;

  // FocusNode
  late final FocusNode _feeFocusNode;
  late final FocusNode _fiatAmountFocusNode;
  late final FocusNode _btcAmountFocusNode;

  double get keyboardHeight => MediaQuery.of(context).viewInsets.bottom;

  @override
  initState() {
    super.initState();
    _feeController = TextEditingController(text: '1.0');
    _fiatAmountController = TextEditingController();
    _btcAmountController = TextEditingController();

    _feeFocusNode = FocusNode();
    _fiatAmountFocusNode = FocusNode();
    _btcAmountFocusNode = FocusNode();

    _feeFocusNode.addListener(() {
      if (!_feeFocusNode.hasFocus && !_viewModel.isValidatingFee) {
        var text = _feeController.text;

        // 빈 문자열이면 '0'으로 설정
        if (text.isEmpty) {
          _viewModel.setIsValidatingFee(true);
          const newText = '0';
          _feeController.value = const TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          );
          _viewModel.setPreviousFeeValue(newText);
          _viewModel.setIsValidatingFee(false);
        }
        // 소수점이 없으면 '.0' 추가
        else if (!text.contains('.')) {
          _viewModel.setIsValidatingFee(true);
          final newText = '$text.0';
          _feeController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          );
          _viewModel.setPreviousFeeValue(newText);
          _viewModel.setIsValidatingFee(false);
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

  /// 스위치 토글, 단위 변경 시: 위쪽 위젯 기준으로 fiatPrice 재계산 후 아래쪽 업데이트
  void _recalculateAndUpdateAmount() {
    if (!_viewModel.isInputChanged || _viewModel.fiatPrice == null || _viewModel.fiatPrice == 0) {
      _viewModel.setIsUpdatingAmounts(true);
      _fiatAmountController.text = '';
      _btcAmountController.text = '';
      _viewModel.setIsUpdatingAmounts(false);
      return;
    }

    // isSwitched가 true면 위쪽이 BTC/Sats → fiatPrice 재계산 필요
    if (_viewModel.isSwitched) {
      final feeValue = double.tryParse(_feeController.text) ?? 0;
      final btcText = _btcAmountController.text.replaceAll(RegExp(r'[^0-9.]'), '');
      if (btcText.isNotEmpty) {
        double btc;
        if (_viewModel.isBtcUnit) {
          btc = double.tryParse(btcText) ?? 0;
        } else {
          final sats = int.tryParse(btcText) ?? 0;
          btc = sats / 100000000;
        }
        _viewModel.setFiatPrice(_viewModel.calculateFiatFromBtc(feeValue, btc));
      }
    }

    // 아래쪽 필드 업데이트
    _updateAmountController(!_viewModel.isSwitched);
  }

  /// 반대쪽 필드만 업데이트 (fiatPrice는 이미 설정된 상태)
  void _updateAmountController(bool isFiatInput) {
    final feeValue = double.tryParse(_feeController.text) ?? 0;

    _viewModel.setIsUpdatingAmounts(true);
    if (isFiatInput) {
      _btcAmountController.text = _viewModel.getAmountString(feeValue, isFiat: false);
    } else {
      _fiatAmountController.text = _viewModel.getAmountString(feeValue, isFiat: true);
    }
    _viewModel.setIsUpdatingAmounts(false);
  }

  /// Fee 입력 변경 처리 핸들러
  void _handleFeeInputChanged(String value) {
    var text = value;

    // '.'만 입력하면 '0.'으로 변환
    if (text == '.') {
      const newText = '0.';
      _feeController.value = const TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
      _viewModel.setPreviousFeeValue(newText);
      return;
    }

    // 정수 2자리, 소수점 이하 1자리만 허용하는 검증
    final regex = RegExp(r'^\d{0,2}(\.\d{0,1})?$');
    if (!regex.hasMatch(text)) {
      // 유효하지 않은 입력이면 이전 값으로 되돌림
      _feeController.value = TextEditingValue(
        text: _viewModel.previousFeeValue,
        selection: TextSelection.collapsed(offset: _viewModel.previousFeeValue.length),
      );
      return;
    }

    // 정수 부분이 두 자리 이상이고 0으로 시작하면 앞의 0 제거
    if (text.contains('.')) {
      final parts = text.split('.');
      final integerPart = parts[0];
      final decimalPart = parts[1];

      if (integerPart.length >= 2 && integerPart.startsWith('0')) {
        final cleanedInteger = integerPart.replaceFirst(RegExp(r'^0+'), '');
        text = cleanedInteger.isEmpty ? '0.$decimalPart' : '$cleanedInteger.$decimalPart';
      }
    } else {
      if (text.length >= 2 && text.startsWith('0')) {
        final cleaned = text.replaceFirst(RegExp(r'^0+'), '');
        text = cleaned.isEmpty ? '0' : cleaned;
      }
    }

    // 값이 변경되었으면 업데이트
    if (text != _feeController.text) {
      _feeController.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    }

    // 유효한 값이면 이전 값 업데이트
    _viewModel.setPreviousFeeValue(text);

    // fee가 변경되면 위쪽 위젯 기준으로 아래쪽 위젯 값 업데이트
    _updateAmountsOnFeeChange();
    setState(() {});
  }

  /// Amount 입력 변경 처리 메인 핸들러
  void _handleAmountInputChanged(String value, bool isFiat, bool isUpsideWidget) {
    if (_viewModel.isUpdatingAmounts) return;

    final sanitized = _viewModel.sanitizeInput(value, isFiat);
    debugPrint('sanitized: $sanitized');

    // 불허 문자가 섞여 있었으면, 정제된 값으로 즉시 UI에 반영
    if (sanitized != value) {
      _viewModel.setIsUpdatingAmounts(true);
      final controller = isFiat ? _fiatAmountController : _btcAmountController;
      controller.value = TextEditingValue(
        text: sanitized,
        selection: TextSelection.collapsed(offset: sanitized.length),
      );
      _viewModel.setIsUpdatingAmounts(false);
    }

    // 빈 문자열이면 초기화
    if (sanitized.isEmpty) {
      setState(() {
        _viewModel.setFiatPrice(0);
        _viewModel.setIsInputChanged(false);
        _updateAmountController(isFiat);
      });
      return;
    }

    // 분기 처리
    if (isFiat) {
      _processFiatInput(sanitized);
    } else if (_viewModel.isBtcUnit) {
      _processBtcInput(sanitized, isUpsideWidget);
    } else {
      _processSatsInput(sanitized);
    }
  }

  /// Fiat 입력 처리
  void _processFiatInput(String sanitized) {
    var intVal = int.tryParse(sanitized) ?? 0;

    // 최대 BTC 제한 체크
    if (_viewModel.fixedBtcPrice != null && _viewModel.fixedBtcPrice != 0) {
      final btcFromFiat = intVal / _viewModel.fixedBtcPrice!;
      if (btcFromFiat > _maxBtc) {
        intVal = (_maxBtc * _viewModel.fixedBtcPrice!).round();
      }
    }

    setState(() {
      _viewModel.setFiatPrice(intVal);
      _viewModel.setIsInputChanged(true);
      _updateAmountController(true);
    });

    // fiat 입력 필드도 세 자리마다 콤마가 붙도록 포맷팅
    _viewModel.setIsUpdatingAmounts(true);
    final formattedFiat = intVal.toThousandsSeparatedString();
    _fiatAmountController.value = TextEditingValue(
      text: formattedFiat,
      selection: TextSelection.collapsed(offset: formattedFiat.length),
    );
    _viewModel.setIsUpdatingAmounts(false);
  }

  /// BTC 입력 처리
  void _processBtcInput(String sanitized, bool isUpsideWidget) {
    var btcText = sanitized;

    // 사용자가 '.'만 입력한 경우 → '0.' 으로 보이게 처리
    if (btcText == '.') {
      btcText = '0.';
      if (isUpsideWidget) {
        _viewModel.setIsUpdatingAmounts(true);
        _btcAmountController.value = const TextEditingValue(text: '0.', selection: TextSelection.collapsed(offset: 2));
        _viewModel.setIsUpdatingAmounts(false);
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
      _viewModel.setIsUpdatingAmounts(true);
      final formattedInt = _maxBtc.toInt().toThousandsSeparatedString();
      _btcAmountController.value = TextEditingValue(
        text: formattedInt,
        selection: TextSelection.collapsed(offset: formattedInt.length),
      );
      _viewModel.setIsUpdatingAmounts(false);
      btcText = _maxBtc.toStringAsFixed(0);
    }

    // isUpsideWidget이면서 BTC 단위일 때는 정수 부분에 콤마 포맷 적용
    if (isUpsideWidget && btc <= _maxBtc) {
      final formattedBtcText = _viewModel.formatBtcTextWithCommas(btcText);
      _viewModel.setIsUpdatingAmounts(true);
      _btcAmountController.value = TextEditingValue(
        text: formattedBtcText,
        selection: TextSelection.collapsed(offset: formattedBtcText.length),
      );
      _viewModel.setIsUpdatingAmounts(false);
    }

    // fiatPrice 계산
    final fiat = _viewModel.calculateFiatFromBtc(double.tryParse(_feeController.text) ?? 0, btc);

    _viewModel.setFiatPrice(fiat);
    _viewModel.setIsInputChanged(true);
    _updateAmountController(false);
  }

  /// Sats 입력 처리
  void _processSatsInput(String sanitized) {
    var sats = int.tryParse(sanitized) ?? 0;

    // 최대 2,100조 sats (2,100만 BTC)
    const maxSats = 2100000000000000; // 21,000,000 * 100,000,000
    if (sats > maxSats) {
      sats = maxSats;
      _viewModel.setIsUpdatingAmounts(true);
      final clampedText = sats.toThousandsSeparatedString();
      _btcAmountController.value = TextEditingValue(
        text: clampedText,
        selection: TextSelection.collapsed(offset: clampedText.length),
      );
      _viewModel.setIsUpdatingAmounts(false);
    }

    final btc = sats / 100000000;
    final cappedBtc = btc > _maxBtc ? _maxBtc : btc;

    // fiatPrice 계산
    final fiat = _viewModel.calculateFiatFromBtc(double.tryParse(_feeController.text) ?? 0, cappedBtc);

    // 현재 편집 중인 sats 필드도 콤마 기준으로 다시 포맷팅
    _viewModel.setIsUpdatingAmounts(true);
    final formattedSats = sats.toThousandsSeparatedString();
    _btcAmountController.value = TextEditingValue(
      text: formattedSats,
      selection: TextSelection.collapsed(offset: formattedSats.length),
    );
    _viewModel.setIsUpdatingAmounts(false);

    _viewModel.setFiatPrice(fiat);
    _viewModel.setIsInputChanged(true);
    _updateAmountController(false);
  }

  /// 수수료 변경 시 위쪽 위젯 기준으로 아래쪽 위젯 값 업데이트
  void _updateAmountsOnFeeChange() {
    if (!_viewModel.isInputChanged) return;

    // 수수료 변경 중 플래그 설정 (addPostFrameCallback에서 _updateAmountControllers 호출 방지)
    _viewModel.setIsUpdatingOnFeeChange(true);

    // 현재 위쪽 위젯의 값을 먼저 저장
    final currentFiatText = _fiatAmountController.text;
    final currentBtcText = _btcAmountController.text;
    final feeValue = double.tryParse(_feeController.text) ?? 0;

    if (_viewModel.isSwitched) {
      // 위쪽 위젯이 btc/sats인 경우: btc/sats 값 기준으로 fiatPrice 역계산
      final btcText = currentBtcText.replaceAll(RegExp(r'[^0-9.]'), '');
      if (btcText.isEmpty) {
        _viewModel.setIsUpdatingOnFeeChange(false);
        return;
      }

      double btc;
      if (_viewModel.isBtcUnit) {
        btc = double.tryParse(btcText) ?? 0;
      } else {
        // sats인 경우
        final sats = int.tryParse(btcText) ?? 0;
        btc = sats / 100000000;
      }

      // fiatPrice 역계산
      final fiat = _viewModel.calculateFiatFromBtc(feeValue, btc);

      setState(() {
        _viewModel.setFiatPrice(fiat);
        _viewModel.setIsUpdatingAmounts(true);
        // 위쪽(btc/sats)은 현재 값 유지, 아래쪽(fiat)만 업데이트
        _btcAmountController.text = currentBtcText;
        _fiatAmountController.text = _viewModel.fiatPrice!.toThousandsSeparatedString();
        _viewModel.setIsUpdatingAmounts(false);
      });
    } else {
      // 위쪽 위젯이 fiat인 경우: fiatPrice 유지, btc/sats만 새 수수료로 재계산
      setState(() {
        _viewModel.setIsUpdatingAmounts(true);
        // 위쪽(fiat)은 현재 값 유지, 아래쪽(btc/sats)만 업데이트
        _fiatAmountController.text = currentFiatText;
        _btcAmountController.text = _viewModel.getAmountString(feeValue, isFiat: false);
        _viewModel.setIsUpdatingAmounts(false);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.setIsUpdatingOnFeeChange(false);
    });
  }

  void _onShowTransactionBill() {
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
                      if (_viewModel.isSwitched) ...[
                        transactionBillRowWidget(
                          _viewModel.isBtcUnit ? t.btc : t.sats,
                          _btcAmountController.text,
                          canCopyText: true,
                          isFiat: false,
                        ),
                        const SizedBox(height: 8),
                        transactionBillRowWidget(
                          _viewModel.currentFiatUnit.code,
                          _fiatAmountController.text,
                          canCopyText: true,
                          isFiat: true,
                        ),
                      ] else ...[
                        transactionBillRowWidget(
                          _viewModel.currentFiatUnit.code,
                          _fiatAmountController.text,
                          canCopyText: true,
                          isFiat: true,
                        ),
                        const SizedBox(height: 8),
                        transactionBillRowWidget(
                          _viewModel.isBtcUnit ? t.btc : t.sats,
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
                        '${_viewModel.currentFiatUnit.symbol} ${_viewModel.fixedBtcPrice?.toThousandsSeparatedString() ?? '-'} / ${_viewModel.isBtcUnit ? t.btc : t.sats}',
                        rightTextStyle: CoconutTypography.body2_14_Number.copyWith(height: 1.4, letterSpacing: -0.28),
                      ),
                      const SizedBox(height: 20),
                      transactionBillRowWidget(
                        t.utility.p2p_calculator.reference_datetime,
                        _viewModel.referenceDateTimeString,
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

  @override
  Widget build(BuildContext context) {
    // build 시점에 controller 텍스트 동기화 (입력 중이 아닐 때만)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 포커스가 없고, 입력이 변경되었을 때만 업데이트 (초기에는 placeholder 표시)
      // 단, 수수료 입력 중이거나 수수료 변경 중에는 업데이트하지 않음
      if (!_fiatAmountFocusNode.hasFocus &&
          !_btcAmountFocusNode.hasFocus &&
          !_feeFocusNode.hasFocus &&
          _viewModel.isInputChanged &&
          !_viewModel.isUpdatingOnFeeChange) {
        // isSwitched가 true면 아래쪽이 fiat이므로 isFiatInput=false로 fiat 업데이트
        // isSwitched가 false면 아래쪽이 btc이므로 isFiatInput=true로 btc 업데이트
        _updateAmountController(!_viewModel.isSwitched);
      }
    });

    // usableHeight: height - safeArea - toolbar
    final usableHeight =
        MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom -
        56; // CoconutAppBar height

    return ChangeNotifierProvider<P2PCalculatorViewModel>(
      create:
          (context) => P2PCalculatorViewModel(
            context.read<PreferenceProvider>(),
            context.read<ConnectivityProvider>(),
            context.read<PriceProvider>(),
          ),
      child: GestureDetector(
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
          body: Consumer<P2PCalculatorViewModel>(
            builder: (context, viewModel, child) {
              _viewModel = viewModel;
              return SizedBox(
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
                                    if (_viewModel.isNetworkOn) ...[
                                      ShrinkAnimationButton(
                                        onPressed: () {
                                          viewModel.onFiatUnitChange();
                                        },
                                        defaultColor: CoconutColors.gray800,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          constraints: const BoxConstraints(minWidth: 65),
                                          child: Center(
                                            child: Text(
                                              viewModel.currentFiatUnit.name,
                                              style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Column(
                                      children: [
                                        amountInputWidget(
                                          isFiat: !viewModel.isSwitched,
                                          isOfflineMode: viewModel.isOfflineMode,
                                        ),
                                        CoconutLayout.spacing_400h,
                                        amountInputWidget(
                                          isFiat: viewModel.isSwitched,
                                          isOfflineMode: viewModel.isOfflineMode,
                                        ),
                                      ],
                                    ),
                                    ShrinkAnimationButton(
                                      onPressed: () {
                                        viewModel.toggleSwitch();
                                        _recalculateAndUpdateAmount();
                                      },
                                      defaultColor: CoconutColors.gray900,
                                      pressedColor: CoconutColors.gray850,
                                      child: SizedBox(
                                        width: 52,
                                        height: 52,
                                        child: Center(
                                          child: SvgPicture.asset(
                                            'assets/svg/arrow-top-down.svg',
                                            width: 32,
                                            height: 32,
                                            colorFilter: const ColorFilter.mode(CoconutColors.gray400, BlendMode.srcIn),
                                          ),
                                        ),
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
                    buildKeyboardToolbar(context),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget buildKeyboardToolbar(BuildContext context) {
    if (!_feeFocusNode.hasFocus && !_fiatAmountFocusNode.hasFocus && !_btcAmountFocusNode.hasFocus) {
      return const SizedBox.shrink();
    }
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    // 버튼 라벨과 값 결정
    final buttonData = _viewModel.getToolbarButtonData(
      _feeFocusNode.hasFocus,
      _fiatAmountFocusNode.hasFocus,
      _btcAmountFocusNode.hasFocus,
    );

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
              for (int i = 0; i < buttonData.length; i++) ...[
                if (i > 0) CoconutLayout.spacing_50w,
                Flexible(
                  fit: FlexFit.tight,
                  child: ShrinkAnimationButton(
                    onPressed: () => _onToolbarButtonPressed(buttonData[i]['value']!),
                    borderWidth: 1,
                    borderGradientColors: const [CoconutColors.gray600, CoconutColors.gray600],
                    borderRadius: 8,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        buttonData[i]['label']!,
                        style: CoconutTypography.body3_12.setColor(CoconutColors.white),
                        textAlign: TextAlign.center,
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
    if (_feeFocusNode.hasFocus) {
      // 수수료에 값 추가
      final currentFee = double.tryParse(_feeController.text) ?? 0;
      final addValue = double.tryParse(value) ?? 0;
      final newFee = currentFee + addValue;
      // 최대 99.9%로 제한
      final clampedFee = newFee > 99.9 ? 99.9 : newFee;
      _feeController.text = clampedFee.toStringAsFixed(1);
    } else if (_fiatAmountFocusNode.hasFocus) {
      // Fiat 값 추가
      final currentText = _fiatAmountController.text.replaceAll(',', '');
      final currentValue = int.tryParse(currentText) ?? 0;
      final addValue = int.tryParse(value) ?? 0;
      final newValue = currentValue + addValue;
      _handleAmountInputChanged(newValue.toString(), true, !_viewModel.isSwitched);
    } else if (_btcAmountFocusNode.hasFocus) {
      // BTC/Sats 값 추가
      final currentText = _btcAmountController.text.replaceAll(RegExp(r'[^0-9.]'), '');
      if (_viewModel.isBtcUnit) {
        final currentValue = double.tryParse(currentText) ?? 0;
        final addValue = double.tryParse(value) ?? 0;
        final newValue = currentValue + addValue;
        _handleAmountInputChanged(newValue.toString(), false, _viewModel.isSwitched);
      } else {
        // sats
        final currentValue = int.tryParse(currentText) ?? 0;
        final addValue = int.tryParse(value) ?? 0;
        final newValue = currentValue + addValue;
        _handleAmountInputChanged(newValue.toString(), false, _viewModel.isSwitched);
      }
    }
  }

  /// 통화에 따른 거래소 이름 반환
  String _getExchangePriceLabel() {
    switch (_viewModel.currentFiatUnit) {
      case FiatCode.KRW:
        return t.utility.p2p_calculator.upbit_price;
      case FiatCode.USD:
        return t.utility.p2p_calculator.binance_price;
      case FiatCode.JPY:
        return t.utility.p2p_calculator.bitflyer_price;
    }
  }

  /// 거래소 시세 위젯
  Widget currentBtcPriceWidget() {
    // 화면 진입 시점의 시세로 고정 (매번 갱신하지 않음)
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.centerLeft,
      child:
          _viewModel.isOfflineMode
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
                        if (_viewModel.fixedBtcPrice != null && _viewModel.isNetworkOn) ...[
                          Text(
                            '${_viewModel.currentFiatUnit.symbol} ${FiatUtil.calculateFiatAmount(100000000, _viewModel.fixedBtcPrice!).toThousandsSeparatedString()}',
                            style: CoconutTypography.body1_16_Number.setColor(CoconutColors.white),
                          ),
                        ] else ...[
                          Text('1BTC', style: CoconutTypography.body1_16_Number.setColor(CoconutColors.white)),
                        ],
                      ],
                    ),
                    _viewModel.fixedBtcPrice != null && _viewModel.isNetworkOn
                        ? Text(
                          _getExchangePriceLabel(),
                          style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                        )
                        : Text(
                          t.utility.p2p_calculator.offline_price_unavailable,
                          style: CoconutTypography.body3_12.setColor(CoconutColors.hotPink),
                        ),
                  ],
                ),
              ),
    );
  }

  Widget amountInputWidget({bool isFiat = false, bool isOfflineMode = false}) {
    bool isUpsideWidget = (isFiat && !_viewModel.isSwitched) || (!isFiat && _viewModel.isSwitched);
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
                _viewModel.toggleBtcUnit();
                _recalculateAndUpdateAmount();
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
                              '${_viewModel.currentFiatUnit.symbol} ',
                              style: CoconutTypography.heading2_28_Bold.setColor(getInputTextColor()),
                            ),
                          ],
                          Flexible(
                            child: IgnorePointer(
                              ignoring: !isUpsideWidget,
                              child: IntrinsicWidth(
                                child: CoconutTextField(
                                  key: ValueKey(
                                    'amount_${isFiat ? 'fiat' : (_viewModel.isBtcUnit ? 'btc' : 'sats')}_${isUpsideWidget ? 'up' : 'down'}_fee_${_feeController.text}',
                                  ),
                                  maxLines: 1,
                                  controller: isFiat ? _fiatAmountController : _btcAmountController,
                                  focusNode: isFiat ? _fiatAmountFocusNode : _btcAmountFocusNode,
                                  placeholderText: _viewModel.getPlaceholderText(
                                    double.tryParse(_feeController.text) ?? 0,
                                    isFiat,
                                    _viewModel.currentFiatUnit,
                                  ),
                                  textInputFormatter:
                                      isFiat || !_viewModel.isBtcUnit
                                          ? [FilteringTextInputFormatter.digitsOnly]
                                          : [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                  onChanged: (value) => _handleAmountInputChanged(value, isFiat, isUpsideWidget),
                                  textInputType:
                                      isFiat || !_viewModel.isBtcUnit
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
                              ' ${_viewModel.isBtcUnit ? t.btc : t.sats}',
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
                          IntrinsicWidth(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 10),
                              child: CoconutTextField(
                                controller: _feeController,
                                focusNode: _feeFocusNode,
                                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                                maxLines: 1,
                                height: 22,
                                textInputAction: TextInputAction.done,
                                textInputType: TextInputType.number,
                                onChanged: _handleFeeInputChanged,
                                textAlign: TextAlign.end,
                                isVisibleBorder: false,
                              ),
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

                      if (_viewModel.isBtcUnit) {
                        final btc = double.tryParse(raw);
                        if (btc == null) return rightText;
                        final sats = UnitUtil.convertBitcoinToSatoshi(btc);
                        // 예: 0.00001000 BTC (1000 sats) -> "0.0000 1000"
                        return BalanceFormatUtil.formatSatoshiToReadableBitcoin(sats);
                      }

                      // sats 등 기타 문자열은 콤마 제거 후 파싱
                      final satsValue = int.tryParse(raw);
                      if (satsValue == null) return rightText;
                      return satsValue.toThousandsSeparatedString();
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
    return _viewModel.isInputChanged ? CoconutColors.white : CoconutColors.gray600;
  }
}
