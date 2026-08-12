import 'dart:io';
import 'dart:math';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? context.coconutColors.primaryText : context.coconutColors.border,
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SvgPicture.asset(
              isSelected ? 'assets/svg/square_check.svg' : 'assets/svg/square.svg',
              width: 24,
              colorFilter: ColorFilter.mode(
                isSelected ? context.coconutColors.iconDefault : context.coconutColors.iconSubDefault,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fileName, style: CoconutTypography.body1_16, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
                      children: [
                        TextSpan(text: _formatBytes(file.lengthSync())),
                        const TextSpan(text: ' • '),
                        TextSpan(text: modifiedDate),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatBytes(int bytes, {int decimals = 1}) {
  if (bytes <= 0) return "0 B";
  if (bytes == 1) return "1 B";
  const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
  var i = (log(bytes) / log(1024)).floor();
  final size = (bytes / pow(1024, i));
  return '${size.toStringAsFixed(size > 10 || i == 0 ? 0 : decimals)} ${suffixes[i]}';
}
