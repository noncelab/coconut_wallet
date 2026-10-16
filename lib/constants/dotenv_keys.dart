class DotenvKeys {
  static const String apiHost = 'API_HOST';
  static const String networkType = 'NETWORK_TYPE';

  // Floresta 임베드 노드의 고정 피어. 피어 호스트 주소가 실행 플랫폼마다 달라 키를 분리한다.
  static const String florestaFixedPeersAndroid = 'FLORESTA_FIXED_PEERS_ANDROID';
  static const String florestaFixedPeersIos = 'FLORESTA_FIXED_PEERS_IOS';

  // Firebase
  static const String firebaseApiKeyAndroid = 'FIREBASE_API_KEY_ANDROID';
  static const String firebaseAppIdAndroid = 'FIREBASE_APP_ID_ANDROID';
  static const String firebaseMessagingSenderId = 'FIREBASE_MESSAGING_SENDER_ID';
  static const String firebaseProjectId = 'FIREBASE_PROJECT_ID';
  static const String firebaseStorageBucket = 'FIREBASE_STORAGE_BUCKET';
  static const String firebaseApiKeyIos = 'FIREBASE_API_KEY_IOS';
  static const String firebaseAppIdIos = 'FIREBASE_APP_ID_IOS';
  static const String firebaseIosBundleId = 'FIREBASE_IOS_BUNDLE_ID';
}
