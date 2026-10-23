import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Logo aplikasi Dr4ox Motor (burung elang).
///
/// Logo memakai berkas `assets/images/dr4ox_logo_app.png` yang dihasilkan
/// oleh `tool/generate_app_icons.dart`.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 48, this.showBorder = true});

  /// Ukuran logo dalam piksel logis.
  final double size;

  /// Tampilkan garis pembatas lingkaran di sekeliling logo.
  final bool showBorder;

  /// Lokasi berkas logo.
  static const String assetPath = 'assets/images/dr4ox_logo_app.png';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.background,
        border: showBorder
            ? Border.all(color: AppColors.divider, width: 1)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Logo tetap tampil walau berkas belum tersedia (mis. saat pengembangan).
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.two_wheeler,
          size: size * 0.55,
          color: AppColors.accentLight,
        ),
      ),
    );
  }
}
