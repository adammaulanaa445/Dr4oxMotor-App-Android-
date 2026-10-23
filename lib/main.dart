import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/app_dependencies.dart';
import 'core/theme/app_colors.dart';
import 'data/local/app_database.dart';
import 'data/services/tts_service.dart';

Future<void> main() async {
  // Wajib dijalankan sebelum memakai plugin (sqflite, flutter_tts, dll).
  WidgetsFlutterBinding.ensureInitialized();

  // Menyiapkan data tanggal/bulan untuk locale Indonesia (id_ID).
  // Tanpa ini, format tanggal seperti "21 Oktober 2026" akan error.
  await initializeDateFormatting('id_ID', null);

  // Baris status & navigasi menggunakan warna tema aplikasi.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Membuka (atau membuat) database lokal sebelum aplikasi dijalankan,
  // sehingga migrasi skema selesai lebih dulu.
  final database = AppDatabase.instance;
  await database.database;

  // Menyiapkan mesin text-to-speech (tidak boleh menggagalkan aplikasi).
  unawaited(TtsService.instance.initialize());

  runApp(Dr4oxApp(dependencies: AppDependencies(database: database)));
}
