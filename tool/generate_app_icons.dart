// Generator ikon aplikasi Dr4ox Motor.
//
// Menjalankan skrip ini:
//   dart run tool/generate_app_icons.dart
//
// Sumber gambar : assets/images/dr4ox_logo.png  (file PNG/JPG asli)
// Hasil          :
//   android/app/src/main/res/mipmap-*/ic_launcher.png            (ikon lama)
//   android/app/src/main/res/mipmap-*/ic_launcher_foreground.png  (ikon adaptif)
//   assets/images/dr4ox_logo_app.png                              (logo di dalam aplikasi)
//
// Skrip ini idempoten: aman dijalankan berkali-kali.
import 'dart:io';

import 'package:image/image.dart' as img;

const String sourcePath = 'assets/images/dr4ox_logo.png';
const String appLogoPath = 'assets/images/dr4ox_logo_app.png';

/// Ukuran ikon lama (px) untuk tiap densitas Android.
const Map<String, int> legacySizes = {
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
};

/// Ukuran ikon adaptif (px). Kanvas 108dp, isi 72dp (zona aman).
const Map<String, int> adaptiveSizes = {
  'mipmap-mdpi': 108,
  'mipmap-hdpi': 162,
  'mipmap-xhdpi': 216,
  'mipmap-xxhdpi': 324,
  'mipmap-xxxhdpi': 432,
};

/// Porsi logo yang mengisi zona aman ikon adaptif.
const double adaptiveContentRatio = 0.72;

void main(List<String> args) {
  final source = File(sourcePath);
  if (!source.existsSync()) {
    stderr.writeln('Berkas sumber tidak ditemukan: $sourcePath');
    stderr.writeln('Salin gambar logo Anda ke lokasi tersebut lalu jalankan '
        'skrip ini lagi.');
    exitCode = 1;
    return;
  }

  final original = img.decodeImage(source.readAsBytesSync());
  if (original == null) {
    stderr.writeln('Gambar gagal dibaca: $sourcePath');
    exitCode = 1;
    return;
  }
  stdout.writeln('Sumber: $sourcePath (${original.width}x${original.height})');

  // Normalkan ke bujur sangkar dengan latar hitam.
  final square = _toSquare(original);

  // 1. Ikon lama (persegi penuh).
  for (final entry in legacySizes.entries) {
    final size = entry.value;
    final resized = img.copyResize(square, width: size, height: size);
    final file = File('android/app/src/main/res/${entry.key}/ic_launcher.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(img.encodePng(resized, level: 9));
    stdout.writeln('  ${entry.key}/ic_launcher.png (${size}x$size)');
  }

  // 2. Ikon adaptif: logo di tengah kanvas, sisanya transparan.
  for (final entry in adaptiveSizes.entries) {
    final canvasSize = entry.value;
    final contentSize = (canvasSize * adaptiveContentRatio).round();
    final content = img.copyResize(square, width: contentSize, height: contentSize);
    final canvas = img.Image(width: canvasSize, height: canvasSize, numChannels: 4);
    img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));
    img.compositeImage(
      canvas,
      content,
      dstX: (canvasSize - contentSize) ~/ 2,
      dstY: (canvasSize - contentSize) ~/ 2,
    );
    final file =
        File('android/app/src/main/res/${entry.key}/ic_launcher_foreground.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(img.encodePng(canvas, level: 9));
    stdout.writeln('  ${entry.key}/ic_launcher_foreground.png (${canvasSize}x$canvasSize)');
  }

  // 3. Logo untuk dipakai di dalam aplikasi.
  final appLogo = img.copyResize(square, width: 512, height: 512);
  File(appLogoPath).parent.createSync(recursive: true);
  File(appLogoPath).writeAsBytesSync(img.encodePng(appLogo, level: 9));
  stdout.writeln('  $appLogoPath (512x512)');

  stdout.writeln('Selesai.');
}

/// Mengubah gambar menjadi bujur sangkar, mengisi sisanya dengan warna
/// latar aplikasi (#0D0C11).
img.Image _toSquare(img.Image source) {
  final side = source.width < source.height ? source.width : source.height;
  final cropped = img.copyCrop(
    source,
    x: (source.width - side) ~/ 2,
    y: (source.height - side) ~/ 2,
    width: side,
    height: side,
  );
  return cropped;
}
