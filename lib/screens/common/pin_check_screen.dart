import 'package:coconut_wallet/providers/view_model/common/pin_check_view_model.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/widgets/common/overlays/coconut_loading_overlay.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/features/auth/pin/pin_input_pad.dart';
import 'package:provider/provider.dart';

class PinCheckScreen extends StatefulWidget {
  final bool appEntrance;
  final Function? onComplete;
  final bool allowBiometrics;
  const PinCheckScreen({super.key, this.appEntrance = false, this.onComplete, this.allowBiometrics = true});

  @override
  State<PinCheckScreen> createState() => _PinCheckScreenState();
}

class _PinCheckScreenState extends State<PinCheckScreen> with WidgetsBindingObserver {
  late PinCheckViewModel _viewModel;
  final GlobalKey<PinInputPadState> _pinInputScreenKey = GlobalKey<PinInputPadState>();
  late AuthProvider _authProvider;
  bool _isPause = false;

  @override
  void initState() {
    super.initState();
    _authProvider = context.read<AuthProvider>();
    _viewModel = PinCheckViewModel(_authProvider);
    _viewModel.initialize();
    _viewModel.addListener(_onChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (AppLifecycleState.paused == state) {
      _isPause = true;
    } else if (AppLifecycleState.resumed == state && _isPause) {
      _isPause = false;
      _viewModel.onResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewModel.removeListener(_onChanged);
    _viewModel.dispose();
    super.dispose();
  }

  void _complete() {
    if (!widget.appEntrance) Navigator.pop(context, true);
    widget.onComplete?.call();
  }

  Future<void> _onKeyTap(String value) async {
    if (_viewModel.isLoading) return;
    if (value == 'bio' && widget.allowBiometrics) {
      if (await _viewModel.verifyBiometric() && mounted) _complete();
      return;
    }
    if (!_viewModel.canEnterPin) return;
    _viewModel.enterKey(value);
    if (value != '<') vibrateExtraLight();
    if (_viewModel.isPinComplete) {
      final success = await _viewModel.verifyPin();
      if (!mounted) return;
      if (success == true) {
        _complete();
      } else if (success == false) {
        vibrateLightDouble();
      }
    }
  }

  void _showResetConfirmDialog() async {
    vibrateMedium();

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return CoconutPopup(
          languageCode: context.read<PreferenceProvider>().language,
          title: t.alert.forgot_password.title,
          description: t.alert.forgot_password.description,
          onTapRight: () async {
            await _authProvider.resetPassword(resetWallets: Provider.of<RealmManager>(context, listen: false).reset);
            if (!context.mounted) return;
            widget.onComplete?.call();
            if (mounted) {
              Navigator.of(context).pop();
            }
          },
          onTapLeft: () {
            Navigator.of(context).pop();
          },
          rightButtonText: t.alert.forgot_password.btn_reset,
          rightButtonColor: context.coconutColors.danger,
          leftButtonText: t.cancel,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PinInputPad(
          key: _pinInputScreenKey,
          appBarVisible: !widget.appEntrance,
          title: widget.appEntrance ? '' : t.pin_check_screen.text,
          initOptionVisible: widget.appEntrance,
          pin: _viewModel.pin,
          errorMessage: _viewModel.errorMessage,
          onKeyTap: _onKeyTap,
          pinShuffleNumbers:
              widget.allowBiometrics
                  ? _viewModel.shuffledPinNumbers
                  : _viewModel.shuffledPinNumbers.map((value) => value == 'bio' ? '' : value).toList(),
          onClosePressed: () {
            Navigator.pop(context);
          },
          onReset:
              widget.appEntrance
                  ? () {
                    _showResetConfirmDialog();
                  }
                  : null,
          step: 0,
          pinLength: _authProvider.pinLength,
        ),
        if (_viewModel.isLoading) const Positioned.fill(child: CoconutLoadingOverlay(applyFullScreen: true)),
      ],
    );
  }
}
