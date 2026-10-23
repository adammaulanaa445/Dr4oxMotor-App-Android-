import 'package:flutter/widgets.dart';

import 'app_scope.dart';

/// Mixin untuk halaman yang memuat data dari database.
///
/// Saat menu halaman ini menjadi aktif, data dimuat ulang supaya selalu
/// menampilkan data terbaru (misalnya transaksi yang baru dibuat dari
/// halaman lain).
mixin TabRefreshListener<T extends StatefulWidget> on State<T> {
  /// Indeks menu milik halaman ini (0 = Dashboard, 1 = Pelanggan, dst).
  int get tabIndex;

  ValueNotifier<int>? _tabNotifier;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabNotifier = context.dependencies.selectedTab;
    _tabNotifier?.addListener(_handleTabChanged);
  }

  @override
  void dispose() {
    _tabNotifier?.removeListener(_handleTabChanged);
    super.dispose();
  }

  void _handleTabChanged() {
    if (_tabNotifier?.value == tabIndex) onTabActivated();
  }

  /// Dipanggil ketika menu halaman ini sedang aktif.
  void onTabActivated() {}
}
