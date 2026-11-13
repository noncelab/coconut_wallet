import 'package:coconut_lib/coconut_lib.dart' show NetworkType;
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'dart:async';

import 'package:coconut_wallet/app/bootstrap/platform_channels.dart';
import 'package:coconut_wallet/providers/ark_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/payment_request_parser.dart';
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

    final targetId = _targetWalletId(bitcoinUri);

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

  /// 사용자 지갑 순서의 첫 지갑. 아크·라이트닝이 담긴 링크면 아크를 켠 첫 지갑
  int? _targetWalletId(String bitcoinUri) {
    final walletProvider = context.read<WalletProvider>();
    final walletOrder = context.read<PreferenceProvider>().walletOrder;
    final wallets = [
      for (final id in walletOrder) ...walletProvider.walletItemList.where((wallet) => wallet.id == id),
      ...walletProvider.walletItemList.where((wallet) => !walletOrder.contains(wallet.id)),
    ];
    final arkProvider = context.readArkProviderOrNull();
    if (arkProvider != null && PaymentRequest.parse(bitcoinUri, NetworkType.currentNetworkType).hasArkOrLightning) {
      final arkWallet = wallets.where(arkProvider.supportsArk).firstOrNull;
      if (arkWallet != null) return arkWallet.id;
    }
    return wallets.firstOrNull?.id;
  }

  @override
  void dispose() {
    _osChannel.setMethodCallHandler(null);
    _appLifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
