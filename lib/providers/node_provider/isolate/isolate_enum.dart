enum IsolateHandlerMessage {
  subscribeWallets,
  subscribeWallet,
  unsubscribeWallet,
  broadcast,
  getNetworkMinimumFeeRate,
  getLatestBlock,
  getTransaction,
  getRecommendedFees,
}

enum IsolateStateMethod {
  initWalletUpdateStatus,
  addWalletSyncState,
  addWalletCompletedState,
  addWalletCompletedAllStates,
  setState,
}

enum IsolateManagerMessage {
  initialize,
  updateState,
}
