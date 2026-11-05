/// 위젯 정의 id. 크기가 다르면 다른 위젯이므로 id 끝에 크기를 붙인다.
class HomeItemIds {
  /// 2×2 / 4×2 중 고를 수 있다
  static const hotWalletStack = 'hot_wallet_stack';
  static const watchOnlyWalletStack = 'watch_only_wallet_stack';
  static const allWalletStack = 'all_wallet_stack';
  static const bitcoinBalanceTrend = 'bitcoin_balance_trend';

  static const bitcoinBalanceByFiat = 'bitcoin_balance_by_fiat_2x2';
  static const fiatPriceTrend = 'fiat_price_trend_2x2';
  static const fiatValues = 'fiat_values_2x2';
  static const balanceByWallet = 'balance_by_wallet_4x2';
  static const recentTransactions = 'recent_transactions_4x2';
  static const transactionActivity = 'transaction_activity_4x2';
  static const savingsGoal = 'savings_goal_2x2';
  static const utxoStatus = 'utxo_status_2x2';
  static const safetyStatusSmall = 'safety_status_2x2';
  static const safetyStatusWide = 'safety_status_4x2';

  static String shortcut(String featureId) => 'shortcut:$featureId';
}
