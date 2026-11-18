import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/app/bootstrap/platform_channels.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_expiry_reminder.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_feature.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_payment_link.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_send_screen.dart';
import 'package:coconut_wallet/services/notification/local_notification_service.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class DeepLinkListener extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  const DeepLinkListener({super.key, required this.navigatorKey, required this.child});

  @override
  State<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends State<DeepLinkListener> {
  static const MethodChannel _osChannel = MethodChannel(methodChannelOS);
  static const Duration _duplicateUriWindow = Duration(seconds: 2);

  late final AppLifecycleListener _appLifecycleListener;
  StreamSubscription<String>? _notificationTaps;
  ArkWalletProvider? _arkWallet;
  bool? _lightningLinksEnabled;
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
    });

    _arkWallet = context.read<ArkWalletProvider>()..addListener(_syncLightningLinks);
    _syncLightningLinks();

    _notificationTaps = LocalNotificationService.instance.taps.listen(_onNotificationTap);
    unawaited(
      LocalNotificationService.instance.consumeLaunchPayload().then((payload) {
        if (payload != null) _onNotificationTap(payload);
      }),
    );
  }

  /// Android는 아크 지갑이 있을 때만 lightning: 링크를 받음. iOS는 스킴을 켜고 끌 수 없어 등록하지 않음
  void _syncLightningLinks() {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final enabled = _arkWallet?.hasWallet ?? false;
    if (enabled == _lightningLinksEnabled) return;
    _lightningLinksEnabled = enabled;
    _osChannel.invokeMethod<void>('setLightningLinksEnabled', enabled).catchError((Object _) {});
  }

  void _onNotificationTap(String payload) {
    if (!mounted || payload != LocalArkExpiryReminder.payload) return;
    if (!context.read<ArkWalletProvider>().hasWallet) return;
    final navigator = widget.navigatorKey.currentState;
    if (navigator != null) _openArkWallet(navigator);
  }

  /// 아크 지갑 홈이 쌓여 있으면 그 화면으로 돌아가고, 없으면 새로 염
  void _openArkWallet(NavigatorState navigator, {String? sendInput}) {
    var found = false;
    navigator.popUntil((route) {
      found = route.settings.name == AnalyticsScreenNames.ccosArkWalletHome;
      return found || route.isFirst;
    });
    if (!found) ArkFeature.openWallet(navigator.context);
    if (sendInput != null) ArkSendScreen.open(navigator.context, initialInput: sendInput);
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

    if (opensInArkWallet(
      bitcoinUri,
      NetworkType.currentNetworkType,
      hasArkWallet: context.read<ArkWalletProvider>().hasWallet,
    )) {
      final navigator = widget.navigatorKey.currentState;
      if (navigator == null) return;
      _recentBitcoinUri = bitcoinUri;
      _recentBitcoinUriHandledAt = DateTime.now();
      _openArkWallet(navigator, sendInput: bitcoinUri);
      return;
    }

    if (bitcoinUri.toLowerCase().startsWith('lightning:')) return;

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
    _notificationTaps?.cancel();
    _arkWallet?.removeListener(_syncLightningLinks);
    _appLifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
