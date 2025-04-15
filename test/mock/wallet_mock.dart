import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';

class WalletMock {
  static SinglesigWalletListItem createSingleSigWalletItem({
    int id = 1,
    String name = 'test_wallet',
  }) {
    return SinglesigWalletListItem(
      id: id,
      name: name,
      colorIndex: 0,
      iconIndex: 0,
      descriptor:
          "wpkh([D45AA182/84'/1'/0']vpub5YtEovN9MqeUZxWqdpUKngsiaLCPFY34KpWGQVk9Tjq8G5SYcRFj9s5aCKeAQYGunG7LrFkA5obtH8kPJiv92JtWHfRvnir6PDvhd4p93Pp/<0;1>/*)#rcn2hj6y",
    );
  }
}
