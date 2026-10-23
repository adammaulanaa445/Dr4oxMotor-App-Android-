import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Memastikan aplikasi benar-benar bisa dipakai tanpa internet.
///
/// Cara kerjanya: pemeriksaan statis (tidak ada dependensi/izin jaringan)
/// ditambah pengujian otomatis yang berjalan tanpa akses jaringan sama
/// sekali (seluruh test memakai database lokal in-memory / berkas lokal).
void main() {
  group('Audit offline', () {
    test('tidak ada dependensi jaringan di pubspec', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final dependencies = pubspec
          .split('dependencies:')[1]
          .split('dev_dependencies:')[0]
          .toLowerCase();

      const forbidden = [
        'http',
        'dio',
        'chopper',
        'retrofit',
        'socket_io',
        'websocket',
        'firebase',
        'supabase',
        'graphql',
        'sembast',
        'realm',
        'cloud_firestore',
      ];
      for (final package in forbidden) {
        expect(
          dependencies.contains(package),
          isFalse,
          reason: 'dependensi jaringan "$package" tidak boleh dipakai',
        );
      }
    });

    test('tidak ada izin jaringan di AndroidManifest', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest.contains('android.permission.INTERNET'), isFalse);
      expect(manifest.contains('android.permission.ACCESS_NETWORK_STATE'),
          isFalse);
    });

    test('kode aplikasi tidak mengimpor pustaka jaringan', () {
      final libFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in libFiles) {
        final content = file.readAsStringSync();
        expect(
          content.contains("package:http/"),
          isFalse,
          reason: '${file.path} tidak boleh memakai http',
        );
        expect(
          content.contains("package:dio/"),
          isFalse,
          reason: '${file.path} tidak boleh memakai dio',
        );
        expect(
          content.contains('HttpClient('),
          isFalse,
          reason: '${file.path} tidak boleh memakai HttpClient',
        );
        expect(
          content.contains('Socket.connect'),
          isFalse,
          reason: '${file.path} tidak boleh memakai Socket',
        );
      }
    });

    test('penyimpanan data memakai berkas lokal, bukan layanan online', () {
      final dbSource =
          File('lib/data/local/app_database.dart').readAsStringSync();
      // Database memakai sqflite (SQLite lokal di perangkat).
      expect(dbSource.contains('getDatabasesPath'), isTrue);
      expect(dbSource.contains('openDatabase'), isTrue);
      expect(dbSource.contains('http'), isFalse);
    });
  });
}
