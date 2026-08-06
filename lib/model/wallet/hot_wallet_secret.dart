import 'dart:convert';

class EncryptedValue {
  const EncryptedValue({
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  final String nonce;
  final String cipherText;
  final String mac;

  factory EncryptedValue.fromJson(Map<String, dynamic> json) => EncryptedValue(
    nonce: json['nonce'] as String,
    cipherText: json['cipherText'] as String,
    mac: json['mac'] as String,
  );

  Map<String, dynamic> toJson() => {
    'nonce': nonce,
    'cipherText': cipherText,
    'mac': mac,
  };
}

enum DeviceKeyProtection {
  androidStrongBox,
  androidTee,
  iosSecureEnclave,
  secureStorage;

  factory DeviceKeyProtection.fromName(
    String name,
  ) => DeviceKeyProtection.values.firstWhere(
    (value) => value.name == name,
    orElse:
        () => throw const FormatException('Unsupported device key protection'),
  );
}

class DeviceWrappedDek {
  const DeviceWrappedDek({
    required this.protection,
    required this.encryptedDek,
    this.alias,
  });

  final DeviceKeyProtection protection;

  /// StrongBox/TEE/Secure Enclave 키를 찾는 식별자다.
  /// SecureStorage fallback에서는 별도 저장 키가 alias 역할을 한다.
  final String? alias;

  /// 하드웨어 키 경로는 네이티브 암호문만 사용하므로 nonce/mac이 비어 있다.
  /// SecureStorage fallback은 AES-256-GCM 값 전체를 사용한다.
  final EncryptedValue encryptedDek;

  factory DeviceWrappedDek.fromJson(Map<String, dynamic> json) =>
      DeviceWrappedDek(
        protection: DeviceKeyProtection.fromName(json['protection'] as String),
        alias: json['alias'] as String?,
        encryptedDek: EncryptedValue.fromJson(
          json['encryptedDek'] as Map<String, dynamic>,
        ),
      );

  Map<String, dynamic> toJson() => {
    'protection': protection.name,
    'alias': alias,
    'encryptedDek': encryptedDek.toJson(),
  };
}

class HotWalletSecret {
  const HotWalletSecret({
    required this.version,
    required this.encryptedPayload,
    required this.deviceWrappedDek,
  });

  static const int currentVersion = 1;

  final int version;
  final EncryptedValue encryptedPayload;
  final DeviceWrappedDek deviceWrappedDek;

  factory HotWalletSecret.decode(String encoded) {
    final json = jsonDecode(encoded) as Map<String, dynamic>;
    final version = json['version'] as int;
    if (version != currentVersion) {
      throw const FormatException('Unsupported hot wallet secret version');
    }
    return HotWalletSecret(
      version: version,
      encryptedPayload: EncryptedValue.fromJson(
        json['encryptedPayload'] as Map<String, dynamic>,
      ),
      deviceWrappedDek: DeviceWrappedDek.fromJson(
        json['deviceWrappedDek'] as Map<String, dynamic>,
      ),
    );
  }

  String encode() => jsonEncode({
    'version': version,
    'encryptedPayload': encryptedPayload.toJson(),
    'deviceWrappedDek': deviceWrappedDek.toJson(),
  });
}

class HotWalletPlaintext {
  const HotWalletPlaintext({required this.mnemonic, required this.passphrase});

  final String mnemonic;
  final String passphrase;
}
