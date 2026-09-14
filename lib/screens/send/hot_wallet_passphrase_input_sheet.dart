import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutTextField, CoconutPopup;
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/common/flutter_hot_wallet_authenticator.dart';
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:coconut_wallet/widgets/common/dialogs/dialog.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class HotWalletPassphraseInputSheet extends StatefulWidget {
  const HotWalletPassphraseInputSheet({
    super.key,
    required this.requiresAuthentication,
    required this.showIncorrectError,
    required this.onAuthenticationStarted,
    required this.onPassphraseInputResumed,
  });

  final bool requiresAuthentication;
  final bool showIncorrectError;
  final Future<void> Function() onAuthenticationStarted;
  final VoidCallback onPassphraseInputResumed;

  @override
  State<HotWalletPassphraseInputSheet> createState() => _HotWalletPassphraseInputSheetState();
}

class _HotWalletPassphraseInputSheetState extends State<HotWalletPassphraseInputSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSubmitting = false;
  late bool _isIncorrect;
  bool _isPassphraseVisible = false;

  @override
  void initState() {
    super.initState();
    _isIncorrect = widget.showIncorrectError;
    _controller.addListener(_handleChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _handleChanged() {
    if (!mounted) return;
    setState(() {
      if (_controller.text.isNotEmpty) _isIncorrect = false;
    });
  }

  Future<void> _complete() async {
    if (_controller.text.isEmpty || _isSubmitting) return;
    _focusNode.unfocus();
    setState(() => _isSubmitting = true);
    if (widget.requiresAuthentication) {
      await widget.onAuthenticationStarted();
      if (!mounted) return;
      final authenticated = await AppGuard.runWithoutPrivacyScreen(
        () => FlutterHotWalletAuthenticator(context).authenticate(),
      );
      if (!mounted) return;
      if (!authenticated) {
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
    }

    Navigator.pop(context, Uint8List.fromList(utf8.encode(_controller.text)));
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
                key: const ValueKey('hot-wallet-passphrase-input'),
                controller: _controller,
                focusNode: _focusNode,
                onChanged: (_) {},
                isError: _isIncorrect,
                errorText: _isIncorrect ? t.wallet_home_screen.hot_wallet_setup.passphrase_incorrect : null,
                descriptionText: widget.showIncorrectError ? ' ' : null,
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
