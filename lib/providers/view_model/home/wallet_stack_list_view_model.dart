import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/home/wallet_widget_definitions.dart';
import 'package:flutter/foundation.dart';

/// 지갑 목록 휠 화면
/// 가짜 잔액은 홈에만 쓰므로 여기서는 실제 잔액을 보여 준다
class WalletStackListViewModel extends ChangeNotifier {
  final WalletStackKind kind;
  final WalletProvider _walletProvider;
  final PreferenceProvider _preferenceProvider;

  WalletStackListViewModel(this.kind, this._walletProvider, this._preferenceProvider) {
    _walletProvider.addListener(notifyListeners);
    _preferenceProvider.addListener(notifyListeners);
  }

  List<WalletItemBase> get wallets =>
      orderStackWallets(_walletProvider.walletItemList, _preferenceProvider.walletOrder, kind: kind);

  /// 보기 전용·핫월렛 목록은 이미 한 종류만 있으므로 종류를 보여 주지 않는다.
  int indexOf(int? walletId) {
    final index = wallets.indexWhere((wallet) => wallet.id == walletId);
    return index < 0 ? 0 : index;
  }

  String balanceText(WalletItemBase wallet) => _preferenceProvider.currentUnit.displayBitcoinAmount(
    _walletProvider.getWalletBalance(wallet.id).total,
    withUnit: true,
  );

  int utxoCount(WalletItemBase wallet) => _walletProvider.getUtxoList(wallet.id).length;

  DateTime? lastTransactionTime(WalletItemBase wallet) {
    final transactions = _walletProvider.getTransactionRecordList(wallet.id);
    if (transactions.isEmpty) return null;
    return transactions.map((tx) => tx.timestamp).reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// 모든 지갑: 보관 방식과 서명 방식을 함께, 보기 전용: 서명 방식만. 핫월렛은 모두 단일 서명이라 보여 주지 않는다.
  String? typeLabel(WalletItemBase wallet) {
    final signature = switch (wallet.walletType) {
      WalletType.singleSignature => t.wallet_stack_list.single_sig,
      WalletType.multiSignature => t.wallet_stack_list.multisig,
      WalletType.taproot => t.wallet_stack_list.inheritance,
    };
    final custody =
        wallet.hasLocalKey ? t.wallet_home_screen.wallet_filter.hot : t.wallet_home_screen.wallet_filter.watch_only;
    return switch (kind) {
      WalletStackKind.all => '$custody • $signature',
      WalletStackKind.watchOnly => signature,
      WalletStackKind.hot => null,
    };
  }

  @override
  void dispose() {
    _walletProvider.removeListener(notifyListeners);
    _preferenceProvider.removeListener(notifyListeners);
    super.dispose();
  }
}
