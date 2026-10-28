import 'package:coconut_wallet/model/wallet/wallet_background.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';

/// 지갑 카드를 어떤 모양으로 그릴지 담는 값. 지갑 데이터(무엇인지)와 외형(어떻게 보일지)을 나눠 둔다.
///
/// - [WalletCard]는 색·아이콘을 지갑에서 직접 읽지 않고 이 값을 따로 받는다.
/// - [colorIndex], [iconIndex]는 Realm 지갑 값을 그대로 쓴다([WalletAppearance.of]).
/// - [background]는 Realm 지갑 스키마가 아닌 별도 저장소([WalletAppearanceRepository])에 둔다.
class WalletAppearance {
  final int colorIndex;
  final int iconIndex;
  final WalletBackground? background;

  const WalletAppearance({required this.colorIndex, required this.iconIndex, this.background});

  factory WalletAppearance.of(WalletItemBase wallet, {WalletBackground? background}) =>
      WalletAppearance(colorIndex: wallet.colorIndex, iconIndex: wallet.iconIndex, background: background);

  @override
  bool operator ==(Object other) =>
      other is WalletAppearance &&
      other.colorIndex == colorIndex &&
      other.iconIndex == iconIndex &&
      other.background == background;

  @override
  int get hashCode => Object.hash(colorIndex, iconIndex, background);
}
