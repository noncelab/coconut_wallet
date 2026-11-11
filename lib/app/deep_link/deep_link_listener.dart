import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'dart:async';

import 'package:coconut_wallet/app/bootstrap/platform_channels.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/home/goal_amount_screen.dart';
import 'package:coconut_wallet/services/goal_reminder/goal_reminder.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class DeepLinkListener extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  const DeepLinkListener({super.key, required this.navigatorKey, required this.child});

  /// 모으기 알림을 눌렀을 때 여는 화면. 테스트에서 바꿔 끼운다.
  @visibleForTesting
  static Future<void> Function(NavigatorState navigator, BuildContext context) openGoalAmount =
      GoalAmountScreen.openFromReminder;

  @override
  State<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends State<DeepLinkListener> {
  static const MethodChannel _osChannel = MethodChannel(methodChannelOS);
  static const Duration _duplicateUriWindow = Duration(seconds: 2);

  late final AppLifecycleListener _appLifecycleListener;
  StreamSubscription<void>? _reminderTaps;
  bool _isHandlingBitcoinUri = false;
  String? _recentBitcoinUri;
  DateTime? _recentBitcoinUriHandledAt;

  @override
  void initState() {
    super.initState();
    _osChannel.setMethodCallHandler((call) async {
      if (call.method == 'onBitcoinUri' && call.arguments is String) {
        await _handleBitcoinUri(call.arguments as String);
      }
    });

    _appLifecycleListener = AppLifecycleListener(onResume: _consumePendingBitcoinUri);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumePendingBitcoinUri();
      _listenGoalReminderTaps();
    });
  }

  /// 모으기 알림을 누르면 목표 수량 화면을 연다.
  /// 이 위젯은 잠금을 푼 뒤(메인 흐름)에 만들어지므로, 알림으로 앱을 켰으면 잠금을 푼 다음에 연다.
  Future<void> _listenGoalReminderTaps() async {
    final scheduler = GoalReminderScheduler.instance;
    _reminderTaps = scheduler.taps.listen((_) => _openGoalAmount());
    try {
      if (await scheduler.consumeLaunchTap()) _openGoalAmount();
    } catch (error) {
      Logger.error('Failed to read the notification that launched the app: $error');
    }
  }

  void _openGoalAmount() {
    final navigator = widget.navigatorKey.currentState;
    if (!mounted || navigator == null) return;
    unawaited(DeepLinkListener.openGoalAmount(navigator, context));
  }

  Future<void> _consumePendingBitcoinUri() async {
    if (!mounted || _isHandlingBitcoinUri) return;

    final bitcoinUri = await _osChannel.invokeMethod<String>('getPendingBitcoinUri');
    if (!mounted || bitcoinUri == null || bitcoinUri.isEmpty) return;
    await _handleBitcoinUri(bitcoinUri);
  }

  Future<void> _handleBitcoinUri(String bitcoinUri) async {
    if (!mounted || _isHandlingBitcoinUri || bitcoinUri.isEmpty) return;
    if (_recentBitcoinUri == bitcoinUri &&
        _recentBitcoinUriHandledAt != null &&
        DateTime.now().difference(_recentBitcoinUriHandledAt!) < _duplicateUriWindow) {
      return;
    }

    final walletProvider = context.read<WalletProvider>();
    final walletOrder = context.read<PreferenceProvider>().walletOrder;
    final firstWallet = walletProvider.walletItemList.isEmpty ? null : walletProvider.walletItemList.first;
    final targetId =
        firstWallet == null ? null : walletOrder.firstWhere((id) => id == firstWallet.id, orElse: () => firstWallet.id);

    _isHandlingBitcoinUri = true;
    _recentBitcoinUri = bitcoinUri;
    _recentBitcoinUriHandledAt = DateTime.now();
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) {
      _isHandlingBitcoinUri = false;
      return;
    }

    unawaited(
      navigator.pushNamed(
        AppRouteNames.send,
        arguments: SendRouteArgs(id: targetId, sendEntryPoint: SendEntryPoint.home, initialBitcoinUri: bitcoinUri),
      ),
    );

    Future<void>.delayed(const Duration(milliseconds: 300)).then((_) {
      if (mounted) {
        _isHandlingBitcoinUri = false;
      }
    });
  }

  @override
  void dispose() {
    _osChannel.setMethodCallHandler(null);
    _appLifecycleListener.dispose();
    _reminderTaps?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
