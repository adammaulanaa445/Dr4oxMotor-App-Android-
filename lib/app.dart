import 'package:flutter/material.dart';

import 'core/app_dependencies.dart';
import 'core/app_scope.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_shell.dart';

/// Root widget aplikasi Dr4ox Motor.
class Dr4oxApp extends StatelessWidget {
  const Dr4oxApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      dependencies: dependencies,
      child: MaterialApp(
        title: 'Dr4ox Motor',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const HomeShell(),
      ),
    );
  }
}
