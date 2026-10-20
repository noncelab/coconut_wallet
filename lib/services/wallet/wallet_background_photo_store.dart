import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:coconut_wallet/model/wallet/wallet_background.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 지갑 카드 배경 사진 파일을 앱 문서 폴더의 `wallet_backgrounds/`에 둔다.
///
/// 카드는 동기로 그려야 하므로 [init]에서 폴더 경로를 한 번 구해 두고, 이후 [fileOf]는 동기로 경로를 만든다.
class WalletBackgroundPhotoStore {
  static const String directoryName = 'wallet_backgrounds';

  final Future<Directory> Function() _baseDirectory;
  Directory? _directory;

  WalletBackgroundPhotoStore({Future<Directory> Function()? baseDirectory})
    : _baseDirectory = baseDirectory ?? getApplicationDocumentsDirectory;

  bool get isReady => _directory != null;

  Future<Directory> init() async {
    final existing = _directory;
    if (existing != null) return existing;
    final directory = Directory(p.join((await _baseDirectory()).path, directoryName));
    if (!await directory.exists()) await directory.create(recursive: true);
    return _directory = directory;
  }

  File? fileOf(String fileName) {
    final directory = _directory;
    return directory == null ? null : File(p.join(directory.path, fileName));
  }

  /// 사진을 저장하고 가운데 맞춤 배경 값을 돌려준다. 아직 지갑에 적용하지는 않는다.
  Future<WalletPhotoBackground> save(int walletId, Uint8List bytes, {String extension = 'jpg'}) async {
    final aspectRatio = await _aspectRatioOf(bytes);
    final directory = await init();
    final fileName = 'wallet_${walletId}_${DateTime.now().microsecondsSinceEpoch}.$extension';
    await File(p.join(directory.path, fileName)).writeAsBytes(bytes, flush: true);
    return WalletPhotoBackground(fileName: fileName, aspectRatio: aspectRatio);
  }

  Future<void> delete(String fileName) async {
    final file = fileOf(fileName) ?? File(p.join((await init()).path, fileName));
    try {
      if (await file.exists()) await file.delete();
    } catch (e) {
      Logger.error('[WalletBackgroundPhotoStore] delete failed: $e');
    }
  }

  /// [keep]에 없는 사진을 지운다. 저장 도중 앱이 꺼지거나 편집을 취소해 남은 파일을 정리한다.
  Future<void> deleteAllExcept(Set<String> keep) async {
    final directory = await init();
    try {
      await for (final entity in directory.list()) {
        if (entity is File && !keep.contains(p.basename(entity.path))) await entity.delete();
      }
    } catch (e) {
      Logger.error('[WalletBackgroundPhotoStore] cleanup failed: $e');
    }
  }

  Future<void> deleteAll() => deleteAllExcept(const {});

  static Future<double> _aspectRatioOf(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      if (descriptor.width <= 0 || descriptor.height <= 0) throw const FormatException('empty image');
      return descriptor.width / descriptor.height;
    } finally {
      descriptor.dispose();
      buffer.dispose();
    }
  }
}
