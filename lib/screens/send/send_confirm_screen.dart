import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart'
    hide
        CoconutAppBar,
        CoconutToolTip,
        CoconutTooltipType,
        CoconutTooltipState,
        CoconutToast,
        CoconutToastLevel,
        CoconutPopup;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/send_confirm_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_add/connected/bitbox02_connect_screen.dart';
import 'package:coconut_wallet/screens/send/broadcasting_screen.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_connectivity_service.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_device.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_transport.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_ble_connectivity_service.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_navigator.dart';
import 'package:coconut_wallet/services/security/hot_wallet_unlock_service.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/dialogs/dialog.dart';
import 'package:coconut_wallet/widgets/features/send/send_transaction_flow_card.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/send/send_amount_header.dart';
import 'package:coconut_wallet/widgets/features/send/send_output_detail_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

enum _HotWalletSigningStage { idle, authentication, signing, completed, finalReview }

class SendConfirmScreen extends StatefulWidget {
  final BitcoinUnit? currentUnit;

  const SendConfirmScreen({super.key, this.currentUnit});

  @override
  State<SendConfirmScreen> createState() => _SendConfirmScreenState();
}

class _SendConfirmScreenState extends State<SendConfirmScreen> with SingleTickerProviderStateMixin {
  late SendConfirmViewModel _viewModel;
  late BitcoinUnit _currentUnit;
  bool _isLocalSigning = false;
  late final AnimationController _signatureController;
  final Completer<void> _signatureCompositionLoaded = Completer<void>();
  _HotWalletSigningStage _signingStage = _HotWalletSigningStage.idle;
  bool _showTransactionFlow = true;
  bool _showOutputDetail = true;
  bool _showSigningStatus = false;

  String get totalSendAmountText =>
      _currentUnit.displayBitcoinAmount(UnitUtil.convertBitcoinToSatoshi(_viewModel.totalSendAmount ?? 0));

  String get totalCostText => _currentUnit.displayBitcoinAmount(
    _viewModel.totalUsedAmount,
    defaultWhenZero: t.calculation_failed,
    shouldCheckZero: true,
  );

