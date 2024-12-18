import 'package:coconut_wallet/model/data/wallet_list_item_base.dart';
import 'package:coconut_wallet/services/shared_prefs_service.dart';

abstract class WalletListItemFactory {
  Future<WalletListItemBase> create({
    required String name,
    required int colorIndex,
    required int iconIndex,
    required descriptor,
    Map<String, dynamic>? secrets,
  });

  WalletListItemBase createFromJson(Map<String, dynamic> json);

  // 다음 일련번호를 저장하고 불러오는 메서드
  static int loadNextId() {
    final nextId = SharedPrefs().getInt('nextId');
    return nextId > 0 ? nextId : 1;
  }

  static Future<void> saveNextId(int nextId) async {
    await SharedPrefs().setInt('nextId', nextId);
  }
}
