import 'package:coconut_design_system/coconut_design_system.dart'
    hide CoconutAppBar, CoconutTextField, CoconutTextFieldStyle;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/extensions/widget_animation_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:coconut_wallet/utils/hot_wallet_passphrase_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/overlays/coconut_loading_overlay.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HotWalletPassphraseCheckScreen extends StatefulWidget {
  const HotWalletPassphraseCheckScreen({super.key, required this.mnemonic, required this.descriptor});

  final Uint8List mnemonic;
  final String descriptor;

  @override
  State<HotWalletPassphraseCheckScreen> createState() => _HotWalletPassphraseCheckScreenState();
}

class _HotWalletPassphraseCheckScreenState extends State<HotWalletPassphraseCheckScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isIncorrect = false;
  bool _isChecking = false;
  bool _isCorrect = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  void _handleChanged() {
    if (mounted && !_isChecking && !_isCorrect) {
      setState(() => _isIncorrect = false);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChanged);
    _controller.clear();
    _controller.dispose();
    _focusNode.dispose();
    widget.mnemonic.fillRange(0, widget.mnemonic.length, 0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = t.wallet_home_screen.hot_wallet_setup;
    return Stack(
      children: [
        Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: context.coconutColors.background,
          appBar: CoconutAppBar.build(
            title: strings.passphrase_check_title,
            context: context,
            backgroundColor: context.coconutColors.background,
          ),
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.passphrase_confirm_question,
                            style: CoconutTypography.heading3_21_Bold.setColor(context.coconutColors.primaryText),
                          ),
                          AnimatedOpacity(
                            opacity: _isIncorrect ? 1 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                strings.passphrase_incorrect,
                                style: CoconutTypography.body2_14.setColor(context.coconutColors.danger),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child:
                                _isCorrect
                                    ? Column(
                                      key: const ValueKey('correct'),
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SvgPicture.asset(
                                          CommonFormIconPath.circleCheckFilled,
                                          width: 52,
                                          height: 52,
                                          colorFilter: ColorFilter.mode(
                                            context.coconutColors.iconPrimary,
                                            BlendMode.srcIn,
                                          ),
                                        ),
                                        CoconutLayout.spacing_500h,
                                        Text(
                                          strings.passphrase_correct,
                                          style: CoconutTypography.body1_16_Bold.setColor(
                                            context.coconutColors.primaryText,
                                          ),
                                        ),
                                      ],
                                    )
                                    : CoconutTextField(
                                      key: const ValueKey('input'),
                                      controller: _controller,
                                      focusNode: _focusNode,
                                      onChanged: (_) {},
                                      obscureText: true,
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      textAlign: TextAlign.center,
                                      textInputAction: TextInputAction.done,
                                      activeColor:
                                          _isIncorrect
                                              ? context.coconutColors.danger
                                              : context.coconutColors.primaryText,
                                      backgroundColor: Colors.transparent,
                                      isVisibleBorder: false,
                                      isLengthVisible: false,
                                      maxLines: 1,
                                      height: 52,
                                      padding: EdgeInsets.zero,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      onEditingComplete: _check,
                                    ).shakeAnimation(autoStart: _isIncorrect),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
                FixedBottomButton(
                  text: t.complete,
                  isActive: _controller.text.isNotEmpty && !_isChecking && !_isCorrect,
                  isVisibleAboveKeyboard: false,
                  showSurroundings: false,
                  onButtonClicked: _check,
                ),
              ],
            ),
          ),
        ),
        if (_isChecking) const Positioned.fill(child: CoconutLoadingOverlay(applyFullScreen: true)),
      ],
    );
  }

  Future<void> _check() async {
    if (_controller.text.isEmpty || _isChecking || _isCorrect) return;
    final passphrase = _controller.text;
    final mnemonic = widget.mnemonic;
    final descriptor = widget.descriptor;
    _focusNode.unfocus();
    setState(() {
      _isIncorrect = false;
      _isChecking = true;
    });

    // doesPassphraseMatchDescriptorBytes는 전달받은 mnemonic을 내부에서 복사해서만 사용하므로
    // widget.mnemonic 원본은 그대로 남아 있어 오답 시 재입력해도 다시 검증할 수 있다.
    final isCorrect = await doesPassphraseMatchDescriptorAsync(
      mnemonic: mnemonic,
      passphrase: passphrase,
      descriptor: descriptor,
    );
    if (!mounted) return;

    if (!isCorrect) {
      setState(() {
        _isChecking = false;
        _isIncorrect = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
      return;
    }

    _focusNode.unfocus();
    setState(() {
      _isChecking = false;
      _isCorrect = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.pop(context, true);
  }
}
