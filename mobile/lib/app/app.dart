import 'package:flutter/material.dart';

import '../core/routing/app_router.dart';
import '../core/theme/app_theme.dart';

class EEELibraryApp extends StatelessWidget {
  const EEELibraryApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'EEELibrary',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    routerConfig: appRouter,
  );
}
