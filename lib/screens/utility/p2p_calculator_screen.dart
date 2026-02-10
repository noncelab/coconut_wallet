import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/view_model/utility/p2p_calculator_view_model.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
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
  static const int _maxSats = 2100000000000000; // 21M BTC
  final Color _keyboardToolbarColor = const Color(0xFF2E2E2E);

  late P2PCalculatorViewModel _viewModel;

  late final TextEditingController _feeController;
  late final TextEditingController _inputController;

  late final FocusNode _feeFocusNode;
  late final FocusNode _inputFocusNode;

  bool _isUpdatingController = false; // 무한 루프 방지 플래그

  @override
  void initState() {
    super.initState();
    _feeController = TextEditingController(text: '1.0');
    _inputController = TextEditingController();

    _feeFocusNode = FocusNode();
    _inputFocusNode = FocusNode();

    _feeFocusNode.addListener(_onFeeFocusChanged);
    _inputFocusNode.addListener(_onInputFocusChanged);
  }

  @override
  void dispose() {
    _feeController.dispose();
    _inputController.dispose();
    _feeFocusNode.removeListener(_onFeeFocusChanged);
    _inputFocusNode.removeListener(_onInputFocusChanged);
    _feeFocusNode.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _onFeeFocusChanged() {
    if (!_feeFocusNode.hasFocus) {
      _formatFeeOnFocusLost();
    }
    setState(() {});
  }

  void _onInputFocusChanged() {
    if (!_inputFocusNode.hasFocus) {
      // 포커스를 잃었을 때 - BTC 단위면 readable 형식으로 변환 (소수부 4자리씩 공백)
      if (_viewModel.inputAssetType == InputAssetType.btc && _viewModel.isBtcUnit) {
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

  void _formatFeeOnFocusLost() {
    var text = _feeController.text;

    if (text.isEmpty) {
      _feeController.text = '0';
    } else if (text.endsWith('.')) {
      _feeController.text = '${text}0';
    } else if (!text.contains('.')) {
      _feeController.text = '$text.0';
    }

    _viewModel.setFeeRate(double.tryParse(_feeController.text) ?? 0);
  }

  void _handleFeeInputChanged(String value) {
    var text = value;

    if (text == '.') {
      _feeController.value = const TextEditingValue(text: '0.', selection: TextSelection.collapsed(offset: 2));
      return;
    }

    final regex = RegExp(r'^\d{0,2}(\.\d{0,1})?$');
    if (!regex.hasMatch(text)) {
      final prevText = _viewModel.feeRate.toStringAsFixed(1);
      _feeController.value = TextEditingValue(
        text: prevText,
        selection: TextSelection.collapsed(offset: prevText.length),
      );
      return;
    }

    if (text.contains('.')) {
      final parts = text.split('.');
      final intPart = parts[0];
      final decPart = parts[1];
      if (intPart.length >= 2 && intPart.startsWith('0')) {
        final cleaned = intPart.replaceFirst(RegExp(r'^0+'), '');
        text = '${cleaned.isEmpty ? '0' : cleaned}.$decPart';
      }
    } else {
      if (text.length >= 2 && text.startsWith('0')) {
        final cleaned = text.replaceFirst(RegExp(r'^0+'), '');
        text = cleaned.isEmpty ? '0' : cleaned;
      }
    }

    if (text != _feeController.text) {
      _feeController.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    }

    _viewModel.setFeeRate(double.tryParse(text) ?? 0);
    _updateResultOnFeeChange();
  }

  void _handleAmountInputChanged(String value) {
    if (_isUpdatingController) return; // 무한 루프 방지

    final isBtcInput = _viewModel.inputAssetType == InputAssetType.btc && _viewModel.isBtcUnit;
    final sanitized = _sanitizeInput(value, isBtcInput);

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

    if (_viewModel.inputAssetType == InputAssetType.fiat) {
      _processFiatInput(sanitized);
    } else if (_viewModel.isBtcUnit) {
      _processBtcInput(sanitized);
    } else {
      _processSatsInput(sanitized);
    }

    setState(() {});
  }

  void _processFiatInput(String sanitized) {
    var value = int.tryParse(sanitized) ?? 0;

    if (_viewModel.btcPrice != null && _viewModel.btcPrice! > 0) {
      final btcFromFiat = value / _viewModel.btcPrice!;
      if (btcFromFiat > _maxBtc) {
        value = (_maxBtc * _viewModel.btcPrice!).round();
      }
    }

    _viewModel.setInputAmount(value);

    final formatted = value.toThousandsSeparatedString();
    _isUpdatingController = true;
    _inputController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    _isUpdatingController = false;
  }

  void _processBtcInput(String sanitized) {
    var btcText = sanitized;

    // "." 입력 시 "0."으로 자동 변환
    if (btcText == '.') {
      btcText = '0.';
      _isUpdatingController = true;
      _inputController.value = const TextEditingValue(text: '0.', selection: TextSelection.collapsed(offset: 2));
      _isUpdatingController = false;
      _viewModel.setInputAmount(0);
      return;
    }

    // 소수점 이하 8자리 제한
    if (btcText.contains('.')) {
      final parts = btcText.split('.');
      var decPart = parts.length > 1 ? parts[1] : '';
      if (decPart.length > 8) {
        decPart = decPart.substring(0, 8);
        btcText = '${parts[0]}.$decPart';
      }
    }

    var btc = double.tryParse(btcText) ?? 0;

    // 최대값 체크
    if (btc > _maxBtc) {
      btc = _maxBtc;
      final formatted = _maxBtc.toInt().toThousandsSeparatedString();
      _isUpdatingController = true;
      _inputController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
      _isUpdatingController = false;
      btcText = _maxBtc.toStringAsFixed(0);
    } else {
      final formatted = _formatBtcWithCommas(btcText);
      _isUpdatingController = true;
      _inputController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
      _isUpdatingController = false;
    }

    // Sats로 변환
    final sats = (btc * 100000000).round();
    _viewModel.setInputAmount(sats);
  }

  /// BTC 입력값에 천 단위 구분자 추가 (소수부는 그대로 유지)
  String _formatBtcWithCommas(String btcText) {
    final parts = btcText.split('.');
    final rawIntPart = parts[0].isEmpty ? '0' : parts[0];
    final hasDotOnly = parts.length == 2 && parts[1].isEmpty;
    final decPart = parts.length > 1 ? parts[1] : '';
    final intVal = int.tryParse(rawIntPart) ?? 0;
    final formattedInt = intVal.toThousandsSeparatedString();

    if (hasDotOnly) {
      return '$formattedInt.';
    } else if (decPart.isEmpty) {
      return formattedInt;
    } else {
      return '$formattedInt.$decPart';
    }
  }

  void _processSatsInput(String sanitized) {
    var sats = int.tryParse(sanitized) ?? 0;

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

  void _updateResultOnFeeChange() {
    setState(() {});
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

    // 단위 토글
    _viewModel.toggleBtcUnit();

    // 입력값이 있으면 컨트롤러를 새 단위로 재포맷
    if (currentInput != null && currentInput > 0 && _viewModel.inputAssetType == InputAssetType.btc) {
      _isUpdatingController = true;

      if (_viewModel.isBtcUnit) {
        // Sats → BTC 전환 (readable bitcoin 형식)
        final formatted = BalanceFormatUtil.formatSatoshiToReadableBitcoin(currentInput, forceEightDecimals: true);
        _inputController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      } else {
        // BTC → Sats 전환
        final formatted = currentInput.toThousandsSeparatedString();
        _inputController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }

      _isUpdatingController = false;
    }

    setState(() {});
  }

  /// 토글 후 컨트롤러를 결과값으로 업데이트
  void _updateControllerWithResult(int result) {
    _isUpdatingController = true;

    if (_viewModel.inputAssetType == InputAssetType.fiat) {
      // BTC → Fiat로 전환: 정수 포맷
      final formatted = result.toThousandsSeparatedString();
      _inputController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    } else {
      // Fiat → BTC로 전환
      if (_viewModel.isBtcUnit) {
        // BTC 단위: readable bitcoin 형식
        final formatted = BalanceFormatUtil.formatSatoshiToReadableBitcoin(result, forceEightDecimals: true);
        _inputController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      } else {
        // Sats 단위: 정수 포맷
        final formatted = result.toThousandsSeparatedString();
        _inputController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }

    _isUpdatingController = false;
  }

  String _sanitizeInput(String value, bool isBtcInput) {
    if (!isBtcInput) {
      return value.replaceAll(RegExp(r'[^0-9]'), '');
    } else {
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

  String formatResultAmount(int result) {
    if (_viewModel.inputAssetType == InputAssetType.fiat) {
      return _viewModel.formatSatsResult(result);
    } else {
      return _viewModel.formatFiatResult(result);
    }
  }

  void _onShowTransactionBill() {
    final input = _viewModel.inputAmount;
    if (input == null || input == 0) return;

    final result = _viewModel.calculate(input);
    final referenceDateTime = DateTime.now();
    final referenceDateTimeString =
        '${referenceDateTime.year}-${referenceDateTime.month.toString().padLeft(2, '0')}-${referenceDateTime.day.toString().padLeft(2, '0')} ${referenceDateTime.hour.toString().padLeft(2, '0')}:${referenceDateTime.minute.toString().padLeft(2, '0')}:${referenceDateTime.second.toString().padLeft(2, '0')}';

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
                      // 입력값
                      _buildBillRow(
                        _viewModel.inputAssetType == InputAssetType.fiat
                            ? _viewModel.fiatCode.code
                            : (_viewModel.isBtcUnit ? t.btc : t.sats),
                        _viewModel.inputAssetType == InputAssetType.fiat
                            ? input.toThousandsSeparatedString()
                            : _viewModel.formatSatsResult(input),
                        canCopy: true,
                      ),
                      const SizedBox(height: 8),
                      // 결과값
                      _buildBillRow(
                        _viewModel.inputAssetType == InputAssetType.fiat
                            ? (_viewModel.isBtcUnit ? t.btc : t.sats)
                            : _viewModel.fiatCode.code,
                        _viewModel.inputAssetType == InputAssetType.fiat
                            ? _viewModel.formatSatsResult(result)
                            : result.toThousandsSeparatedString(),
                        canCopy: true,
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: CoconutColors.gray700, height: 1),
                      const SizedBox(height: 24),
                      _buildBillRow(
                        t.utility.p2p_calculator.reference_price,
                        '${_viewModel.fiatCode.symbol} ${_viewModel.btcPrice?.toThousandsSeparatedString() ?? '-'} / BTC',
                      ),
                      const SizedBox(height: 20),
                      _buildBillRow(t.utility.p2p_calculator.reference_datetime, referenceDateTimeString),
                      const SizedBox(height: 20),
                      _buildBillRow(t.utility.p2p_calculator.transaction_fee, '${_feeController.text} %'),
                      const SizedBox(height: 34),
                      _buildBillActions(),
                      CoconutLayout.spacing_600h,
                    ],
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
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

  Widget _buildBillRow(String label, String value, {bool canCopy = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: CoconutTypography.body3_12.copyWith(height: 1.0, letterSpacing: -0.12, fontWeight: FontWeight.w500),
          ),
          if (canCopy)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value.replaceAll(',', '').replaceAll(' ', '')));
              },
              child: Row(
                children: [
                  Text(
                    value,
                    style: CoconutTypography.body1_16_Number.copyWith(
                      color: CoconutColors.white,
                      height: 1.4,
                      letterSpacing: -0.32,
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
            )
          else
            Text(
              value,
              style: CoconutTypography.body2_14_Number.copyWith(
                color: CoconutColors.white,
                height: 1.4,
                letterSpacing: -0.28,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBillActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ShrinkAnimationButton(
          borderRadius: 8,
          pressedColor: CoconutColors.gray850,
          onPressed: () {
            // TODO: 전체 복사
          },
          child: Container(
            width: 120,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
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
            // TODO: 공유
          },
          child: Container(
            width: 120,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/svg/export.svg',
                  colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
                  width: 14,
                  height: 14,
                ),
                CoconutLayout.spacing_200w,
                Text(t.utility.p2p_calculator.share, style: CoconutTypography.body3_12.setColor(CoconutColors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final usableHeight =
        MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom -
        56;

    return ChangeNotifierProvider<P2PCalculatorViewModel>(
      create:
          (context) => P2PCalculatorViewModel(
            context.read<PreferenceProvider>(),
            context.read<ConnectivityProvider>(),
            context.read<PriceProvider>(),
          ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: CoconutColors.black,
          appBar: CoconutAppBar.build(
            context: context,
            title: t.utility.p2p_calculator.calculator,
            actionButtonList: [
              IconButton(
                onPressed: _onShowTransactionBill,
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
                      child: Container(
                        width: MediaQuery.sizeOf(context).width,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CoconutLayout.spacing_400h,
                            _buildPriceHeader(viewModel),
                            _buildCalculatorCards(viewModel),
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

  Widget _buildPriceHeader(P2PCalculatorViewModel viewModel) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildCurrentPriceWidget(viewModel),
        if (viewModel.isNetworkOn)
          ShrinkAnimationButton(
            onPressed: () async {
              await viewModel.onFiatUnitChange();
              _inputFocusNode.unfocus();
            },
            defaultColor: CoconutColors.gray800,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              constraints: const BoxConstraints(minWidth: 65),
              child: Center(
                child: Text(
                  viewModel.fiatCode.name,
                  style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCurrentPriceWidget(P2PCalculatorViewModel viewModel) {
    if (viewModel.isOfflineMode) return const SizedBox.shrink();

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
                  style: CoconutTypography.body1_16_Number.setColor(CoconutColors.white),
                ),
                Text(
                  viewModel.formattedOneBtcPrice,
                  style: CoconutTypography.body1_16_Number.setColor(CoconutColors.white),
                ),
              ],
            ),
          ),
          _buildExchangePriceLabel(viewModel),
        ],
      ),
    );
  }

  Widget _buildExchangePriceLabel(P2PCalculatorViewModel viewModel) {
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
          viewModel.isBtcPriceAvailable
              ? Text(
                _getExchangeLabel(viewModel.fiatCode),
                key: ValueKey('exchange_${viewModel.fiatCode.name}'),
                style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
              )
              : Text(
                t.utility.p2p_calculator.offline_price_unavailable,
                key: const ValueKey('offline'),
                style: CoconutTypography.body3_12.setColor(CoconutColors.hotPink),
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
    }
  }

  Widget _buildCalculatorCards(P2PCalculatorViewModel viewModel) {
    final hasInput = viewModel.inputAmount != null && viewModel.inputAmount! > 0;
    final result = hasInput ? viewModel.calculate(viewModel.inputAmount!) : 0;
    final placeholder = viewModel.getPlaceholder(isInputCard: true);
    return Stack(
      alignment: Alignment.center,
      children: [
        Column(
          children: [
            // 입력 카드
            _buildInputCardWidget(
              controller: _inputController,
              focusNode: _inputFocusNode,
              placeholderText: placeholder,
              prefix: viewModel.inputCardPrefix,
              postfix: viewModel.inputCardPostfix,
              feeController: _feeController,
              feeFocusNode: _feeFocusNode,
              onUnitToggle: viewModel.inputAssetType == InputAssetType.btc ? _onBtcUnitToggle : null,
            ),
            CoconutLayout.spacing_400h,
            // 결과 카드
            _buildResultCardWidget(
              isActive: hasInput,
              resultText: hasInput ? formatResultAmount(result) : viewModel.getPlaceholder(isInputCard: false),
              prefix: viewModel.resultCardPrefix,
              postfix: viewModel.resultCardPostfix,
              onTap: viewModel.inputAssetType == InputAssetType.fiat ? _onBtcUnitToggle : null,
            ),
          ],
        ),
        // 스위치 버튼
        ShrinkAnimationButton(
          onPressed: _changeInputAsset,
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
    );
  }

  Widget _buildInputCardWidget({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String placeholderText,
    TextEditingController? feeController,
    FocusNode? feeFocusNode,
    String? prefix,
    String? postfix,
    VoidCallback? onUnitToggle,
  }) {
    final hasInput = _viewModel.inputAmount != null;
    final textColor = hasInput ? CoconutColors.white : CoconutColors.gray600;
    // focus가 있고 입력값이 비어있으면 placeholder 숨김 (단, controller.text가 있으면 표시)
    final shouldHidePlaceholder = focusNode.hasFocus && controller.text.isEmpty;
    final effectivePlaceholder = shouldHidePlaceholder ? '' : placeholderText;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.2)),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onUnitToggle,
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
                      if (prefix != null)
                        Text('$prefix ', style: CoconutTypography.heading2_28_Bold.setColor(textColor)),
                      Flexible(
                        child: IntrinsicWidth(
                          child: CoconutTextField(
                            key: ValueKey('input_textfield_$placeholderText'),
                            maxLines: 1,
                            controller: controller,
                            focusNode: focusNode,
                            placeholderText: effectivePlaceholder,
                            textInputFormatter:
                                postfix == t.btc
                                    ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
                                    : [FilteringTextInputFormatter.digitsOnly],
                            onChanged: _handleAmountInputChanged,
                            textInputType:
                                postfix == t.btc
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
            if (feeController != null && feeFocusNode != null)
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      feeFocusNode.requestFocus();
                      final text = feeController.text;
                      if (text.isNotEmpty) {
                        feeController.selection = TextSelection.fromPosition(TextPosition(offset: text.length));
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
                                controller: feeController,
                                focusNode: feeFocusNode,
                                padding: EdgeInsets.zero,
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
    final textColor = isActive ? CoconutColors.white : CoconutColors.gray500;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.2)),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
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
                  if (prefix != null) Text('$prefix ', style: CoconutTypography.heading2_28_Bold.setColor(textColor)),
                  Text(resultText, style: CoconutTypography.heading2_28_Bold.setColor(textColor)),
                  if (postfix != null) Text(' $postfix', style: CoconutTypography.heading2_28_Bold.setColor(textColor)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboardToolbar() {
    if (!_feeFocusNode.hasFocus && !_inputFocusNode.hasFocus) {
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
          color: _keyboardToolbarColor,
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
      final currentFee = double.tryParse(_feeController.text) ?? 0;
      final addValue = double.tryParse(value) ?? 0;
      final newFee = (currentFee + addValue).clamp(0.0, 99.9);
      _feeController.text = newFee.toStringAsFixed(1);
      _viewModel.setFeeRate(newFee);
      _updateResultOnFeeChange();
    } else if (_inputFocusNode.hasFocus) {
      final currentText = _inputController.text.replaceAll(RegExp(r'[^0-9.]'), '');

      if (_viewModel.inputAssetType == InputAssetType.fiat) {
        final currentValue = int.tryParse(currentText) ?? 0;
        final addValue = int.tryParse(value) ?? 0;
        _handleAmountInputChanged((currentValue + addValue).toString());
      } else if (_viewModel.isBtcUnit) {
        final currentValue = double.tryParse(currentText) ?? 0;
        final addValue = double.tryParse(value) ?? 0;
        _handleAmountInputChanged((currentValue + addValue).toString());
      } else {
        final currentValue = int.tryParse(currentText) ?? 0;
        final addValue = int.tryParse(value) ?? 0;
        _handleAmountInputChanged((currentValue + addValue).toString());
      }
    }
  }

  /// Quick Add 버튼 데이터 반환
  List<Map<String, String>> _getQuickAddAmounts() {
    final isFeeFocused = _feeFocusNode.hasFocus;
    final isInputFocused = _inputFocusNode.hasFocus;
    if (isFeeFocused) {
      return [
        {'label': '+0.1 %', 'value': '0.1'},
        {'label': '+0.5 %', 'value': '0.5'},
        {'label': '+1.0 %', 'value': '1.0'},
        {'label': '+5.0 %', 'value': '5.0'},
      ];
    }

    if (!isInputFocused) return [];

    if (_viewModel.inputAssetType == InputAssetType.fiat) {
      switch (_viewModel.fiatCode) {
        case FiatCode.KRW:
          return [
            {'label': '+10,000', 'value': '10000'},
            {'label': '+50,000', 'value': '50000'},
            {'label': '+100,000', 'value': '100000'},
            {'label': '+500,000', 'value': '500000'},
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
            {'label': '+1,000', 'value': '1000'},
            {'label': '+5,000', 'value': '5000'},
            {'label': '+10,000', 'value': '10000'},
            {'label': '+50,000', 'value': '50000'},
          ];
      }
    } else {
      // BTC/Sats 입력
      if (_viewModel.isBtcUnit) {
        return [
          {'label': '+0.0001', 'value': '0.0001'},
          {'label': '+0.0005', 'value': '0.0005'},
          {'label': '+0.001', 'value': '0.001'},
          {'label': '+0.005', 'value': '0.005'},
        ];
      } else {
        return [
          {'label': '+10,000', 'value': '10000'},
          {'label': '+50,000', 'value': '50000'},
          {'label': '+100,000', 'value': '100000'},
          {'label': '+500,000', 'value': '500000'},
        ];
      }
    }
  }
}
