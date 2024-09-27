import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

Future<Directory> getAppDocumentDirectory({List<String>? paths}) async {
  Directory appDocDir = await getApplicationDocumentsDirectory();
  if (paths == null) {
    return appDocDir;
  }

  for (final String dir in paths) {
    appDocDir.createSync();
    appDocDir = Directory(p.join(appDocDir.path, dir));
  }
  return appDocDir;
}
