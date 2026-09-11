import 'dart:convert';
import 'dart:math';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/extensions/widget_animation_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/hot_wallet_passphrase_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/overlays/coconut_loading_overlay.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 니모닉 바이트를 공백(0x20) 기준으로 잘라서 단어별 바이트 복사본 리스트를 만든다.
/// 각 단어는 [Uint8List.sublistView]가 아닌 복사본이므로, 원본 니모닉 버퍼와
/// 독립적으로 wipe할 수 있다.
List<Uint8List> splitMnemonicWordBytes(Uint8List mnemonic) {
  final words = <Uint8List>[];
  int start = -1;
  for (int i = 0; i < mnemonic.length; i++) {
    if (mnemonic[i] == 0x20) {
      if (start >= 0) {
        words.add(mnemonic.sublist(start, i));
        start = -1;
      }
    } else if (start < 0) {
      start = i;
    }
  }
  if (start >= 0) {
    words.add(mnemonic.sublist(start));
  }
  return List<Uint8List>.unmodifiable(words);
}

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
    required this.passphrase,
    this.descriptor = '',
    this.confirmPassphrase = false,
    this.walletId,
    this.continueToAppLockGuide = false,
  });

  final Uint8List mnemonic;
  final Uint8List passphrase;
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
  late final List<Uint8List> _wordBytes;
  late final List<int> _questionIndices;
  int _questionIndex = 0;
  double _progress = 0;
  bool _isIncorrect = false;
  bool _isProcessing = false;
  bool _isVerifyingPassphrase = false;

  @override
  void initState() {
    super.initState();
    _wordBytes = splitMnemonicWordBytes(widget.mnemonic);
    _questionIndices = selectMnemonicChallengeIndices(wordCount: _wordBytes.length, challengeCount: 3);
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
    for (final word in _wordBytes) {
      word.fillRange(0, word.length, 0);
    }
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
              if (_isVerifyingPassphrase)
                const Positioned.fill(child: CoconutLoadingOverlay(applyFullScreen: true, indicatorSize: 36)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitAnswer() async {
    if (_isProcessing || _controller.text.trim().isEmpty) return;
    final isPassphraseQuestion = widget.confirmPassphrase && _questionIndex == _questionIndices.length;
    final requiresDescriptorVerification =
        isPassphraseQuestion && widget.passphrase.isEmpty && widget.descriptor.isNotEmpty;
    setState(() {
      _isIncorrect = false;
      _isProcessing = true;
      _isVerifyingPassphrase = requiresDescriptorVerification;
    });

    late final bool isCorrect;
    try {
      isCorrect =
          isPassphraseQuestion
              ? await _isPassphraseCorrect(_controller.text)
              : _isMnemonicWordCorrect(_questionIndices[_questionIndex], _controller.text);
    } finally {
      if (mounted && _isVerifyingPassphrase) {
        setState(() => _isVerifyingPassphrase = false);
      }
    }
    if (!mounted) return;
    if (!isCorrect) {
      setState(() {
        _isIncorrect = true;
        _isProcessing = false;
      });
      _showKeyboard();
      return;
    }

    final completedCount = _questionIndex + 1;
    final questionCount = _questionIndices.length + (widget.confirmPassphrase ? 1 : 0);
    setState(() {
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

  bool _isMnemonicWordCorrect(int wordIndex, String input) {
    // BIP-39 단어는 항상 소문자 ASCII이므로, 사용자 입력을 소문자로 변환해
    // 바이트로 인코딩한 뒤 니모닉 단어 바이트와 직접 비교한다.
    // 니모닉 자체는 String으로 변환하지 않는다.
    final guess = Uint8List.fromList(utf8.encode(input.trim().toLowerCase()));
    return listEquals(guess, _wordBytes[wordIndex]);
  }

  Future<bool> _isPassphraseCorrect(String input) async {
    if (widget.passphrase.isNotEmpty) {
      final guess = Uint8List.fromList(utf8.encode(input));
      return listEquals(guess, widget.passphrase);
    }
    if (widget.descriptor.isEmpty) return false;

    return doesPassphraseMatchDescriptorAsync(
      mnemonic: widget.mnemonic,
      passphrase: input,
      descriptor: widget.descriptor,
    );
  }
}
