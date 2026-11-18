import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';

enum ArkSeedSource { created, restored }

class ArkWalletInfo {
  const ArkWalletInfo({
    required this.secretStorageKey,
    required this.fingerprint,
    required this.source,
    required this.backupVerified,
    required this.createdAt,
  });

  final String secretStorageKey;
  final String fingerprint;
  final ArkSeedSource source;
  final bool backupVerified;
  final DateTime createdAt;

  ArkWalletInfo copyWith({bool? backupVerified}) => ArkWalletInfo(
    secretStorageKey: secretStorageKey,
    fingerprint: fingerprint,
    source: source,
    backupVerified: backupVerified ?? this.backupVerified,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'secretStorageKey': secretStorageKey,
    'fingerprint': fingerprint,
    'source': source.name,
    'backupVerified': backupVerified,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ArkWalletInfo.fromJson(Map<String, dynamic> json) => ArkWalletInfo(
    secretStorageKey: json['secretStorageKey'] as String,
    fingerprint: json['fingerprint'] as String,
    source: ArkSeedSource.values.byName(json['source'] as String),
    backupVerified: json['backupVerified'] as bool,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

/// 아크 지갑 시드는 핫월렛과 같은 암호화 저장소에, 정보는 SharedPreferences에 둠
class ArkWalletStore {
  ArkWalletStore(this._prefs, this._secrets);

  final SharedPrefsRepository _prefs;
  final HotWalletSecretRepository _secrets;

  ArkWalletInfo? read() {
    final encoded = _prefs.getStringOrNull(SharedPrefKeys.kArkWallet);
    if (encoded == null || encoded.isEmpty) return null;
    return ArkWalletInfo.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
  }

  Future<ArkWalletInfo> save({
    required Uint8List mnemonic,
    required String fingerprint,
    required ArkSeedSource source,
  }) async {
    final storageKey = _secrets.newSecretStorageKey();
    await _secrets.create(storageKey: storageKey, mnemonic: mnemonic, passphrase: Uint8List(0));
    final info = ArkWalletInfo(
      secretStorageKey: storageKey,
      fingerprint: fingerprint,
      source: source,
      backupVerified: source != ArkSeedSource.created,
      createdAt: DateTime.now(),
    );
    await _write(info);
    return info;
  }

  Future<Uint8List> readMnemonic(ArkWalletInfo info) async {
    final plaintext = await _secrets.unlockAfterAuthentication(info.secretStorageKey);
    plaintext.passphrase.fillRange(0, plaintext.passphrase.length, 0);
    return plaintext.mnemonic;
  }

  Future<void> markBackupVerified() async {
    final info = read();
    if (info == null) return;
    await _write(info.copyWith(backupVerified: true));
  }

  /// 정보와 이 저장소의 시드를 모두 지움. 정보 없이 남은 시드도 함께
  Future<void> clear() async {
    for (final key in await _secrets.getSecretStorageKeys()) {
      await _secrets.delete(key);
    }
    await _prefs.deleteSharedPrefsWithKey(SharedPrefKeys.kArkWallet);
  }

  Future<void> _write(ArkWalletInfo info) => _prefs.setStringAndConfirm(SharedPrefKeys.kArkWallet, jsonEncode(info));
}
