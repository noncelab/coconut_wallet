import 'dart:io';
import 'dart:math';

import 'package:coconut_wallet/widgets/features/bip329/checkbox_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

class FileListItemCard extends StatelessWidget {
  final File file;
  final bool isSelected;
  final VoidCallback onTap;

  const FileListItemCard({super.key, required this.file, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(file.path);
    final modifiedDate = DateFormat('yy-MM-dd HH:mm').format(file.lastModifiedSync());

    return CheckboxCard(
      title: fileName,
      subtitle: [
        TextSpan(text: _formatBytes(file.lengthSync())),
        const TextSpan(text: ' • '),
        TextSpan(text: modifiedDate),
      ],
      isSelected: isSelected,
      onTap: onTap,
      showBorder: true,
    );
  }
}

String _formatBytes(int bytes, {int decimals = 1}) {
  if (bytes <= 0) return "0 B";
  if (bytes == 1) return "1 B";
  const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
  var i = (log(bytes) / log(1024)).floor();
  final size = (bytes / pow(1024, i));
  return '${size.toStringAsFixed(size > 10 || i == 0 ? 0 : decimals)}${suffixes[i]}';
}
