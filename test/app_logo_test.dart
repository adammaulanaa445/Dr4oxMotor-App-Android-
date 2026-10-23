import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dr4ox_motor/widgets/app_logo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Logo aplikasi', () {
    test('berkas logo tersedia di dalam paket aplikasi', () async {
      final data = await rootBundle.load(AppLogo.assetPath);
      expect(data.lengthInBytes, greaterThan(1000));
    });

    test('semua ikon launcher Android tersedia di tiap densitas', () {
      const densities = [
        'mipmap-mdpi',
        'mipmap-hdpi',
        'mipmap-xhdpi',
        'mipmap-xxhdpi',
        'mipmap-xxxhdpi',
      ];
      for (final density in densities) {
        final legacy = File(
          'android/app/src/main/res/$density/ic_launcher.png',
        );
        final adaptive = File(
          'android/app/src/main/res/$density/ic_launcher_foreground.png',
        );
        expect(legacy.existsSync(), isTrue, reason: '$density/ic_launcher.png');
        expect(
          adaptive.existsSync(),
          isTrue,
          reason: '$density/ic_launcher_foreground.png',
        );
        expect(legacy.lengthSync(), greaterThan(500));
      }
    });

    test('ikon adaptif Android 8+ dan warna latar terdaftar', () {
      final adaptiveIcon = File(
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      );
      expect(adaptiveIcon.existsSync(), isTrue);
      final content = adaptiveIcon.readAsStringSync();
      expect(content, contains('ic_launcher_foreground'));
      expect(content, contains('ic_launcher_background'));

      final background = File(
        'android/app/src/main/res/values/ic_launcher_background.xml',
      );
      expect(background.existsSync(), isTrue);
      expect(background.readAsStringSync(), contains('0D0C11'));
    });
  });
}
