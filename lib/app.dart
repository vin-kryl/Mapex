import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/providers.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';

class MapexApp extends ConsumerWidget {
  const MapexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      title: 'Mapex',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light, settings),
      darkTheme: buildTheme(Brightness.dark, settings),
      themeMode: themeModeOf(settings.theme),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(settings.fontScale)),
        child: child!,
      ),
      home: const HomeShell(),
    );
  }
}
