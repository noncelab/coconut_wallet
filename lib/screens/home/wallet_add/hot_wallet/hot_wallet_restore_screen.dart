import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart'
    hide
        CoconutAppBar,
        CoconutToolTip,
        CoconutTooltipType,
        CoconutTooltipState,
        CoconutToast,
        CoconutToastLevel,
        CoconutPopup,
        CoconutTextField,
        CoconutTextFieldStyle;
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_add/hot_wallet_restore_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_add/hot_wallet/hot_wallet_app_lock_guide_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/utils/wallet_sync_result_util.dart';
import 'package:coconut_wallet/utils/wallet_name_util.dart';
import 'package:coconut_wallet/utils/seed_qr_decoder.dart';
import 'package:coconut_wallet/utils/app_settings_util.dart' as app_settings;
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/common/dialogs/dialog.dart';
import 'package:coconut_wallet/widgets/common/overlays/coconut_loading_overlay.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart' as permission;
import 'package:provider/provider.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

enum _RestoreInputMode { mnemonic, seedQr }

class HotWalletRestoreScreen extends StatelessWidget {
  const HotWalletRestoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(create: (_) => HotWalletRestoreViewModel(), child: const _HotWalletRestoreView());
  }
}

class WordSuggestableController extends TextEditingController {
  int _cursorOffset = 0;
  String _suggestionWord = '';

  void updateSuggestion(int? offset, String? suggestion) {
    _cursorOffset = offset ?? 0;
    _suggestionWord = suggestion ?? '';
    notifyListeners();
  }

  void clearSuggestion() {
    if (_suggestionWord.isEmpty) return;
    _suggestionWord = '';
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final defaultStyle = style ?? CoconutTypography.body2_14;
    final input = text;
    if (_cursorOffset < 0 || _cursorOffset > input.length) {
      return TextSpan(text: input, style: defaultStyle);
    }

    var wordStart = _cursorOffset;
    while (wordStart > 0 && input[wordStart - 1] != ' ') {
      wordStart--;
    }
    var wordEnd = _cursorOffset;
    while (wordEnd < input.length && input[wordEnd] != ' ') {
      wordEnd++;
    }

    final currentWord = input.substring(wordStart, wordEnd);
    if (currentWord.isEmpty || !_suggestionWord.toLowerCase().startsWith(currentWord.toLowerCase())) {
      return TextSpan(text: input, style: defaultStyle);
    }

    return TextSpan(
      style: defaultStyle,
      children: [
        if (wordStart > 0) TextSpan(text: input.substring(0, wordStart)),
        TextSpan(text: currentWord),
        TextSpan(
          text: _suggestionWord.substring(currentWord.length),
          style: defaultStyle.copyWith(color: context.coconutColors.tertiaryText),
        ),
        if (wordEnd < input.length) TextSpan(text: input.substring(wordEnd)),
      ],
    );
  }
}

class _HotWalletRestoreView extends StatefulWidget {
  const _HotWalletRestoreView();

  @override
  State<_HotWalletRestoreView> createState() => _HotWalletRestoreViewState();
}

class _HotWalletRestoreViewState extends State<_HotWalletRestoreView> {
  final List<WordSuggestableController> _wordControllers = List.generate(24, (_) => WordSuggestableController());
  final List<FocusNode> _wordFocusNodes = List.generate(24, (_) => FocusNode());
  final List<GlobalKey> _mnemonicRowKeys = List.generate(8, (_) => GlobalKey());
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passphraseController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _passphraseFocusNode = FocusNode();
  final FocusNode _screenFocusNode = FocusNode();
  final GlobalKey _nameFieldKey = GlobalKey();
  final GlobalKey _passphraseFieldKey = GlobalKey();
  final GlobalKey _bottomButtonKey = GlobalKey();
  final GlobalKey _wordCountSelectorKey = GlobalKey();
  final GlobalKey _wordCountDropdownKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  final Set<int> _invalidWordIndexes = {};
  final Set<int> _resetOnNextEditAfterRefocus = {};
  bool _passphraseVisible = false;
  bool _isWordCountDropdownVisible = false;
  bool _canPop = false;
  bool _isCheckingDuplicate = false;
  _RestoreInputMode _inputMode = _RestoreInputMode.mnemonic;
  final GlobalKey _seedQrKey = GlobalKey(debugLabel: 'SeedQR');
  QRViewController? _seedQrScannerController;
  bool _isSeedQrProcessing = false;
  bool _isRescanButtonPressed = false;
  bool _hasCameraPermission = false;
  bool _isRequestingCameraPermission = false;
  String? _scannedMasterFingerprint;
  bool _isMasterFingerprintLoading = false;
  Timer? _masterFingerprintDebounce;
  int _masterFingerprintRequestId = 0;
  int _fieldScrollRequestId = 0;
  late final String _suggestedName;

