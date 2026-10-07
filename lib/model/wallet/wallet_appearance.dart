import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';

/// 지갑 카드를 어떤 모양으로 그릴지 담는 값. 지갑 데이터(무엇인지)와 외형(어떻게 보일지)을 나눠 둔다.
///
/// - [WalletCard]는 색·아이콘을 지갑에서 직접 읽지 않고 이 값을 따로 받는다.
/// - 지금은 기존 지갑의 [colorIndex], [iconIndex]만 담는다([WalletAppearance.of]).
/// - 지갑 꾸미기(Epic 2)에서 배경·강조색·카드 스타일 같은 값을 여기에 더한다. 카드를 쓰는 쪽은 바꾸지 않아도 된다.
/// - 꾸미기 값은 Realm 지갑 스키마가 아닌 별도 저장소에 둔다.
class WalletAppearance {
  final int colorIndex;
  final int iconIndex;

  const WalletAppearance({required this.colorIndex, required this.iconIndex});

  factory WalletAppearance.of(WalletItemBase wallet) =>
      WalletAppearance(colorIndex: wallet.colorIndex, iconIndex: wallet.iconIndex);

  @override
  bool operator ==(Object other) =>
      other is WalletAppearance && other.colorIndex == colorIndex && other.iconIndex == iconIndex;

  @override
  int get hashCode => Object.hash(colorIndex, iconIndex);
}
