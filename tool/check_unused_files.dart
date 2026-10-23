// Memeriksa apakah setiap file di lib/ benar-benar dipakai.
//
// File dianggap terpakai bila nama filenya muncul di import file lain.
// Jalankan: dart run tool/check_unused_files.dart
import 'dart:io';

void main() {
  final libFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  final allSources = <String, String>{};
  final searchDirs = ['lib', 'test', 'tool'];
  for (final dir in searchDirs) {
    final directory = Directory(dir);
    if (!directory.existsSync()) continue;
    for (final file in directory.listSync(recursive: true)) {
      if (file is File && file.path.endsWith('.dart')) {
        allSources[file.path] = file.readAsStringSync();
      }
    }
  }

  var unused = 0;
  for (final file in libFiles) {
    final name = file.path.split(Platform.pathSeparator).last;
    final isEntryPoint = name == 'main.dart';
    var used = false;
    for (final entry in allSources.entries) {
      if (entry.key == file.path) continue;
      if (entry.value.contains(name)) {
        used = true;
        break;
      }
    }
    if (!used && !isEntryPoint) {
      stdout.writeln('TIDAK TERPAKAI: ${file.path}');
      unused++;
    }
  }
  stdout.writeln(
    unused == 0
        ? 'OK: semua file lib/ terpakai.'
        : '$unused file belum terpakai.',
  );
}
