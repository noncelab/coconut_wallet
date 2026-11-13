import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 동기화가 내 코인을 쓰는데 서명이 맞지 않는 미확정 거래를 넣지 않았을 때, 그 거래마다 한 번만 알린다.
/// 서버는 같은 거래를 동기화마다 다시 보내므로 알린 거래 번호를 기억해 둔다(거래 번호만 저장)
class UnverifiedTransactionListener extends StatefulWidget {
  const UnverifiedTransactionListener({super.key, required this.navigatorKey, required this.child});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<UnverifiedTransactionListener> createState() => _UnverifiedTransactionListenerState();
}

class _UnverifiedTransactionListenerState extends State<UnverifiedTransactionListener> {
  StreamSubscription<List<String>>? _subscription;
  final Set<String> _shown = {};
  bool _isShowing = false;

  @override
  void initState() {
    super.initState();
    _shown.addAll(SharedPrefsRepository().getShownUnverifiedTransactionIds());
    _subscription = context.read<NodeProvider>().unverifiedPendingTransactionStream.listen(_onDropped);
  }

  void _onDropped(List<String> txHashes) {
    final fresh = txHashes.where(_shown.add).toList();
    if (fresh.isEmpty) return;
    SharedPrefsRepository().addShownUnverifiedTransactionIds(fresh);
    final navigatorContext = widget.navigatorKey.currentContext;
    if (_isShowing || navigatorContext == null) return;
    _isShowing = true;
    showDialog<void>(
      context: navigatorContext,
      builder:
          (dialogContext) => CoconutPopup(
            languageCode: context.read<PreferenceProvider>().language,
            title: t.unverified_transaction_dialog.title,
            description: t.unverified_transaction_dialog.description,
            leftButtonText: t.close,
            rightButtonText: t.unverified_transaction_dialog.change_server,
            onTapLeft: () => Navigator.of(dialogContext).pop(),
            onTapRight: () {
              Navigator.of(dialogContext).pop();
              widget.navigatorKey.currentState?.pushNamed(AppRouteNames.electrumServer);
            },
          ),
    ).whenComplete(() => _isShowing = false);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
