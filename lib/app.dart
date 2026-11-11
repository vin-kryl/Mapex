import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/providers.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';

class SortleApp extends ConsumerWidget {
  const SortleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    Widget app(ColorScheme? light, ColorScheme? dark) => MaterialApp(
      title: 'Sortle',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light, settings, wallpaper: light),
      darkTheme: buildTheme(Brightness.dark, settings, wallpaper: dark),
      themeMode: themeModeOf(settings.theme),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(settings.fontScale)),
        child: child!,
      ),
      home: const HomeShell(),
    );
    if (!settings.wallpaperColors) return app(null, null);
    return DynamicColorBuilder(builder: app);
  }
}