  String get unitText => _currentUnit.symbol;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SendConfirmViewModel>(
      create: (_) => _viewModel,
      child: Consumer<SendConfirmViewModel>(
        builder: (context, viewModel, child) {
          final appBar = CoconutAppBar.build(title: t.send_confirm_screen.title, context: context);
          return Scaffold(
            backgroundColor: context.coconutColors.background,
            appBar: PreferredSize(
              preferredSize: appBar.preferredSize,
              child: AnimatedOpacity(
                opacity: _signingStage == _HotWalletSigningStage.idle ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                child: IgnorePointer(ignoring: _signingStage != _HotWalletSigningStage.idle, child: appBar),
              ),
            ),
            body: SafeArea(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 10, right: 10),
                    child: SingleChildScrollView(
                      physics:
                          _signingStage == _HotWalletSigningStage.idle ? null : const NeverScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          AnimatedSize(
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeInOutCubic,
                            alignment: Alignment.topCenter,
                            child:
                                _signingStage == _HotWalletSigningStage.idle
                                    ? const SizedBox.shrink()
                                    : Column(
                                      children: [
                                        CoconutLayout.spacing_1000h,
                                        AnimatedOpacity(
                                          opacity: _showSigningStatus ? 1 : 0,
                                          duration: const Duration(milliseconds: 220),
                                          curve: Curves.easeOutCubic,
                                          child: AnimatedContainer(
                                            height: 25.2,
                                            duration: const Duration(milliseconds: 280),
                                            curve: Curves.easeInOutCubic,
                                            child: AnimatedSwitcher(
                                              duration: const Duration(milliseconds: 360),
                                              layoutBuilder:
                                                  (currentChild, previousChildren) => Stack(
                                                    alignment: Alignment.center,
                                                    children: [
                                                      ...previousChildren,
                                                      if (currentChild != null) currentChild,
                                                    ],
                                                  ),
                                              transitionBuilder: (child, animation) {
                                                final isIncoming = child.key == ValueKey(_signingStage);
                                                final sequencedAnimation = CurvedAnimation(
                                                  parent: animation,
                                                  curve: const Interval(0.5, 1, curve: Curves.easeOutCubic),
                                                );
                                                final slideAnimation = Tween<Offset>(
                                                  begin: isIncoming ? const Offset(0, 0.35) : const Offset(0, -0.35),
                                                  end: Offset.zero,
                                                ).animate(sequencedAnimation);
                                                return SlideTransition(
                                                  position: slideAnimation,
                                                  child: FadeTransition(opacity: sequencedAnimation, child: child),
                                                );
                                              },
                                              child: _buildSigningStatus(),
                                            ),
                                          ),
                                        ),
                                        CoconutLayout.spacing_400h,
                                      ],
                                    ),
                          ),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 40, end: _signingStage == _HotWalletSigningStage.idle ? 40 : 0),
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeInOutCubic,
                            builder:
                                (context, topMargin, child) => SendAmountHeader(
                                  amountText: totalSendAmountText,
                                  unit: _currentUnit,
                                  satoshiAmount: UnitUtil.convertBitcoinToSatoshi(viewModel.totalSendAmount ?? 0),
                                  totalCostAmountText: totalCostText,
                                  onTap: _toggleUnit,
                                  topMargin: topMargin,
                                ),
                          ),
                          CoconutLayout.spacing_300h,
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: _SigningContentTransition(
                              visible: _showTransactionFlow,
                              child: _buildTransactionFlowCard(viewModel),
                            ),
                          ),
                          CoconutLayout.spacing_500h,
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: _SigningContentTransition(
                              visible: _showOutputDetail,
                              child: _buildOutputDetailCard(viewModel),
                            ),
                          ),
                          CoconutLayout.spacing_500h,
                          CoconutLayout.spacing_2500h,
                        ],
                      ),
                    ),
                  ),
                  if (_signingStage != _HotWalletSigningStage.idle)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: AnimatedSlide(
                            offset:
                                _signingStage == _HotWalletSigningStage.completed ||
                                        _signingStage == _HotWalletSigningStage.finalReview
                                    ? const Offset(0, -0.18)
                                    : Offset.zero,
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeInOutCubic,
                            child: AnimatedOpacity(
                              opacity:
                                  _signingStage == _HotWalletSigningStage.completed ||
                                          _signingStage == _HotWalletSigningStage.finalReview
                                      ? 0
                                      : 1,
                              duration: const Duration(milliseconds: 220),
                              child: Lottie.asset(
                                'assets/lottie/signature.json',
                                controller: _signatureController,
                                width: 180,
                                height: 180,
                                repeat: false,
                                delegates: LottieDelegates(
                                  values: [
                                    ValueDelegate.colorFilter([
                                      '**',
                                    ], value: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcATop)),
                                  ],
                                ),
                                onLoaded: (composition) {
                                  _signatureController.duration = composition.duration;
                                  if (!_signatureCompositionLoaded.isCompleted) {
                                    _signatureCompositionLoaded.complete();
                                  }
                                  if (_signingStage == _HotWalletSigningStage.authentication) {
                                    _signatureController.value = 1;
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  _SigningContentTransition(
                    visible: _signingStage == _HotWalletSigningStage.idle,
                    child: FixedBottomButton(
                      text:
                          viewModel.isHotWallet
                              ? viewModel.shouldEnterPassphraseWhenSigning
                                  ? t.send_confirm_screen.passphrase_input_title
                                  : t.sign
                              : t.next,
                      isActive: !_isLocalSigning,
                      onButtonClicked: () => _onButtonClicked(viewModel),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _signatureController = AnimationController(vsync: this);
    context.loaderOverlay.show();
    _currentUnit = widget.currentUnit ?? context.read<PreferenceProvider>().currentUnit;
    _viewModel = SendConfirmViewModel(
      Provider.of<SendInfoProvider>(context, listen: false),
      Provider.of<WalletProvider>(context, listen: false),
    );
    _viewModel
        .setEstimatedFeeAndTotalUsedAmount()
        .then((_) {
          if (mounted) {
            context.loaderOverlay.hide();
          }
        })
        .catchError((error) async {
          if (mounted) {
            context.loaderOverlay.hide();
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return CoconutPopup(
                  languageCode: context.read<PreferenceProvider>().language,
                  title: t.alert.error_tx.created_failed,
                  description: t.alert.error_tx.not_created(error: error.toString()),
                  onTapRight: () {
                    Navigator.pop(context);
                  },
                  rightButtonText: t.OK,
                );
              },
            );
          }
        });
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  Widget _buildSigningStatus() {
    final (text, emphasized) = switch (_signingStage) {
      _HotWalletSigningStage.authentication => (
        t.send_confirm_screen.authentication_required,
        t.send_confirm_screen.authentication_emphasis,
      ),
      _HotWalletSigningStage.signing => (
        t.send_confirm_screen.signing_in_progress,
        t.send_confirm_screen.signing_emphasis,
      ),
      _HotWalletSigningStage.completed => (t.send_confirm_screen.signing_completed, ''),
      _HotWalletSigningStage.finalReview => (t.broadcasting_screen.description, ''),
      _ => ('', ''),
    };
    if (_signingStage == _HotWalletSigningStage.idle) {
      return const SizedBox.shrink(key: ValueKey('idle'));
    }
    final parts = emphasized.isEmpty ? <String>[text] : text.split(emphasized);
    return Padding(
      key: ValueKey(_signingStage),
      padding: EdgeInsets.zero,
      child: Text.rich(
        TextSpan(
          style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.primaryText),
          children: [
            TextSpan(text: parts.first),
            if (emphasized.isNotEmpty) ...[
              TextSpan(text: emphasized, style: TextStyle(color: context.coconutColors.primary)),
              if (parts.length > 1) TextSpan(text: parts.sublist(1).join(emphasized)),
            ],
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Future<void> _enterAuthenticationStage({required bool requiresAuthentication}) async {
    setState(() {
      _isLocalSigning = true;
      _signingStage = requiresAuthentication ? _HotWalletSigningStage.authentication : _HotWalletSigningStage.signing;
      _showTransactionFlow = false;
      _showSigningStatus = false;
    });
    if (requiresAuthentication) {
      _signatureController.value = 1;
    }
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) setState(() => _showOutputDetail = false);
    await Future.delayed(const Duration(milliseconds: 220));
    if (mounted) setState(() => _showSigningStatus = true);
  }

  void _resumePassphraseInput() {
    if (!mounted) return;
    _signatureController.stop();
    setState(() {
      _signingStage = _HotWalletSigningStage.idle;
      _showTransactionFlow = true;
      _showOutputDetail = true;
      _showSigningStatus = false;
    });
  }

  void _restoreConfirmationContent() {
    if (!mounted) return;
    _signatureController.stop();
    setState(() {
      _isLocalSigning = false;
      _signingStage = _HotWalletSigningStage.idle;
      _showOutputDetail = true;
      _showSigningStatus = false;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _showTransactionFlow = true);
    });
  }

  Future<void> _onButtonClicked(SendConfirmViewModel viewModel) async {
    if (viewModel.isHotWallet) {
      await _signHotWallet(viewModel);
      return;
    }

    context.loaderOverlay.show();
    viewModel.setTxWaitingForSign();
    if (!mounted) return;

    final connectedDeviceSource = await viewModel.findConnectedMatchingDevice();
    if (!mounted) return;
    context.loaderOverlay.hide();

    if (connectedDeviceSource != null && connectedDeviceSource != viewModel.walletImportSource) {
      final language = context.read<PreferenceProvider>().language;
      final deviceName = connectedDeviceSource.displayName;
      if (!mounted) return;
      bool useConnectedDevice = false;
      await showConfirmDialog(
        context,
        language,
        t.send_confirm_screen.sign_with_connected_device_title,
        t.send_confirm_screen.sign_with_connected_device_description(deviceName: deviceName),
        leftButtonText: t.no,
        rightButtonText: t.yes,
        barrierDismissible: true,
        onTapLeft: () {
          useConnectedDevice = false;
          Navigator.of(context).pop();
        },
        onTapRight: () {
          useConnectedDevice = true;
          Navigator.of(context).pop();
        },
      );
      if (!mounted) return;
      _navigateToNextScreen(viewModel, connectedDeviceSource: useConnectedDevice ? connectedDeviceSource : null);
      return;
    }

    _navigateToNextScreen(viewModel, connectedDeviceSource: connectedDeviceSource);
  }

  Future<void> _signHotWallet(SendConfirmViewModel viewModel) async {
    if (_isLocalSigning) return;
    final storageKey = viewModel.hotWalletSecretStorageKey;
    if (storageKey == null) {
      await _showLocalSignFailure();
      return;
    }

    final requiresAuthentication = context.read<AuthProvider>().isAuthEnabled;
    final requiresPassphrase = viewModel.shouldEnterPassphraseWhenSigning;
    if (requiresPassphrase) {
      setState(() => _isLocalSigning = true);
    } else {
      await _enterAuthenticationStage(requiresAuthentication: requiresAuthentication);
    }
    if (!mounted) return;
    var shouldRestore = true;
    try {
      _HotWalletSigningCredentials? credentials;
      if (requiresPassphrase) {
        credentials = await CommonBottomSheets.showBottomSheet<_HotWalletSigningCredentials>(
          context: context,
          title: t.send_confirm_screen.passphrase_input_title,
          appBar: CoconutAppBar.build(
            isBottom: true,
            context: context,
            onBackPressed: () => Navigator.pop(context),
            title: t.send_confirm_screen.passphrase_input_title,
          ),
          backgroundColor: context.coconutColors.surfaceBottomSheet,
          showDragHandle: true,
          titlePadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: _HotWalletPassphraseInputSheet(
            storageKey: storageKey,
            requiresAuthentication: requiresAuthentication,
            validatePassphrase:
                (mnemonic, passphrase) =>
                    viewModel.validateHotWalletPassphrase(mnemonic: mnemonic, passphrase: passphrase),
            onAuthenticationStarted: () => _enterAuthenticationStage(requiresAuthentication: true),
            onPassphraseInputResumed: _resumePassphraseInput,
          ),
        );
        if (!mounted || credentials == null) return;
        if (!requiresAuthentication) {
          await _enterAuthenticationStage(requiresAuthentication: false);
          if (!mounted) return;
        }
      } else {
        final plaintext = await AppGuard.runWithoutPrivacyScreen(
          () => HotWalletUnlockService().unlockPreferBiometrics(
            context: context,
            storageKey: storageKey,
            onDecrypting: () {
              if (mounted) context.loaderOverlay.show();
            },
          ),
        );
        if (!mounted) return;
        context.loaderOverlay.hide();

        if (plaintext == null) {
          await showInfoDialog(
            context,
            context.read<PreferenceProvider>().language,
            t.send_confirm_screen.authentication_failed_title,
            t.send_confirm_screen.authentication_failed_description,
          );
          return;
        }
        credentials = _HotWalletSigningCredentials(mnemonic: plaintext.mnemonic, passphrase: plaintext.passphrase);
      }

      setState(() => _signingStage = _HotWalletSigningStage.signing);
      await WidgetsBinding.instance.endOfFrame;
      await _signatureCompositionLoaded.future;
      if (!mounted) return;
      final signingAnimationStartedAt = DateTime.now();
      _signatureController.repeat();
      await viewModel.signHotWallet(mnemonic: credentials.mnemonic, passphrase: credentials.passphrase);
      if (!mounted) return;
      final signingAnimationElapsed = DateTime.now().difference(signingAnimationStartedAt);
      const minimumSigningAnimationDuration = Duration(milliseconds: 1500);
      if (signingAnimationElapsed < minimumSigningAnimationDuration) {
        await Future.delayed(minimumSigningAnimationDuration - signingAnimationElapsed);
      }
      if (!mounted) return;
      _signatureController.stop();
      await _signatureController.forward();
      if (!mounted) return;
      context.loaderOverlay.hide();
      setState(() => _signingStage = _HotWalletSigningStage.completed);
      await Future.delayed(const Duration(milliseconds: 1300));
      if (!mounted) return;
      setState(() => _signingStage = _HotWalletSigningStage.finalReview);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      shouldRestore = false;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          settings: const RouteSettings(name: '/broadcasting'),
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          pageBuilder:
              (_, animation, secondaryAnimation) => BroadcastingScreen(
                animateHotWalletEntry: true,
                initialAmount: UnitUtil.convertBitcoinToSatoshi(viewModel.totalSendAmount ?? 0),
                initialTotalAmount: viewModel.totalUsedAmount,
              ),
          transitionsBuilder:
              (_, animation, secondaryAnimation, child) =>
                  FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic), child: child),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      context.loaderOverlay.hide();
      await _showLocalSignFailure();
    } finally {
      if (mounted && shouldRestore) {
        context.loaderOverlay.hide();
        _restoreConfirmationContent();
      }
    }
  }

  Future<void> _showLocalSignFailure() => showInfoDialog(
    context,
    context.read<PreferenceProvider>().language,
    t.send_confirm_screen.signing_failed_title,
    t.send_confirm_screen.signing_failed_description,
  );

  void _navigateToNextScreen(SendConfirmViewModel viewModel, {WalletImportSource? connectedDeviceSource}) {
    final source = connectedDeviceSource ?? viewModel.walletImportSource;
    switch (source) {
      case WalletImportSource.bitbox02:
        if (connectedDeviceSource != null) {
          _pushBitBox02SignScreen(viewModel);
        } else {
          _navigateToBitBox02ConnectIfNeeded(viewModel);
        }
      case WalletImportSource.trezor:
        if (connectedDeviceSource != null) {
          _pushTrezorSignScreen(viewModel);
        } else {
          _navigateToTrezorConnectIfNeeded(viewModel);
        }
      default:
        Navigator.pushNamed(context, '/unsigned-transaction-qr', arguments: {'walletName': viewModel.walletName});
    }
  }

  void _pushBitBox02SignScreen(SendConfirmViewModel viewModel) {
    Navigator.pushNamed(
      context,
      '/bitbox02-sign',
      arguments: {
        'psbtBase64': viewModel.txWaitingForSign,
        'walletName': viewModel.walletName,
        'walletFingerprint': viewModel.walletFingerprint,
        'isFromSendFlow': true,
        'transport': BitBox02Transport.resolveForSign(),
      },
    );
  }

  Future<void> _navigateToBitBox02ConnectIfNeeded(SendConfirmViewModel viewModel) async {
    final isConnected = await BitBox02ConnectivityService.isDeviceConnected();
    final lastConnected = BitBox02Device.lastConnected;
    final hasSession = lastConnected != null;
    final isMatchingWallet =
        hasSession && lastConnected.cachedXpub != null && lastConnected.cachedXpub == viewModel.walletExtendedPublicKey;
    if (!mounted) return;
    if (isConnected && hasSession && isMatchingWallet) {
      _pushBitBox02SignScreen(viewModel);
    } else {
      CommonBottomSheets.showCustomHeightBottomSheet(
        context: context,
        child: BitBox02ConnectScreen(
          importSource: WalletImportSource.bitbox02,
          psbtBase64: viewModel.txWaitingForSign,
          walletName: viewModel.walletName,
          walletFingerprint: viewModel.walletFingerprint,
          resumeFromExistingSession: isConnected && hasSession,
        ),
        heightRatio: 0.9,
      );
    }
  }

  void _pushTrezorSignScreen(SendConfirmViewModel viewModel) {
    final lastConnected = TrezorDevice.lastConnected!;
    Navigator.pushNamed(
      context,
      '/trezor-sign',
      arguments: {
        'psbtBase64': viewModel.txWaitingForSign,
        'walletName': viewModel.walletName,
        'walletFingerprint': viewModel.walletFingerprint,
        'isFromSendFlow': true,
        'transport': lastConnected.transport.name,
      },
    );
  }

  Future<void> _navigateToTrezorConnectIfNeeded(SendConfirmViewModel viewModel) async {
    final lastConnected = TrezorDevice.lastConnected;
    final isConnected = await TrezorBleConnectivityService.isDeviceConnected(
      lastConnected?.transport ?? TrezorTransport.ble,
    );
    final hasSession = lastConnected != null;
    final isMatchingWallet =
        hasSession && lastConnected.cachedXpub != null && lastConnected.cachedXpub == viewModel.walletExtendedPublicKey;
    if (!mounted) return;
    if (isConnected && hasSession && isMatchingWallet) {
      _pushTrezorSignScreen(viewModel);
    } else {
      TrezorNavigator.showConnectScreen(
        context: context,
        psbtBase64: viewModel.txWaitingForSign,
        walletName: viewModel.walletName,
        walletFingerprint: viewModel.walletFingerprint,
        resumeFromExistingSession: isConnected && hasSession,
      );
    }
  }

  void _toggleUnit() {
    setState(() {
      _currentUnit = _currentUnit.next;
    });
  }

  Widget _buildTransactionFlowCard(SendConfirmViewModel viewModel) {
    final transaction = viewModel.transaction;
    if (transaction == null) {
      return const SizedBox.shrink();
    }

    final inputCount = transaction.inputs.length;
    final List<int?> inputAmounts = List<int?>.from(viewModel.inputAmounts);
    if (inputAmounts.length != inputCount) {
      inputAmounts
        ..clear()
        ..addAll(List<int?>.filled(inputCount, null));
    }

    return SendTransactionFlowCard(
      inputAmounts: inputAmounts,
      externalOutputAmounts: viewModel.externalOutputAmounts,
      changeOutputAmounts: viewModel.changeOutputAmounts,
      fee: viewModel.estimatedFee,
      currentUnit: _currentUnit,
    );
  }

  Widget _buildOutputDetailCard(SendConfirmViewModel viewModel) {
    final transaction = viewModel.transaction;
    if (transaction == null || transaction.outputs.isEmpty) {
      return const SizedBox.shrink();
    }

    final detailItems = <OutputDetailItem>[];
    int outputIndex = 0;
    for (final output in transaction.outputs) {
      final isChange = output.isChangeOutput == true;
      if (!isChange) {
        outputIndex += 1;
      }
      detailItems.add(
        OutputDetailItem(
          label: isChange ? t.change : t.send_confirm_screen.flow_output_title(index: outputIndex),
          address: output.getAddress(),
          amountSats: output.amount,
          isChange: isChange,
        ),
      );
    }

    return SendOutputDetailCard(items: detailItems, currentUnit: _currentUnit);
  }
}

class _SigningContentTransition extends StatelessWidget {
  const _SigningContentTransition({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !visible,
    child: AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 0.12),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
      child: AnimatedOpacity(opacity: visible ? 1 : 0, duration: const Duration(milliseconds: 220), child: child),
    ),
  );
}

class _HotWalletSigningCredentials {
  const _HotWalletSigningCredentials({required this.mnemonic, required this.passphrase});

  final String mnemonic;
  final String passphrase;
}

class _HotWalletPassphraseInputSheet extends StatefulWidget {
  const _HotWalletPassphraseInputSheet({
    required this.storageKey,
    required this.requiresAuthentication,
    required this.validatePassphrase,
    required this.onAuthenticationStarted,
    required this.onPassphraseInputResumed,
  });

  final String storageKey;
  final bool requiresAuthentication;
  final Future<bool> Function(String mnemonic, String passphrase) validatePassphrase;
  final Future<void> Function() onAuthenticationStarted;
  final VoidCallback onPassphraseInputResumed;

  @override
  State<_HotWalletPassphraseInputSheet> createState() => _HotWalletPassphraseInputSheetState();
}

class _HotWalletPassphraseInputSheetState extends State<_HotWalletPassphraseInputSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSubmitting = false;
  bool _isIncorrect = false;
  bool _isPassphraseVisible = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _handleChanged() {
    if (mounted) {
      setState(() => _isIncorrect = false);
    }
  }

  Future<void> _complete() async {
    if (_controller.text.isEmpty || _isSubmitting) return;
    _focusNode.unfocus();
    setState(() => _isSubmitting = true);
    if (widget.requiresAuthentication) {
      await widget.onAuthenticationStarted();
      if (!mounted) return;
    }

    try {
      final plaintext = await AppGuard.runWithoutPrivacyScreen(
        () => HotWalletUnlockService().unlockPreferBiometrics(
          context: context,
          storageKey: widget.storageKey,
          onDecrypting: () {
            if (mounted) context.loaderOverlay.show();
          },
        ),
      );
      if (!mounted) return;

      if (plaintext == null) {
        context.loaderOverlay.hide();
        setState(() => _isSubmitting = false);
        await showInfoDialog(
          context,
          context.read<PreferenceProvider>().language,
          t.send_confirm_screen.authentication_failed_title,
          t.send_confirm_screen.authentication_failed_description,
        );
        widget.onPassphraseInputResumed();
        return;
      }

      final enteredPassphrase = _controller.text;
      final isMatchingWallet = await widget.validatePassphrase(plaintext.mnemonic, enteredPassphrase);
      if (!mounted) return;
      context.loaderOverlay.hide();
      if (!isMatchingWallet) {
        setState(() {
          _isSubmitting = false;
          _isIncorrect = true;
        });
        widget.onPassphraseInputResumed();
        _focusNode.requestFocus();
        return;
      }

      Navigator.pop(context, _HotWalletSigningCredentials(mnemonic: plaintext.mnemonic, passphrase: enteredPassphrase));
    } catch (_) {
      if (!mounted) return;
      context.loaderOverlay.hide();
      setState(() => _isSubmitting = false);
      widget.onPassphraseInputResumed();
      await showInfoDialog(
        context,
        context.read<PreferenceProvider>().language,
        t.send_confirm_screen.signing_failed_title,
        t.send_confirm_screen.signing_failed_description,
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChanged);
    _controller.clear();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _focusNode.unfocus,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CoconutTextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: (_) {},
                isError: _isIncorrect,
                errorText: _isIncorrect ? t.wallet_home_screen.hot_wallet_setup.passphrase_incorrect : null,
                obscureText: !_isPassphraseVisible,
                autocorrect: false,
                enableSuggestions: false,
                maxLines: 1,
                textInputAction: TextInputAction.done,
                placeholderText: t.passphrase_input_text_field.placeholder,
                suffix: IconButton(
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  onPressed: () => setState(() => _isPassphraseVisible = !_isPassphraseVisible),
                  icon: SvgPicture.asset(
                    _isPassphraseVisible ? CommonVisibilityIconPath.eye : CommonVisibilityIconPath.eyeCrossed,
                    width: 16,
                    height: 16,
                    colorFilter: ColorFilter.mode(context.coconutColors.iconSecondary, BlendMode.srcIn),
                  ),
                ),
                onEditingComplete: _complete,
              ),
              CoconutLayout.spacing_500h,
              InlineActionButton(
                text: t.sign,
                isActive: _controller.text.isNotEmpty && !_isSubmitting,
                onPressed: _complete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
