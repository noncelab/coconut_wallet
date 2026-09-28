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
  syncDormantAddresses,
  syncViewedAddresses,
  resyncWallet,
  shutdown,
}

enum IsolateStateMethod {
  initWalletUpdateStatus,
  addWalletSyncState,
  addWalletCompletedState,
  addWalletCompletedAllStates,
  setNodeSyncStateToSyncing,
  setNodeSyncStateToCompleted,
  setNodeSyncStateToFailed,
  setWalletResyncPhase,
  setWalletResyncFetchProgress,
  addWalletFetchDispatched,
  addWalletFetchCompleted,
  notifyReceiveDepositDetected,
  notifyReceiveWalletSynced,
}

enum IsolateManagerCommand { initializationCompleted, initializationFailed, updateState }
