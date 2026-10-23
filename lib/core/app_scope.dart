import 'package:flutter/widgets.dart';

import 'app_dependencies.dart';

/// Menyediakan [AppDependencies] ke seluruh widget di bawahnya.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.dependencies,
    required super.child,
  });

  final AppDependencies dependencies;

  /// Mengambil instance dependencies dari context.
  ///
  /// Gunakan `AppScope.of(context)` atau `context.dependencies`.
  static AppDependencies of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope tidak ditemukan pada context ini');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) {
    return oldWidget.dependencies != dependencies;
  }
}

/// Extension supaya repository mudah dipanggil dari widget.
extension AppScopeX on BuildContext {
  AppDependencies get dependencies => AppScope.of(this);
}
