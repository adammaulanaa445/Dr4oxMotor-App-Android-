import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// MengBagikan file struk melalui Android Share Sheet.
///
/// Share Sheet menampilkan daftar aplikasi (WhatsApp, Gmail, Bluetooth,
/// penyimpanan, dan lain-lain). Aplikasi tidak mengirim pesan secara
/// otomatis - pengguna tetap memilih aplikasi, penerima, dan
/// mengonfirmasi pengiriman.
class ShareService {
  const ShareService();

  /// Membagikan file PDF struk.
  ///
  /// Mengembalikan `true` bila menu berbagi berhasil dibuka.
  Future<bool> sharePdf(
    File file, {
    String? text,
    Rect? sharePositionOrigin,
  }) async {
    try {
      final result = await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType: 'application/pdf',
            name: file.uri.pathSegments.isEmpty
                ? 'struk.pdf'
                : file.uri.pathSegments.last,
          ),
        ],
        text: text,
        sharePositionOrigin: sharePositionOrigin,
      );
      return result.status != ShareResultStatus.unavailable;
    } catch (error) {
      debugPrint('Gagal membagikan struk: $error');
      return false;
    }
  }
}
