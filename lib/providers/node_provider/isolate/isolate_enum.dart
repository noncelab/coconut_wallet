enum IsolateHandlerMessage {
  subscribeWallets,
  subscribeWallet,
  unsubscribeWallet,
  broadcast,
  getNetworkMinimumFeeRate,
  getLatestBlock,
  getTransaction,
  getRecommendedFees,
  getSocketConnectionStatus,
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
