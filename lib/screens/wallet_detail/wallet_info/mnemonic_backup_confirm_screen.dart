import 'dart:math';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/extensions/widget_animation_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/hot_wallet_passphrase_util.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

List<int> selectMnemonicChallengeIndices({required int wordCount, int challengeCount = 3, Random? random}) {
  if (wordCount < challengeCount) {
    throw ArgumentError.value(wordCount, 'wordCount', 'Not enough mnemonic words for the requested challenges');
  }
  final indices = List<int>.generate(wordCount, (index) => index)..shuffle(random ?? Random.secure());
  return List<int>.unmodifiable(indices.take(challengeCount));
}

class MnemonicBackupConfirmScreen extends StatefulWidget {
  const MnemonicBackupConfirmScreen({
    super.key,
    required this.mnemonic,
    this.passphrase = '',
    this.descriptor = '',
    this.confirmPassphrase = false,
    this.walletId,
    this.continueToAppLockGuide = false,
  });

  final String mnemonic;
  final String passphrase;
  final String descriptor;
  final bool confirmPassphrase;
  final int? walletId;
  final bool continueToAppLockGuide;

  @override
  State<MnemonicBackupConfirmScreen> createState() => _MnemonicBackupConfirmScreenState();
}

class _MnemonicBackupConfirmScreenState extends State<MnemonicBackupConfirmScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final List<String> _words;
  late final List<int> _questionIndices;
  int _questionIndex = 0;
  double _progress = 0;
  bool _isIncorrect = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _words = widget.mnemonic.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList(growable: false);
    _questionIndices = selectMnemonicChallengeIndices(wordCount: _words.length, challengeCount: 3);
    _controller.addListener(_handleInputChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showKeyboard());
  }

  void _handleInputChanged() {
    if (!mounted) return;
    setState(() => _isIncorrect = false);
  }

  void _showKeyboard() {
    if (!mounted) return;
    _focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focusNode.hasFocus) return;
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleInputChanged);
    _controller.clear();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = t.wallet_home_screen.hot_wallet_setup;
    final isPassphraseQuestion = widget.confirmPassphrase && _questionIndex == _questionIndices.length;
    final wordPosition = isPassphraseQuestion ? 0 : _questionIndices[_questionIndex] + 1;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: context.coconutColors.background,
      appBar: CoconutAppBar.build(
        title: strings.backup_confirm_title,
        context: context,
        backgroundColor: context.coconutColors.background,
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _showKeyboard,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder:
                        (context, constraints) => Align(
                          alignment: Alignment.centerLeft,
                          child: ClipRRect(
                            borderRadius:
                                _progress == 1 ? BorderRadius.zero : const BorderRadius.all(Radius.circular(6)),
                            child: AnimatedContainer(
                              width: constraints.maxWidth * _progress,
                              height: 4,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              color: context.coconutColors.primaryText,
                            ),
                          ),
                        ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPassphraseQuestion
                              ? strings.passphrase_confirm_question
                              : strings.backup_question(position: wordPosition),
                          style: CoconutTypography.heading3_21_Bold.setColor(context.coconutColors.primaryText),
                        ),
                        AnimatedOpacity(
                          opacity: _isIncorrect ? 1 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              isPassphraseQuestion ? strings.passphrase_incorrect : strings.backup_incorrect,
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
                        child: CoconutTextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          onChanged: (_) {},
                          autocorrect: false,
                          enableSuggestions: false,
                          obscureText: isPassphraseQuestion,
                          textAlign: TextAlign.center,
                          textInputAction: TextInputAction.done,
                          cursorColor: context.coconutColors.primaryText,
                          activeColor: _isIncorrect ? context.coconutColors.danger : context.coconutColors.primaryText,
                          backgroundColor: Colors.transparent,
                          isVisibleBorder: false,
                          isLengthVisible: false,
                          maxLines: 1,
                          height: 52,
                          padding: EdgeInsets.zero,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontHeight: 1,
                          onEditingComplete: _submitAnswer,
                        ).shakeAnimation(
                          duration: 500,
                          shakeOffset: 3,
                          shakeAmount: 3,
                          autoStart: _isIncorrect,
                          direction: Axis.horizontal,
                          curve: Curves.easeInOut,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
              FixedBottomButton(
                text: t.complete,
                isActive: _controller.text.trim().isNotEmpty && !_isProcessing,
                isVisibleAboveKeyboard: false,
                showSurroundings: false,
                onButtonClicked: _submitAnswer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitAnswer() async {
    if (_isProcessing || _controller.text.trim().isEmpty) return;
    final isPassphraseQuestion = widget.confirmPassphrase && _questionIndex == _questionIndices.length;
    final isCorrect =
        isPassphraseQuestion
            ? _isPassphraseCorrect(_controller.text)
            : _controller.text.trim().toLowerCase() == _words[_questionIndices[_questionIndex]].toLowerCase();
    if (!isCorrect) {
      setState(() {
        _isIncorrect = true;
      });
      _showKeyboard();
      return;
    }

    final completedCount = _questionIndex + 1;
    final questionCount = _questionIndices.length + (widget.confirmPassphrase ? 1 : 0);
    setState(() {
      _isIncorrect = false;
      _isProcessing = true;
      _progress = completedCount / questionCount;
    });

    if (completedCount == questionCount) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      _focusNode.unfocus();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      final isComplete = await Navigator.pushNamed(
        context,
        '/mnemonic-backup-complete',
        arguments: {'walletId': widget.walletId, 'continueToAppLockGuide': widget.continueToAppLockGuide},
      );
      if (!mounted || isComplete != true) return;
      Navigator.pop(context, true);
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _controller.clear();
    setState(() {
      _questionIndex++;
      _isProcessing = false;
    });
    _showKeyboard();
  }

  bool _isPassphraseCorrect(String input) {
    if (widget.passphrase.isNotEmpty) return input == widget.passphrase;
    if (widget.descriptor.isEmpty) return false;

    return doesPassphraseMatchDescriptor(mnemonic: widget.mnemonic, passphrase: input, descriptor: widget.descriptor);
  }
}
