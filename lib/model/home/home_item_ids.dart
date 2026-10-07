class HomeItemIds {
  static const hotWalletStack = 'hot_wallet_stack';
  static const watchOnlyWalletStack = 'watch_only_wallet_stack';
  static const bitcoinBalanceTrend = 'bitcoin_balance_trend';
  static const fiatValues = 'fiat_values';
  static const balanceByWallet = 'balance_by_wallet';
  static const last24Hours = 'last_24_hours';
  static const transactionActivity = 'transaction_activity';
  static const savingsGoal = 'savings_goal';
  static const utxoStatus = 'utxo_status';
  static const safetyStatus = 'safety_status';

  static String shortcut(String featureId) => 'shortcut:$featureId';
}
