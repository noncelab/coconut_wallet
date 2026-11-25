import 'dart:async';

import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_movement_labels.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// 앱 어느 화면에 있든 아크로 받은 금액을 토스트로 알림
class ArkReceivedToast extends StatefulWidget {
  const ArkReceivedToast({super.key, required this.child});

  final Widget child;

  @override
  State<ArkReceivedToast> createState() => _ArkReceivedToastState();
}

class _ArkReceivedToastState extends State<ArkReceivedToast> {
  StreamSubscription<ArkMovement>? _received;

  @override
  void initState() {
    super.initState();
    _received = context.read<ArkWalletProvider>().received.listen((movement) {
      if (!mounted) return;
      final wallet = context.read<ArkWalletProvider>();
      if (wallet.isInvoiceOnScreen(movement.paymentHash)) return;
      final amount = wallet.unit.displayBitcoinAmount(movement.effectiveBalanceSats, withUnit: true);
      CoconutToast.showToast(
        context: context,
        text:
            movement.kind == ArkMovementKind.board
                ? t.ark_wallet.filled(amount: amount)
                : t.ark_wallet.received(amount: amount),
        isVisibleIcon: true,
        iconPath: _iconFor(movement),
      );
    });
  }

  /// 받은 경로 아이콘. 라이트닝은 번개, 아크는 배, 온체인은 비트코인
  static String _iconFor(ArkMovement movement) => switch (arkMovementRail(movement)) {
    ArkActivityRail.lightning => FeatureArkIconPath.txLightningReceived,
    ArkActivityRail.onchain => FeatureWalletIconPath.bitcoin,
    _ => FeatureArkIconPath.boat,
  };

  @override
  void dispose() {
    _received?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