  @override
  void initState() {
    super.initState();
    _suggestedName = _generateSuggestedName();
    for (var index = 0; index < _wordFocusNodes.length; index++) {
      _wordFocusNodes[index].addListener(() {
        if (!mounted) return;
        if (_wordFocusNodes[index].hasFocus) {
          if (_invalidWordIndexes.contains(index)) {
            _resetOnNextEditAfterRefocus.add(index);
          }
          context.read<HotWalletRestoreViewModel>().setActiveWordIndex(index);
          _scrollToMnemonicRowIfNeeded(index);
        } else {
          _validateWordAfterFocusLost(index);
          if (!_wordFocusNodes.any((node) => node.hasFocus)) {
            context.read<HotWalletRestoreViewModel>().setActiveWordIndex(null);
          }
        }
      });
    }
    _nameFocusNode.addListener(() {
      if (_nameFocusNode.hasFocus) {
        _scrollToFocusedField(_nameFieldKey, _nameFocusNode, delay: const Duration(milliseconds: 150));
      }
    });
    _passphraseFocusNode.addListener(() {
      if (_passphraseFocusNode.hasFocus) {
        _scrollToFocusedField(_passphraseFieldKey, _passphraseFocusNode, delay: const Duration(milliseconds: 150));
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _wordFocusNodes.first.requestFocus());
  }

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      _seedQrScannerController?.pauseCamera();
    }
    _seedQrScannerController?.resumeCamera();
  }

