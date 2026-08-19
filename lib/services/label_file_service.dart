import 'dart:io';
import 'dart:ui';

import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class LabelFileService {
  const LabelFileService();

  /// Returns list of `.jsonl` files in the application documents directory, sorted newest first.
  Future<List<File>> getImportableLabelFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files =
          directory.listSync().whereType<File>().where((file) {
            return file.path.toLowerCase().endsWith('.jsonl');
          }).toList();

      // Sort by modification date, newest first
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      return files;
    } catch (e) {
      debugPrint('Error getting importable label files: $e');
      return [];
    }
  }

  /// Saves content string to a `.jsonl` file in documents directory with unique name if collision occurs.
  Future<XFile> saveLabelFile(
    String content, {
    String baseName = 'coconut-labels',
    bool useTimestampOrCounter = true,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    const extension = '.jsonl';
    String fileName = '$baseName$extension';
    String filePath = p.join(directory.path, fileName);
    int counter = 1;

    while (await File(filePath).exists()) {
      fileName = '$baseName($counter)$extension';
      filePath = p.join(directory.path, fileName);
      counter++;
    }

    final file = File(filePath);
    await file.writeAsString(content);

    return XFile(file.path, name: fileName, mimeType: 'application/jsonl');
  }

  /// Prompts user to pick a `.jsonl` file and copies it to the app documents directory.
  Future<File?> pickAndSaveExternalLabelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);

      if (result == null || result.files.isEmpty || result.files.single.path == null) {
        return null;
      }

      final pickedFile = result.files.single;
      final filePath = pickedFile.path!;
      final fileName = pickedFile.name;

      if (!fileName.toLowerCase().endsWith('.jsonl') && !filePath.toLowerCase().endsWith('.jsonl')) {
        throw ErrorCodes.withMessage(ErrorCodes.storageReadError, 'Invalid file type');
      }

      final sourceFile = File(filePath);
      if (!await sourceFile.exists()) {
        return null;
      }

      final directory = await getApplicationDocumentsDirectory();
      final baseName = p.basenameWithoutExtension(fileName);
      const extension = '.jsonl';
      String targetFileName = '$baseName$extension';
      String targetPath = p.join(directory.path, targetFileName);
      int counter = 1;

      while (await File(targetPath).exists()) {
        targetFileName = '$baseName($counter)$extension';
        targetPath = p.join(directory.path, targetFileName);
        counter++;
      }

      return await sourceFile.copy(targetPath);
    } catch (e) {
      debugPrint('Error picking or saving external label file: $e');
      rethrow;
    }
  }

  /// Shares files with system share sheet while disabling privacy screen temporarily.
  Future<void> shareFiles(List<XFile> xFiles, {Rect? sharePositionOrigin}) async {
    if (xFiles.isEmpty) return;
    AppGuard.disablePrivacyScreen();
    try {
      await Share.shareXFiles(xFiles, text: 'Coconut Wallet Labels', sharePositionOrigin: sharePositionOrigin);
    } finally {
      AppGuard.enablePrivacyScreen();
    }
  }

  /// Shares single file.
  Future<void> shareFile(XFile xFile, {Rect? sharePositionOrigin}) async {
    await shareFiles([xFile], sharePositionOrigin: sharePositionOrigin);
  }

  /// Converts File to XFile with jsonl mime type.
  XFile createXFileFromFile(File file) {
    return XFile(file.path, name: p.basename(file.path), mimeType: 'application/jsonl');
  }

  /// Deletes a file.
  Future<void> deleteFile(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Deletes multiple files.
  Future<void> deleteFiles(List<File> files) async {
    for (final file in files) {
      await deleteFile(file);
    }
  }

  /// Reads lines from file path.
  Future<List<String>> readFileLines(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw ErrorCodes.withMessage(ErrorCodes.storageReadError, 'File not found: $filePath');
    }
    return await file.readAsLines();
  }
}
