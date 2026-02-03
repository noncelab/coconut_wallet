import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

class P2PCalculator extends StatefulWidget {
  const P2PCalculator({super.key});

  @override
  State<P2PCalculator> createState() => _P2PCalculatorState();
}

class _P2PCalculatorState extends State<P2PCalculator> {
  static const double _maxBtc = 2100000000;
  final Color keyboardToolbarGray = const Color(0xFF2E2E2E);

  bool isOfflineMode = false; // TODO: viewModel로 이동
  bool isInputChanged = false;
  int fiatPrice = 50000; // TODO: viewModel로 이동
  bool isBtcUnit = true;
  int? _fixedBtcPrice; // 화면 진입 시점의 BTC 가격 (고정)

  bool isSwitched = false;
  bool _isUpdatingAmounts = false; // Amount 컨트롤러 업데이트 중인지 여부

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

  double get keyboardHeight => MediaQuery.of(context).viewInsets.bottom;

  @override
  initState() {
    super.initState();
    _referenceDateTime = DateTime.now();
    isBtcUnit = context.read<PreferenceProvider>().isBtcUnit; // TODO: vm으로 이동

    // 화면 진입 시점에 한 번만 BTC 가격 가져오기
    final priceProvider = context.read<PriceProvider>();
    _fixedBtcPrice = priceProvider.currentBitcoinPrice;

    // Premium 입력 필드 초기화 (초기값 1)
    _feeController = TextEditingController(text: '1.0');
    _feeFocusNode = FocusNode();
    _previousFeeValue = '1.0';

    // Amount 입력 필드 FocusNode 및 Controller 초기화
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

    // 초기 텍스트 설정
    _updateAmountControllers();

    // 텍스트 변경 시 검증 및 커서를 마지막으로 이동
    _feeController.addListener(() {
      if (_isValidatingFee) return; // 검증 중이면 무시

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

  void _updateAmountControllers() {
    _isUpdatingAmounts = true;
    _fiatAmountController.text = _getAmountString(isFiat: true);
    _btcAmountController.text = _getAmountString(isFiat: false);
    _isUpdatingAmounts = false;
  }

  /// 현재 입력 중인 필드를 제외한 반대쪽 필드만 업데이트
  void _updateAmountController(bool isFiatInput) {
    _isUpdatingAmounts = true;
    if (isFiatInput) {
      // fiat 입력 중이면 BTC 필드만 업데이트
      _btcAmountController.text = _getAmountString(isFiat: false);
    } else {
      // BTC/sats 입력 중이면 fiat 필드만 업데이트
      _fiatAmountController.text = _getAmountString(isFiat: true);
    }
    _isUpdatingAmounts = false;
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
                        _transactionBillRowWidget(
                          isBtcUnit ? t.btc : t.sats,
                          _btcAmountController.text,
                          canCopyText: true,
                          isFiat: false,
                        ),
                        const SizedBox(height: 8),
                        _transactionBillRowWidget(
                          selectedFiat.code,
                          _fiatAmountController.text,
                          canCopyText: true,
                          isFiat: true,
                        ),
                      ] else ...[
                        _transactionBillRowWidget(
                          selectedFiat.code,
                          _fiatAmountController.text,
                          canCopyText: true,
                          isFiat: true,
                        ),
                        const SizedBox(height: 8),
                        _transactionBillRowWidget(
                          isBtcUnit ? t.btc : t.sats,
                          _btcAmountController.text,
                          canCopyText: true,
                          isFiat: false,
                        ),
                      ],
                      const SizedBox(height: 24),
                      const Divider(color: CoconutColors.gray700, height: 1),
                      const SizedBox(height: 24),
                      _transactionBillRowWidget(
                        t.utility.p2p_calculator.reference_price,
                        '${selectedFiat.symbol} ${_fixedBtcPrice?.toThousandsSeparatedString() ?? '-'} / ${isBtcUnit ? t.btc : t.sats}',
                        rightTextStyle: CoconutTypography.body2_14_Number.copyWith(height: 1.4, letterSpacing: -0.28),
                      ),
                      const SizedBox(height: 20),
                      _transactionBillRowWidget(
                        t.utility.p2p_calculator.reference_datetime,
                        referenceDatetime,
                        rightTextStyle: CoconutTypography.body2_14.copyWith(height: 1, letterSpacing: -0.14),
                      ),
                      const SizedBox(height: 20),
                      _transactionBillRowWidget(
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
      // 포커스가 없을 때만 업데이트 (입력 중이 아닐 때)
      if (!_fiatAmountFocusNode.hasFocus && !_btcAmountFocusNode.hasFocus) {
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
                          _currentBtcPriceWidget(),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Column(
                                children: [
                                  _amountInputWidget(isFiat: !isSwitched, isOfflineMode: isOfflineMode),
                                  CoconutLayout.spacing_400h,
                                  _amountInputWidget(isFiat: isSwitched, isOfflineMode: isOfflineMode),
                                ],
                              ),
                              ShrinkAnimationButton(
                                onPressed: () {
                                  setState(() {
                                    isSwitched = !isSwitched;
                                    _updateAmountControllers();
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
              if (_feeFocusNode.hasFocus) _buildKeyboardToolbar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboardToolbar(BuildContext context) {
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
  Widget _currentBtcPriceWidget() {
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

  Widget _amountInputWidget({bool isFiat = false, bool isOfflineMode = false}) {
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
                _updateAmountControllers();
              });
            }
          }
        },
        child: Stack(
          children: [
            Container(
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
                        Consumer<PreferenceProvider>(
                          builder: (context, preferenceProvider, child) {
                            return Text(
                              '${preferenceProvider.selectedFiat.symbol} ',
                              style: CoconutTypography.heading2_28_Bold.setColor(_getInputTextColor()),
                            );
                          },
                        ),
                      ],
                      Flexible(
                        child: IgnorePointer(
                          ignoring: !isUpsideWidget,
                          child: IntrinsicWidth(
                            child: CoconutTextField(
                              maxLines: 1,
                              controller: isFiat ? _fiatAmountController : _btcAmountController,
                              focusNode: isFiat ? _fiatAmountFocusNode : _btcAmountFocusNode,
                              onChanged: (value) {
                                if (_isUpdatingAmounts) return;
                                // TODO: 로직 개선

                                // 숫자와 소수점만 허용
                                final sanitized = value.replaceAll(RegExp(r'[^0-9.]'), '');
                                if (sanitized.isEmpty) {
                                  setState(() {
                                    fiatPrice = 0;
                                    isInputChanged = false;
                                    _updateAmountController(isFiat);
                                  });
                                  return;
                                }

                                if (isFiat) {
                                  // 법정화폐 입력 → fiatPrice 직접 변경
                                  var intVal = int.tryParse(sanitized) ?? 0;

                                  if (_fixedBtcPrice != null && _fixedBtcPrice != 0) {
                                    final btcFromFiat = intVal / _fixedBtcPrice!;
                                    if (btcFromFiat > _maxBtc) {
                                      intVal = (_maxBtc * _fixedBtcPrice!).round();
                                    }
                                  }

                                  setState(() {
                                    fiatPrice = intVal;
                                    isInputChanged = true;
                                    _updateAmountController(isFiat);
                                  });
                                } else {
                                  // BTC/sats 입력 → fiatPrice로 환산
                                  if (_fixedBtcPrice == null || _fixedBtcPrice == 0) return;

                                  if (isBtcUnit) {
                                    var btc = double.tryParse(sanitized) ?? 0;
                                    if (btc > _maxBtc) {
                                      btc = _maxBtc;
                                    }
                                    final fiat = (btc * _fixedBtcPrice!).round();
                                    setState(() {
                                      fiatPrice = fiat;
                                      isInputChanged = true;
                                      _updateAmountController(isFiat);
                                    });
                                  } else {
                                    var sats = int.tryParse(sanitized) ?? 0;
                                    final btc = sats / 100000000;
                                    final cappedBtc = btc > _maxBtc ? _maxBtc : btc;
                                    final fiat = (cappedBtc * _fixedBtcPrice!).round();
                                    setState(() {
                                      fiatPrice = fiat;
                                      isInputChanged = true;
                                      _updateAmountController(isFiat);
                                    });
                                  }
                                }
                              },
                              textInputType: TextInputType.number,
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
                          style: CoconutTypography.heading2_28_Bold.setColor(_getInputTextColor()),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
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

  Widget _transactionBillRowWidget(
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

  Color _getInputTextColor() {
    return isInputChanged ? CoconutColors.white : CoconutColors.gray600;
  }

  String _getAmountString({bool isFiat = false}) {
    if (isFiat) {
      return fiatPrice.toString();
    } else {
      // 고정된 BTC 가격을 사용하여 환산
      if (_fixedBtcPrice == null || _fixedBtcPrice == 0) {
        // BTC 가격이 없으면 기본값 표시
        return isBtcUnit ? '0.00000000' : '0';
      }

      // fiatPrice를 고정된 BTC 가격으로 나누어 BTC로 환산
      final btcAmount = fiatPrice / _fixedBtcPrice!;

      if (isBtcUnit) {
        // BTC 단위로 표시 (소수점 8자리)
        return btcAmount.toStringAsFixed(8);
      } else {
        // sats 단위로 표시 (정수)
        final satsAmount = (btcAmount * 100000000).round();
        return satsAmount.toString();
      }
    }
  }
}
