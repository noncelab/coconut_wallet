enum IsolateControllerCommand {
  subscribeWallets,
  subscribeWallet,
  unsubscribeWallet,
  broadcast,
  getNetworkMinimumFeeRate,
  getLatestBlock,
  getTransaction,
  getRecommendedFees,
  getSocketConnectionStatus,
  getTransactionRecord,
}

enum IsolateStateMethod {
  initWalletUpdateStatus,
  addWalletSyncState,
  addWalletCompletedState,
  addWalletCompletedAllStates,
  setNodeSyncStateToSyncing,
  setNodeSyncStateToCompleted,
  setNodeSyncStateToFailed,
}

enum IsolateManagerCommand {
  initializationCompleted,
  initializationFailed,
  updateState,
}