  void _scrollToMnemonicRowIfNeeded(int index) {
    if (index == 0 || index % 3 != 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rowContext = _mnemonicRowKeys[index ~/ 3].currentContext;
      if (rowContext == null) return;
      Scrollable.ensureVisible(
        rowContext,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOutCubic,
        alignment: 0.15,
      );
    });
  }

  Future<void> _scrollToFocusedField(GlobalKey fieldKey, FocusNode focusNode, {required Duration delay}) async {
    final requestId = ++_fieldScrollRequestId;
    await Future<void>.delayed(delay);
    if (!mounted || requestId != _fieldScrollRequestId || !focusNode.hasFocus) {
      return;
    }
    if (!_scrollController.hasClients) {
      return;
    }
    final stableMaxScrollExtent = await _waitForStableMaxScrollExtent(requestId, focusNode);
    if (stableMaxScrollExtent == null) return;
    if (identical(fieldKey, _nameFieldKey)) {
      await _scrollController.animateTo(
        stableMaxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOutCubic,
      );
      return;
    }
    final fieldContext = fieldKey.currentContext;
    if (fieldContext == null || !fieldContext.mounted) return;
    final fieldBox = fieldContext.findRenderObject() as RenderBox?;
    final buttonBox = _bottomButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (fieldBox == null || buttonBox == null || !fieldBox.hasSize || !buttonBox.hasSize) {
      return;
    }
    final fieldBottom = fieldBox.localToGlobal(Offset(0, fieldBox.size.height)).dy;
    final buttonTop = buttonBox.localToGlobal(Offset.zero).dy;
    const gradientClearance = 100.0;
    final requiredOffset = fieldBottom + gradientClearance - buttonTop;
    if (requiredOffset <= 0) return;
    final position = _scrollController.position;
    final targetOffset = (position.pixels + requiredOffset).clamp(position.minScrollExtent, position.maxScrollExtent);
    await _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<double?> _waitForStableMaxScrollExtent(int requestId, FocusNode focusNode) async {
    double? previousExtent;
    var stableFrameCount = 0;
    for (var frame = 0; frame < 30; frame++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || requestId != _fieldScrollRequestId || !focusNode.hasFocus || !_scrollController.hasClients) {
        return null;
      }
      final currentExtent = _scrollController.position.maxScrollExtent;
      if (previousExtent != null && (currentExtent - previousExtent).abs() < 0.5) {
        stableFrameCount++;
        if (stableFrameCount >= 3) return currentExtent;
      } else {
        stableFrameCount = 0;
      }
      previousExtent = currentExtent;
    }
    return previousExtent;
  }

  void _validateWordAfterFocusLost(int index) {
    final viewModel = context.read<HotWalletRestoreViewModel>();
    final word = viewModel.words[index];
    final isInvalid = word.isNotEmpty && !viewModel.isKnownWord(index);
    setState(() {
      if (isInvalid) {
        _invalidWordIndexes.add(index);
      } else {
        _invalidWordIndexes.remove(index);
        _resetOnNextEditAfterRefocus.remove(index);
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _wordControllers) {
      controller.dispose();
    }
    for (final node in _wordFocusNodes) {
      node.dispose();
    }
    _nameController.dispose();
    _passphraseController.dispose();
    _nameFocusNode.dispose();
    _passphraseFocusNode.dispose();
    _screenFocusNode.dispose();
    _scrollController.dispose();
    _masterFingerprintDebounce?.cancel();
    super.dispose();
  }

  String _generateSuggestedName() {
    return WalletNameUtil.findAvailableDefaultName(
      existingNames: context.read<WalletProvider>().walletItemList.map((wallet) => wallet.name),
      firstName: t.wallet_home_screen.hot_wallet_create.default_name,
      numberedName: (number) => t.wallet_home_screen.hot_wallet_create.default_name_with_number(number: number),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!_isWordCountDropdownVisible) return;
    if (_isPositionInside(_wordCountSelectorKey, event.position) ||
        _isPositionInside(_wordCountDropdownKey, event.position)) {
      return;
    }
    setState(() => _isWordCountDropdownVisible = false);
  }

  bool _isPositionInside(GlobalKey key, Offset globalPosition) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return false;
    final localPosition = renderBox.globalToLocal(globalPosition);
    return (Offset.zero & renderBox.size).contains(localPosition);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HotWalletRestoreViewModel>();
    return PopScope(
      canPop: _canPop,
      child: Stack(
        children: [
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _handlePointerDown,
            child: Scaffold(
              resizeToAvoidBottomInset: true,
              backgroundColor: context.coconutColors.background,
              appBar: CoconutAppBar.build(
                title:
                    _inputMode == _RestoreInputMode.mnemonic
                        ? t.wallet_home_screen.hot_wallet_restore.title
                        : t.wallet_home_screen.hot_wallet_restore.seed_qr_title,
                context: context,
                onBackPressed: _handleAppBarBackPressed,
                actionButtonList: [
                  IconButton(
                    tooltip:
                        _inputMode == _RestoreInputMode.mnemonic
                            ? t.wallet_home_screen.hot_wallet_restore.scan_seed_qr
                            : t.wallet_home_screen.hot_wallet_restore.enter_mnemonic,
                    onPressed: _toggleInputMode,
                    icon: SvgPicture.asset(
                      _inputMode == _RestoreInputMode.mnemonic ? CommonActionIconPath.scan : CommonActionIconPath.paste,
                      width: 22,
                      height: 22,
                      colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
                    ),
                  ),
                ],
              ),
              body: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  FocusScope.of(context).unfocus();
                  if (_isWordCountDropdownVisible) {
                    setState(() => _isWordCountDropdownVisible = false);
                  }
                },
                child: SafeArea(
                  top: false,
                  child: Stack(
                    children: [
                      if (_inputMode == _RestoreInputMode.mnemonic)
                        Column(
                          children: [
                            _buildWordCountSelector(viewModel),
                            Expanded(child: _buildMnemonicInputSection(viewModel)),
                          ],
                        )
                      else
                        _buildSeedQrSection(viewModel),
                      if (_inputMode == _RestoreInputMode.mnemonic && viewModel.suggestions.isNotEmpty)
                        _buildSuggestions(viewModel),
                      if ((_inputMode == _RestoreInputMode.mnemonic && viewModel.suggestions.isEmpty) ||
                          (_inputMode == _RestoreInputMode.seedQr && viewModel.hasScannedMnemonic))
                        FixedBottomButton(
                          buttonKey: _bottomButtonKey,
                          text: t.wallet_home_screen.hot_wallet_restore.restore_wallet,
                          isActive: viewModel.canRestore,
                          subWidget: _inputMode == _RestoreInputMode.mnemonic ? _buildMnemonicError(viewModel) : null,
                          surroundingsColor: context.coconutColors.background,
                          onButtonClicked: _restore,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (viewModel.isRestoring || _isCheckingDuplicate) const CoconutLoadingOverlay(applyFullScreen: true),
        ],
      ),
    );
  }

  Future<void> _handleAppBarBackPressed() async {
    final viewModel = context.read<HotWalletRestoreViewModel>();
    final hasMnemonic = viewModel.hasScannedMnemonic || viewModel.words.any((word) => word.isNotEmpty);
    if (!hasMnemonic) {
      _popScreen();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    var didConfirm = false;
    await showConfirmDialog(
      context,
      context.read<PreferenceProvider>().language,
      t.wallet_home_screen.hot_wallet_restore.stop_restore_title,
      t.wallet_home_screen.hot_wallet_restore.stop_restore_description,
      leftButtonText: t.no,
      rightButtonText: t.yes,
      onTapRight: () {
        didConfirm = true;
        Navigator.of(context).pop();
        _popScreen();
      },
    );
    if (!didConfirm) _unfocusAfterDialogDismissed();
  }

  Future<void> _showClearAllDialog() async {
    FocusManager.instance.primaryFocus?.unfocus();
    var didConfirm = false;
    await showConfirmDialog(
      context,
      context.read<PreferenceProvider>().language,
      t.wallet_home_screen.hot_wallet_restore.clear_all_title,
      LocaleSettings.currentLocale == AppLocale.ko
          ? TextUtils.preventLineBreakInsideWords(t.wallet_home_screen.hot_wallet_restore.clear_all_description)
          : t.wallet_home_screen.hot_wallet_restore.clear_all_description,
      leftButtonText: t.no,
      rightButtonText: t.yes,
      onTapRight: () {
        didConfirm = true;
        Navigator.of(context).pop();
        _clearAll();
      },
    );
    if (!didConfirm) _unfocusAfterDialogDismissed();
  }

  void _unfocusAfterDialogDismissed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).unfocus();
    });
  }

  void _popScreen() {
    setState(() => _canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _toggleInputMode() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final viewModel = context.read<HotWalletRestoreViewModel>();
    if (_inputMode == _RestoreInputMode.mnemonic) {
      _seedQrScannerController = null;
      await _requestCameraPermission();
      if (!mounted) return;
      setState(() {
        _inputMode = _RestoreInputMode.seedQr;
        _isWordCountDropdownVisible = false;
      });
      return;
    }
    if (viewModel.hasScannedMnemonic) {
      var confirmed = false;
      await showConfirmDialog(
        context,
        context.read<PreferenceProvider>().language,
        t.wallet_home_screen.hot_wallet_restore.switch_to_mnemonic_title,
        t.wallet_home_screen.hot_wallet_restore.switch_to_mnemonic_description,
        leftButtonText: t.no,
        rightButtonText: t.yes,
        onTapRight: () {
          confirmed = true;
          Navigator.of(context).pop();
        },
      );
      if (!confirmed || !mounted) return;
      viewModel.clearScannedMnemonic();
      _masterFingerprintDebounce?.cancel();
      _masterFingerprintRequestId++;
      _scannedMasterFingerprint = null;
      _isMasterFingerprintLoading = false;
    }
    _seedQrScannerController = null;
    if (mounted) setState(() => _inputMode = _RestoreInputMode.mnemonic);
  }

  Future<void> _requestCameraPermission() async {
    if (_hasCameraPermission || _isRequestingCameraPermission) return;
    _isRequestingCameraPermission = true;
    var status = await permission.Permission.camera.status;
    if (!status.isGranted) {
      status = await AppGuard.runWithoutPrivacyScreen(permission.Permission.camera.request);
    }
    _isRequestingCameraPermission = false;
    if (!mounted) return;
    setState(() => _hasCameraPermission = status.isGranted);
    if (!status.isGranted) {
      await showConfirmDialog(
        context,
        context.read<PreferenceProvider>().language,
        t.coconut_qr_scanner.camera_error.title,
        t.coconut_qr_scanner.camera_error.need_camera_permission,
        rightButtonText: t.go_to_settings,
        onTapRight: () {
          Navigator.of(context).pop();
          app_settings.openAppSettings();
        },
      );
    }
  }

  Widget _buildSeedQrSection(HotWalletRestoreViewModel viewModel) {
    if (!viewModel.hasScannedMnemonic) {
      final screenSize = MediaQuery.sizeOf(context);
      final scanSize =
          (screenSize.width < 400 || screenSize.height < 400)
              ? 320.0
              : screenSize.width > 600
              ? 500.0
              : screenSize.width * 0.85;
      return Stack(
        children: [
          if (_hasCameraPermission)
            QRView(
              key: _seedQrKey,
              onQRViewCreated: _onSeedQrViewCreated,
              overlay: QrScannerOverlayShape(
                overlayColor: CoconutColors.black.withValues(alpha: 0.45),
                borderColor: CoconutColors.white,
                borderRadius: 10,
                borderLength: scanSize * 0.5,
                borderWidth: 10,
                cutOutSize: scanSize,
              ),
            )
          else
            const Center(child: CoconutCircularIndicator()),
          Positioned(
            top: 20,
            left: 16,
            right: 16,
            child: CoconutToolTip(
              backgroundColor: context.coconutColors.surface,
              borderColor: context.coconutColors.surface,
              tooltipType: CoconutTooltipType.fixed,
              icon: SvgPicture.asset(
                CommonStateIconPath.circleInfo,
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
              ),
              richText: RichText(
                text: TextSpan(
                  text: t.wallet_home_screen.hot_wallet_restore.seed_qr_guide,
                  style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText).copyWith(height: 1.3),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.coconutColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.coconutColors.border),
            ),
            child: Column(
              children: [
                SvgPicture.asset(
                  CommonFormIconPath.circleCheck,
                  colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
                ),
                CoconutLayout.spacing_300h,
                Text(
                  t.wallet_home_screen.hot_wallet_restore.seed_qr_scanned,
                  style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
                ),
                CoconutLayout.spacing_100h,
                Text(
                  t.wallet_home_screen.hot_wallet_restore.seed_qr_word_count(
                    count: viewModel.scannedMnemonicWordCount!,
                  ),
                  style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
                ),
                if (_isMasterFingerprintLoading) ...[
                  CoconutLayout.spacing_50h,
                  const SizedBox(width: 48, height: 32, child: Center(child: CoconutCircularIndicator())),
                ] else if (_scannedMasterFingerprint != null) ...[
                  CoconutLayout.spacing_50h,
                  Text(
                    'MFP $_scannedMasterFingerprint',
                    style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.secondaryText),
                  ),
                  CoconutLayout.spacing_300h,
                ],
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => setState(() => _isRescanButtonPressed = true),
                  onTapUp: (_) => setState(() => _isRescanButtonPressed = false),
                  onTapCancel: () => setState(() => _isRescanButtonPressed = false),
                  onTap: _rescanSeedQr,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(8)),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 100),
                      style: CoconutTypography.body2_14_Bold.setColor(
                        _isRescanButtonPressed ? context.coconutColors.mutedText : context.coconutColors.primaryText,
                      ),
                      child: Text(t.wallet_home_screen.hot_wallet_restore.rescan_seed_qr),
                    ),
                  ),
                ),
              ],
            ),
          ),
          CoconutLayout.spacing_700h,
          _buildPassphraseSection(viewModel),
          CoconutLayout.spacing_700h,
          _buildWalletNameField(),
        ],
      ),
    );
  }

  void _onSeedQrViewCreated(QRViewController controller) {
    _seedQrScannerController = controller;
    controller.resumeCamera();
    controller.scannedDataStream.listen(_onSeedQrDetected);
  }

  Future<void> _onSeedQrDetected(Barcode barcode) async {
    if (_isSeedQrProcessing) return;
    _isSeedQrProcessing = true;
    final mnemonic = SeedQrDecoder.decode(code: barcode.code, rawBytes: barcode.rawBytes);
    if (mnemonic == null) {
      await _seedQrScannerController?.pauseCamera();
      if (mounted) {
        await showConfirmDialog(
          context,
          context.read<PreferenceProvider>().language,
          t.wallet_home_screen.hot_wallet_restore.seed_qr_invalid_title,
          t.wallet_home_screen.hot_wallet_restore.seed_qr_invalid,
          rightButtonText: t.close,
          onTapRight: () => Navigator.of(context).pop(),
        );
      }
      if (mounted && _inputMode == _RestoreInputMode.seedQr) {
        await _seedQrScannerController?.resumeCamera();
      }
      _isSeedQrProcessing = false;
      return;
    }
    final wordCount = utf8.decode(mnemonic, allowMalformed: false).split(' ').length;
    await _seedQrScannerController?.pauseCamera();
    _seedQrScannerController = null;
    if (mounted) {
      final viewModel = context.read<HotWalletRestoreViewModel>();
      viewModel.clearWords();
      for (final controller in _wordControllers) {
        controller.clear();
        controller.clearSuggestion();
      }
      _invalidWordIndexes.clear();
      _resetOnNextEditAfterRefocus.clear();
      viewModel.setScannedMnemonic(mnemonic, wordCount);
      setState(() {});
      _scheduleMasterFingerprintUpdate(immediate: true);
    }
    mnemonic.fillRange(0, mnemonic.length, 0);
    _isSeedQrProcessing = false;
  }

  Future<void> _rescanSeedQr() async {
    _seedQrScannerController = null;
    if (!mounted) return;
    context.read<HotWalletRestoreViewModel>().clearScannedMnemonic();
    _masterFingerprintDebounce?.cancel();
    _masterFingerprintRequestId++;
    _scannedMasterFingerprint = null;
    _isMasterFingerprintLoading = false;
    _isSeedQrProcessing = false;
    setState(() {});
  }

  void _scheduleMasterFingerprintUpdate({bool immediate = false}) {
    _masterFingerprintDebounce?.cancel();
    final requestId = ++_masterFingerprintRequestId;
    final viewModel = context.read<HotWalletRestoreViewModel>();
    if (!viewModel.hasScannedMnemonic || !viewModel.isPassphraseValid) {
      if ((_scannedMasterFingerprint != null || _isMasterFingerprintLoading) && mounted) {
        setState(() {
          _scannedMasterFingerprint = null;
          _isMasterFingerprintLoading = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _scannedMasterFingerprint = null;
        _isMasterFingerprintLoading = true;
      });
    }
    _masterFingerprintDebounce = Timer(immediate ? Duration.zero : const Duration(milliseconds: 300), () async {
      try {
        final fingerprint = await viewModel.deriveMasterFingerprint();
        if (!mounted || requestId != _masterFingerprintRequestId) return;
        setState(() {
          _scannedMasterFingerprint = fingerprint;
          _isMasterFingerprintLoading = false;
        });
      } catch (_) {
        if (!mounted || requestId != _masterFingerprintRequestId) return;
        setState(() {
          _scannedMasterFingerprint = null;
          _isMasterFingerprintLoading = false;
        });
      }
    });
  }

  Widget _buildWordCountSelector(HotWalletRestoreViewModel viewModel) {
    final canClear = viewModel.words.any((word) => word.isNotEmpty);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CupertinoButton(
            key: _wordCountSelectorKey,
            minSize: 0,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            onPressed: canClear ? _showClearAllDialog : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  CommonActionIconPath.eraser,
                  width: 18,
                  height: 18,
                  colorFilter: ColorFilter.mode(
                    canClear
                        ? context.coconutColors.iconPrimary
                        : context.coconutColors.iconPrimary.withValues(alpha: 0.3),
                    BlendMode.srcIn,
                  ),
                ),
                CoconutLayout.spacing_100w,
                Text(
                  t.wallet_home_screen.hot_wallet_restore.clear_all,
                  style: CoconutTypography.body2_14.setColor(
                    canClear
                        ? context.coconutColors.primaryText
                        : context.coconutColors.primaryText.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            minSize: 0,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            onPressed: () => setState(() => _isWordCountDropdownVisible = !_isWordCountDropdownVisible),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.translate(
                  offset: const Offset(0, -2),
                  child: Text(
                    t.wallet_home_screen.hot_wallet_create.word_count(count: viewModel.wordCount),
                    style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
                  ),
                ),
                CoconutLayout.spacing_200w,
                SvgPicture.asset(
                  CommonNavigationIconPath.arrowDown,
                  width: 12,
                  colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMnemonicInputSection(HotWalletRestoreViewModel viewModel) {
    return Stack(
      children: [
        SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMnemonicGrid(viewModel),
              CoconutLayout.spacing_700h,
              _buildPassphraseSection(viewModel),
              CoconutLayout.spacing_700h,
              _buildWalletNameField(),
            ],
          ),
        ),
        if (_isWordCountDropdownVisible) _buildWordCountDropdown(),
      ],
    );
  }

  Widget? _buildMnemonicError(HotWalletRestoreViewModel viewModel) {
    String? message;
    if (_invalidWordIndexes.isNotEmpty) {
      final indexes = _invalidWordIndexes.toList()..sort();
      final words = indexes.map((index) => viewModel.words[index]).join(', ');
      message = t.wallet_home_screen.hot_wallet_restore.invalid_words(words: '[$words]');
    } else if (viewModel.areAllWordsFilled && !viewModel.isMnemonicValid) {
      message = t.wallet_home_screen.hot_wallet_restore.invalid_mnemonic;
    }
    if (message == null) return null;
    return Text(
      message,
      textAlign: TextAlign.center,
      style: CoconutTypography.body2_14.setColor(context.coconutColors.danger),
    );
  }

  Widget _buildWordCountDropdown() {
    return Positioned(
      top: 0,
      right: 16,
      child: CoconutPulldownMenu(
        key: _wordCountDropdownKey,
        backgroundColor: context.coconutColors.pulldownMenuBackground,
        shadowColor: context.coconutColors.shadowDefault,
        dividerColor: context.coconutColors.pulldownMenuDividerColor,
        splashColor: context.coconutColors.pulldownMenuPressedColor,
        entries: [
          CoconutPulldownMenuItem(title: t.wallet_home_screen.hot_wallet_create.word_count(count: 12)),
          CoconutPulldownMenuItem(title: t.wallet_home_screen.hot_wallet_create.word_count(count: 24)),
        ],
        dividerHeight: 1,
        onSelected: (index, _) {
          setState(() => _isWordCountDropdownVisible = false);
          _changeWordCount(index == 0 ? 12 : 24);
        },
      ),
    );
  }

  Widget _buildMnemonicGrid(HotWalletRestoreViewModel viewModel) {
    return Column(
      children: [
        for (var row = 0; row < viewModel.wordCount ~/ 3; row++) ...[
          Row(
            key: _mnemonicRowKeys[row],
            children: [
              for (var column = 0; column < 3; column++) ...[
                if (column > 0) CoconutLayout.spacing_200w,
                Expanded(child: _buildWordField(row * 3 + column, viewModel)),
              ],
            ],
          ),
          if (row < viewModel.wordCount ~/ 3 - 1) CoconutLayout.spacing_200h,
        ],
      ],
    );
  }

  Widget _buildWordField(int index, HotWalletRestoreViewModel viewModel) {
    final isInvalid = _invalidWordIndexes.contains(index);
    final hasFocus = _wordFocusNodes[index].hasFocus;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _wordFocusNodes[index].requestFocus();
        _wordControllers[index].selection = TextSelection.collapsed(offset: _wordControllers[index].text.length);
        if (_isWordCountDropdownVisible) {
          setState(() => _isWordCountDropdownVisible = false);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.coconutColors.background,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                isInvalid
                    ? context.coconutColors.danger.withValues(alpha: 0.7)
                    : hasFocus
                    ? context.coconutColors.inputBorderFocused
                    : context.coconutColors.inputBorderUnfocused,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              (index + 1).toString().padLeft(2, '0'),
              style: CoconutTypography.body2_14.setColor(context.coconutColors.tertiaryText),
            ),
            CoconutLayout.spacing_50h,
            CoconutTextField(
              controller: _wordControllers[index],
              focusNode: _wordFocusNodes[index],
              size: CoconutTextFieldSize.compact,
              textAlign: TextAlign.center,
              textInputAction: index == viewModel.wordCount - 1 ? TextInputAction.done : TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              textInputFormatter: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z ]'))],
              fontSize: 14,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              cursorColor: context.coconutColors.primaryText,
              activeColor: context.coconutColors.primaryText,
              isVisibleBorder: false,
              isLengthVisible: false,
              maxLines: 1,
              onChanged: (value) => _onWordChanged(index, value),
              onEditingComplete: () => _focusNext(index, viewModel.wordCount),
            ),
          ],
        ),
      ),
    );
  }

  void _onWordChanged(int index, String value) {
    final viewModel = context.read<HotWalletRestoreViewModel>();
    final previousWord = viewModel.words[index];
    final pieces = value.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    if (pieces.length > 1) {
      final nextIndex = viewModel.applyWords(index, pieces);
      _syncControllers(viewModel);
      _focusIndex(nextIndex, viewModel.wordCount);
      return;
    }

    var normalized = value.trim().toLowerCase();
    if (_resetOnNextEditAfterRefocus.remove(index) && normalized != previousWord) {
      final cursorOffset = _wordControllers[index].selection.baseOffset;
      normalized = normalized.length > previousWord.length && cursorOffset > 0 ? normalized[cursorOffset - 1] : '';
      _invalidWordIndexes.remove(index);
    }
    viewModel.updateWord(index, normalized);
    if (_wordControllers[index].text != normalized) {
      _wordControllers[index].value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    }
    final suggestions = viewModel.suggestions;
    _wordControllers[index].updateSuggestion(
      _wordControllers[index].selection.baseOffset,
      normalized.length >= 2 && suggestions.isNotEmpty ? suggestions.first : '',
    );
  }

  void _applySuggestion(int index, String word) {
    final viewModel = context.read<HotWalletRestoreViewModel>();
    _invalidWordIndexes.remove(index);
    _resetOnNextEditAfterRefocus.remove(index);
    viewModel.updateWord(index, word);
    _wordControllers[index].clearSuggestion();
    _wordControllers[index].value = TextEditingValue(
      text: word,
      selection: TextSelection.collapsed(offset: word.length),
    );
    _focusNext(index, viewModel.wordCount);
  }

  Widget _buildSuggestions(HotWalletRestoreViewModel viewModel) {
    final activeIndex = viewModel.activeWordIndex;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 200),
            color: context.coconutColors.background.withValues(alpha: 0.55),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.wallet_home_screen.hot_wallet_restore.recommended_words,
                      style: CoconutTypography.body3_12_Bold.setColor(context.coconutColors.secondaryText),
                    ),
                    CoconutLayout.spacing_300h,
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children:
                          viewModel.suggestions
                              .map(
                                (word) => ShrinkAnimationButton(
                                  onPressed: () {
                                    if (activeIndex != null) {
                                      _applySuggestion(activeIndex, word);
                                    }
                                  },
                                  defaultColor: context.coconutColors.surface,
                                  pressedColor: context.coconutColors.surfacePressOverlay,
                                  border: Border.all(color: context.coconutColors.border),
                                  borderRadius: 100,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Text(
                                      word,
                                      style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPassphraseSection(HotWalletRestoreViewModel viewModel) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                t.wallet_home_screen.hot_wallet_create.use_passphrase,
                style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
              ),
            ),
            CoconutSwitch(
              isOn: viewModel.usePassphrase,
              scale: 0.75,
              activeTrackColor: context.coconutColors.switchActiveTrack,
              activeThumbColor: context.coconutColors.switchActiveThumb,
              inactiveTrackColor: context.coconutColors.switchInactiveTrack,
              inactiveThumbColor: context.coconutColors.switchInactiveThumb,
              onChanged: (value) {
                if (!value) {
                  _passphraseFocusNode.unfocus();
                  _passphraseController.clear();
                  _passphraseVisible = false;
                }
                viewModel.setUsePassphrase(value);
                _scheduleMasterFingerprintUpdate(immediate: !value);
              },
            ),
          ],
        ),
        if (viewModel.usePassphrase) ...[
          CoconutLayout.spacing_200h,
          CoconutTextField(
            key: _passphraseFieldKey,
            controller: _passphraseController,
            focusNode: _passphraseFocusNode,
            maxLength: 100,
            maxLines: 1,
            isLengthVisible: true,
            textInputFormatter: [LengthLimitingTextInputFormatter(100)],
            obscureText: !_passphraseVisible,
            placeholderText: t.wallet_home_screen.hot_wallet_create.passphrase_placeholder,
            backgroundColor: context.coconutColors.inputSurface,
            activeColor: context.coconutColors.primaryText,
            cursorColor: context.coconutColors.primaryText,
            suffix: IconButton(
              iconSize: 16,
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _passphraseVisible = !_passphraseVisible),
              icon: SvgPicture.asset(
                _passphraseVisible ? CommonVisibilityIconPath.eye : CommonVisibilityIconPath.eyeCrossed,
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(context.coconutColors.iconSecondary, BlendMode.srcIn),
              ),
            ),
            onChanged: (value) {
              viewModel.setPassphrase(value);
              _scheduleMasterFingerprintUpdate();
            },
          ),
          CoconutLayout.spacing_200h,
          Row(
            children: [
              CoconutCheckbox(
                isSelected: viewModel.enterPassphraseWhenSigning,
                onChanged: _setEnterPassphraseWhenSigning,
                disabledColor: context.coconutColors.chipSelectedBackground,
                color: context.coconutColors.chipSelectedBackground,
              ),
              CoconutLayout.spacing_200w,
              Expanded(
                child: GestureDetector(
                  onTap: () => _setEnterPassphraseWhenSigning(!viewModel.enterPassphraseWhenSigning),
                  child: Text(
                    t.wallet_home_screen.hot_wallet_create.enter_passphrase_when_signing,
                    style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _setEnterPassphraseWhenSigning(bool value) async {
    final viewModel = context.read<HotWalletRestoreViewModel>();
    if (!value) {
      viewModel.setEnterPassphraseWhenSigning(false);
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    var confirmed = false;
    await showConfirmDialog(
      context,
      context.read<PreferenceProvider>().language,
      t.wallet_home_screen.hot_wallet_create.passphrase_not_stored_title,
      t.wallet_home_screen.hot_wallet_create.passphrase_not_stored_description,
      leftButtonText: t.cancel,
      rightButtonText: t.wallet_home_screen.hot_wallet_create.passphrase_not_stored_confirm,
      onTapRight: () {
        confirmed = true;
        Navigator.of(context).pop();
      },
    );
    if (!mounted) return;
    _unfocusAfterDialogDismissed();
    if (confirmed) viewModel.setEnterPassphraseWhenSigning(true);
  }

  Widget _buildWalletNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.wallet_home_screen.hot_wallet_create.wallet_name,
          style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
        ),
        CoconutLayout.spacing_200h,
        CoconutTextField(
          key: _nameFieldKey,
          controller: _nameController,
          focusNode: _nameFocusNode,
          maxLength: 20,
          maxLines: 1,
          isLengthVisible: true,
          placeholderText: _suggestedName,
          backgroundColor: context.coconutColors.inputSurface,
          activeColor: context.coconutColors.primaryText,
          cursorColor: context.coconutColors.primaryText,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  void _changeWordCount(int count) {
    final viewModel = context.read<HotWalletRestoreViewModel>();
    _invalidWordIndexes.clear();
    _resetOnNextEditAfterRefocus.clear();
    viewModel.setWordCount(count);
    _syncControllers(viewModel);
    _focusIndex(0, count);
  }

  void _syncControllers(HotWalletRestoreViewModel viewModel) {
    for (var index = 0; index < 24; index++) {
      final value = index < viewModel.wordCount ? viewModel.words[index] : '';
      _wordControllers[index].clearSuggestion();
      _wordControllers[index].value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  void _focusNext(int index, int wordCount) => _focusIndex(index + 1, wordCount);

  void _focusIndex(int index, int wordCount) {
    if (index >= wordCount) {
      FocusScope.of(context).unfocus();
      return;
    }
    _wordFocusNodes[index].requestFocus();
  }

  Future<void> _clearAll() async {
    context.read<HotWalletRestoreViewModel>().clearWords();
    _invalidWordIndexes.clear();
    _resetOnNextEditAfterRefocus.clear();
    for (final controller in _wordControllers) {
      controller.clear();
      controller.clearSuggestion();
    }
    _wordFocusNodes.first.requestFocus();
  }

  Future<void> _restore() async {
    FocusManager.instance.primaryFocus?.unfocus();
    FocusScope.of(context).requestFocus(_screenFocusNode);
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    if (!mounted) return;
    final walletProvider = context.read<WalletProvider>();
    final viewModel = context.read<HotWalletRestoreViewModel>();
    final walletName = _nameController.text.trim().isEmpty ? _suggestedName : _nameController.text.trim();
    String descriptor;
    try {
      setState(() => _isCheckingDuplicate = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      descriptor = await viewModel.deriveDescriptor();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCheckingDuplicate = false);
      await _showRestoreFailedDialog();
      return;
    }
    if (!mounted) return;

    final duplicateHotWallet = walletProvider.findSameSinglesigWallet(descriptor, hasLocalKey: true);
    if (duplicateHotWallet != null) {
      setState(() => _isCheckingDuplicate = false);
      await showInfoDialog(
        context,
        context.read<PreferenceProvider>().language,
        t.wallet_home_screen.hot_wallet_restore.duplicate_wallet_title,
        '',
        descriptionSpan: buildDuplicateWalletDescriptionSpan(
          name: duplicateHotWallet.name,
          type: t.wallet_home_screen.hot_wallet_restore.hot_wallet_type,
        ),
      );
      return;
    }

    final duplicateWatchOnly = walletProvider.findSameSinglesigWallet(descriptor, hasLocalKey: false);
    var removeWatchOnly = false;
    if (duplicateWatchOnly != null) {
      setState(() => _isCheckingDuplicate = false);
      final decision = await _showWatchOnlyDuplicatePopup(duplicateWatchOnly);
      if (decision == null || !mounted) return;
      removeWatchOnly = decision;
      setState(() => _isCheckingDuplicate = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }

    final hasNameConflict = walletProvider.walletItemList.any(
      (wallet) => wallet.name == walletName && (!removeWatchOnly || wallet.id != duplicateWatchOnly?.id),
    );
    if (hasNameConflict) {
      setState(() => _isCheckingDuplicate = false);
      await showInfoDialog(
        context,
        context.read<PreferenceProvider>().language,
        t.wallet_home_screen.hot_wallet_create.duplicate_name_title,
        t.wallet_home_screen.hot_wallet_create.duplicate_name_description,
      );
      return;
    }

    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final restoredWallet = await viewModel.restore(
        walletProvider: walletProvider,
        walletName: walletName,
        derivedDescriptor: descriptor,
        replacingWatchOnlyWalletId: removeWatchOnly ? duplicateWatchOnly?.id : null,
      );
      if (removeWatchOnly && duplicateWatchOnly != null) {
        await walletProvider.deleteWallet(duplicateWatchOnly.id);
      }
      if (!mounted) return;
      setState(() => _isCheckingDuplicate = false);
      if (context.read<AuthProvider>().isAuthEnabled) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/wallet-detail',
          (route) => route.isFirst,
          arguments: {'id': restoredWallet.id, 'entryPoint': kEntryPointWalletHome},
        );
      } else {
        await showHotWalletAppLockGuideBottomSheet(context);
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/wallet-detail',
          (route) => route.isFirst,
          arguments: {'id': restoredWallet.id, 'entryPoint': kEntryPointWalletHome},
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCheckingDuplicate = false);
      await _showRestoreFailedDialog();
    }
  }

  Future<bool?> _showWatchOnlyDuplicatePopup(SinglesigWalletItem duplicateWatchOnly) {
    var removeWatchOnly = false;
    return showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => CoconutPopup(
                  languageCode: context.read<PreferenceProvider>().language,
                  title: t.wallet_home_screen.hot_wallet_restore.duplicate_wallet_title,
                  description: '',
                  descriptionSpan: buildDuplicateWalletDescriptionSpan(
                    name: duplicateWatchOnly.name,
                    type: t.wallet_home_screen.hot_wallet_restore.watch_only_type,
                  ),
                  backgroundColor: context.coconutColors.popupBackground.withValues(alpha: 0.7),
                  checkboxText: t.wallet_home_screen.hot_wallet_restore.remove_watch_only,
                  checkboxTextStyle: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
                  isCheckboxSelected: removeWatchOnly,
                  onCheckboxChanged: (value) => setDialogState(() => removeWatchOnly = value),
                  rightButtonText: t.wallet_home_screen.hot_wallet_restore.restore_wallet,
                  rightButtonColor: context.coconutColors.primaryText,
                  onTapRight: () => Navigator.of(dialogContext).pop(removeWatchOnly),
                ),
          ),
    );
  }

  Future<void> _showRestoreFailedDialog() {
    return showInfoDialog(
      context,
      context.read<PreferenceProvider>().language,
      t.alert.error_occurs,
      t.wallet_home_screen.hot_wallet_restore.restore_failed,
    );
  }
}
