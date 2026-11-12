import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutPopup;
import 'package:coconut_wallet/constants/lottie_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/ark/ark_board.dart';
import 'package:coconut_wallet/model/ark/ark_movement.dart';
import 'package:coconut_wallet/providers/ark_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/features/transaction/icon/pending_transaction_lottie_icon.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

/// How a payment from Ark got going: the movement it created, and whether it is already done (an
/// Ark payment, an on-chain payment once broadcast) or still in flight (Lightning, which bark
/// finishes on later syncs).
class ArkPaymentStart {
  const ArkPaymentStart({this.movementId, required this.isDone});

  final int? movementId;
  final bool isDone;
}

/// Pays from Ark with the send screen's broadcast animation: "Sending request" while it runs, then
/// "Transaction Sent" as on-chain sends end. A payment that isn't done within five seconds shows as
/// pending (it finishes in the background) instead. Confirm goes back to where Send started.
class ArkPaymentScreen extends StatefulWidget {
  const ArkPaymentScreen({super.key, required this.walletId, required this.pay, required this.isSendStart});

  final int walletId;

  /// Starts the payment. Throws [ArkMovePendingException] when bark accepted it but finishes it
  /// later, and anything else when it failed.
  final Future<ArkPaymentStart> Function() pay;

  /// The route Confirm returns to.
  final RoutePredicate isSendStart;

  @override
  State<ArkPaymentScreen> createState() => _ArkPaymentScreenState();
}

enum _Outcome { sending, sent, pending }

class _ArkPaymentScreenState extends State<ArkPaymentScreen> with SingleTickerProviderStateMixin {
  static const _pendingAfter = Duration(seconds: 5);

  late final AnimationController _lottie = AnimationController(vsync: this);
  final Completer<void> _lottieLoaded = Completer<void>();
  late final ArkProvider _arkProvider;
  _Outcome _outcome = _Outcome.sending;
  bool _isFinished = false;
  Timer? _pendingTimer;
  int? _watchedMovementId;

  @override
  void initState() {
    super.initState();
    _arkProvider = context.read<ArkProvider>();
    _arkProvider.setFastSync(widget.walletId, true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _pendingTimer?.cancel();
    _arkProvider.cacheRevision.removeListener(_onArkChanged);
    _arkProvider.setFastSync(widget.walletId, false);
    _lottie.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    await _lottieLoaded.future.timeout(const Duration(seconds: 2), onTimeout: () {});
    unawaited(_spin());
    _pendingTimer = Timer(_pendingAfter, () => _settle(_Outcome.pending));
    try {
      final start = await widget.pay();
      if (start.isDone) {
        _settle(_Outcome.sent);
      } else if (start.movementId != null) {
        _watch(start.movementId!);
      } else {
        _settle(_Outcome.pending);
      }
    } on ArkMovePendingException {
      _settle(_Outcome.pending);
    } catch (error) {
      Logger.error('ArkPaymentScreen: payment failed: $error');
      if (_outcome != _Outcome.sending || !mounted) return; // already shown as pending
      _pendingTimer?.cancel();
      _lottie.stop();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder:
            (dialogContext) => CoconutPopup(
              languageCode: context.read<PreferenceProvider>().language,
              title: t.ark.send.send_failed,
              description: '$error',
              rightButtonText: t.confirm,
              onTapRight: () => Navigator.pop(dialogContext),
            ),
      );
      if (mounted) Navigator.pop(context);
    }
  }

  /// A payment in flight is sent once its movement succeeds (the sync claims it).
  void _watch(int movementId) {
    _watchedMovementId = movementId;
    _arkProvider.cacheRevision.addListener(_onArkChanged);
    _onArkChanged();
  }

  void _onArkChanged() {
    final id = _watchedMovementId;
    if (id == null) return;
    final movement = _arkProvider.snapshot(widget.walletId)?.movements.where((m) => m.id == id).firstOrNull;
    if (movement?.status == ArkMovementStatus.successful) _settle(_Outcome.sent);
  }

  void _settle(_Outcome outcome) {
    if (_outcome != _Outcome.sending || !mounted) return;
    _pendingTimer?.cancel();
    _arkProvider.cacheRevision.removeListener(_onArkChanged);
    setState(() => _outcome = outcome);
    if (outcome == _Outcome.sent) vibrateLight();
  }

  /// The broadcast screen's check: swinging while the request runs, completing once it's sent.
  Future<void> _spin() async {
    const pivot = 22 / 60;
    const half = Duration(milliseconds: 733);
    _lottie.value = 0;
    while (_outcome == _Outcome.sending && mounted) {
      await _lottie.animateTo(pivot, duration: half, curve: Curves.easeInOut);
      if (_outcome != _Outcome.sending || !mounted) break;
      await _lottie.animateBack(0, duration: half, curve: Curves.easeInOut);
    }
    if (!mounted) return;
    if (_outcome == _Outcome.sent) {
      await _lottie.animateTo(1, duration: Duration(milliseconds: ((1 - _lottie.value) * 2000).round()));
    }
    if (mounted) setState(() => _isFinished = true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final height = MediaQuery.sizeOf(context).height;
    final title = switch (_outcome) {
      _Outcome.sending => t.broadcasting_screen.requesting,
      _Outcome.sent => t.broadcasting_complete_screen.complete,
      _Outcome.pending => t.ark.send.pending_title,
    };
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    SizedBox(height: height * 0.3),
                    SizedBox(
                      width: 70,
                      height: 70,
                      child:
                          _outcome == _Outcome.pending
                              ? const PendingTransactionLottieIcon(
                                isIncoming: false,
                                size: 38,
                                padding: EdgeInsets.all(16),
                                fit: BoxFit.contain,
                              )
                              : Lottie.asset(
                                TransactionLottiePath.checkSpinning,
                                controller: _lottie,
                                width: 70,
                                height: 70,
                                repeat: false,
                                onLoaded: (composition) {
                                  _lottie.duration = composition.duration;
                                  if (!_lottieLoaded.isCompleted) _lottieLoaded.complete();
                                },
                              ),
                    ),
                    CoconutLayout.spacing_400h,
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: Text(
                        title,
                        key: ValueKey(_outcome),
                        style: CoconutTypography.heading4_18_Bold.setColor(colors.primaryText),
                      ),
                    ),
                    if (_outcome == _Outcome.pending) ...[
                      CoconutLayout.spacing_200h,
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          t.ark.send.pending_description,
                          textAlign: TextAlign.center,
                          style: CoconutTypography.body2_14.setColor(colors.secondaryText),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_outcome == _Outcome.pending || (_outcome == _Outcome.sent && _isFinished))
                FixedBottomButton(
                  showSurroundings: false,
                  isVisibleAboveKeyboard: false,
                  onButtonClicked: () => Navigator.popUntil(context, widget.isSendStart),
                  text: t.confirm,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
