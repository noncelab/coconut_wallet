import 'dart:convert';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/taproot_script_path_seed_info.dart';

class WatchOnlyWallet {
  final String _name;
  final int _colorIndex;
  final int _iconIndex;
  late Descriptor _descriptor;
  int? _requiredSignatureCount;
  List<MultisigSigner>? _signers;
  late WalletImportSource _walletImportSource;
  List<String>? _keyPathSeedInfos;
  List<TaprootScriptPathSeedInfo>? _scriptPathSeedInfos;

  WatchOnlyWallet(
    this._name,
    this._colorIndex,
    this._iconIndex,
    String descriptor,
    this._requiredSignatureCount,
    this._signers,
    String walletImportSource, {
    List<String>? keyPathSeedInfos,
    List<TaprootScriptPathSeedInfo>? scriptPathSeedInfos,
  }) : _keyPathSeedInfos = keyPathSeedInfos,
       _scriptPathSeedInfos = scriptPathSeedInfos {
    _descriptor = Descriptor.parse(descriptor);
    _walletImportSource = WalletImportSourceExtension.fromStringDefaultCoconut(walletImportSource);
  }

  String get name => _name;
  int get colorIndex => _colorIndex;
  int get iconIndex => _iconIndex;
  String get descriptor => _descriptor.serialize();
  String get scriptType => _descriptor.scriptType;
  int? get requiredSignatureCount => _requiredSignatureCount;
  List<MultisigSigner>? get signers => _signers;
  WalletImportSource get walletImportSource => _walletImportSource;
  List<String>? get keyPathSeedInfos => _keyPathSeedInfos;
  List<TaprootScriptPathSeedInfo>? get scriptPathSeedInfos => _scriptPathSeedInfos;

  bool get isTaproot => _keyPathSeedInfos != null || _scriptPathSeedInfos != null;

  WalletType get walletType {
    if (_signers != null) return WalletType.multiSignature;
    if (isTaproot) return WalletType.taproot;
    return WalletType.singleSignature;
  }

  bool get isSupportedTaprootConfiguration {
    if (!isTaproot) return false;
    final keyPathCount = _descriptor.totalSigner;
    final scriptPathCount = _descriptor.miniscriptList.length;
    if (!(keyPathCount == 1 || keyPathCount == 2) || scriptPathCount != 1) return false;

    final keyPathSeedInfoCount = _keyPathSeedInfos?.length ?? 0;
    final scriptPathSeedInfoCount = _scriptPathSeedInfos?.length ?? 0;
    if (keyPathSeedInfoCount > 1 || scriptPathSeedInfoCount > 1) return false;
    if (keyPathSeedInfoCount == 0 && scriptPathSeedInfoCount == 0) return false;

    // 모든 signers의 derivation path purpose가 86'인지 검증
    for (int i = 0; i < _descriptor.totalSigner; i++) {
      if (!_hasPurpose86(_descriptor.getDerivationPath(i))) return false;
    }
    // miniscript가 InheritancePolicy로 파싱 가능하고, beneficiary purpose도 86'인지 검증
    final miniscriptRegex = RegExp(r'and_v\(v:pk\(\[(.+?)\].+?\),older\(\d+\)\)');
    try {
      final miniScript = _descriptor.miniscriptList.first;
      InheritancePolicy.fromMiniscript(miniScript);
      final match = miniscriptRegex.firstMatch(miniScript);
      if (match == null) return false;
      final keyOriginPath = match.group(1)!; // e.g. "70C4E9DE/86'/1'/0'"
      final pathSegments = keyOriginPath.split('/');
      if (pathSegments.length < 2 || (pathSegments[1] != "86'" && pathSegments[1] != "86h")) {
        return false;
      }
    } catch (e) {
      return false;
    }

    return true;
  }

  static bool _hasPurpose86(String path) {
    final segments = path.split('/');
    return segments.length >= 2 && (segments[1] == "86'" || segments[1] == "86h");
  }

  String toJson() {
    Map<String, dynamic> json = {
      'name': _name,
      'colorIndex': _colorIndex,
      'iconIndex': _iconIndex,
      'descriptor': _descriptor.serialize(),
      'requiredSignatureCount': _requiredSignatureCount,
      'signers': _signers,
      'walletImportSource': _walletImportSource.name,
    };
    if (_keyPathSeedInfos != null) {
      json['keyPathSeedInfos'] = _keyPathSeedInfos;
    }
    if (_scriptPathSeedInfos != null) {
      json['scriptPathSeedInfos'] = _scriptPathSeedInfos!.map((e) => e.toJson()).toList();
    }
    return jsonEncode(json);
  }

  factory WatchOnlyWallet.fromJson(Map<String, dynamic> json) {
    final keyPathSeedInfos =
        json.containsKey('keyPathSeedInfos')
            ? (json['keyPathSeedInfos'] as List<dynamic>).map((e) => e as String).toList()
            : null;
    final scriptPathSeedInfos =
        json.containsKey('scriptPathSeedInfos')
            ? (json['scriptPathSeedInfos'] as List<dynamic>)
                .map((e) => TaprootScriptPathSeedInfo.fromJson(e as Map<String, dynamic>))
                .toList()
            : null;

    return WatchOnlyWallet(
      json['name'],
      json['colorIndex'] ?? 0,
      json['iconIndex'] ?? 0,
      json['descriptor'],
      json['requiredSignatureCount'] ?? 0,
      json['signers'] != null
          ? (json['signers'] as List<dynamic>).map((e) => MultisigSigner.fromJson(e as Map<String, dynamic>)).toList()
          : null,
      json['walletImportSource'] ?? WalletImportSource.coconutVault.name,
      keyPathSeedInfos: keyPathSeedInfos,
      scriptPathSeedInfos: scriptPathSeedInfos,
    );
  }
}
