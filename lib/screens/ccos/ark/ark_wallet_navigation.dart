import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_activity_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_movement_detail_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_receive_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_send_screen.dart';
import 'package:flutter/widgets.dart';

/// 아크 지갑 홈에서 여는 화면들
class ArkWalletNavigation {
  const ArkWalletNavigation(this.context);

  final BuildContext context;

  void openReceive() => ArkReceiveScreen.open(context);

  void openSend() => ArkSendScreen.open(context);

  void openActivity() => ArkActivityScreen.open(context);

  void openMovement(ArkMovement movement) => ArkMovementDetailScreen.open(context, movement);
}
