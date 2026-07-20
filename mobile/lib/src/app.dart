import 'package:flutter/material.dart';
import 'routing/app_router.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = ThemeData.light().textTheme.apply(fontFamily: 'PlusJakartaSans');
    final baseDarkTextTheme = ThemeData.dark().textTheme.apply(fontFamily: 'PlusJakartaSans');

    return MaterialApp.router(
      title: 'PayAjo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC8E6A0),
          brightness: Brightness.light,
        ),
        textTheme: baseTextTheme.copyWith(
          displayLarge: baseTextTheme.displayLarge?.copyWith(fontFamily: 'SpaceGrotesk'),
          displayMedium: baseTextTheme.displayMedium?.copyWith(fontFamily: 'SpaceGrotesk'),
          displaySmall: baseTextTheme.displaySmall?.copyWith(fontFamily: 'SpaceGrotesk'),
          headlineLarge: baseTextTheme.headlineLarge?.copyWith(fontFamily: 'SpaceGrotesk'),
          headlineMedium: baseTextTheme.headlineMedium?.copyWith(fontFamily: 'SpaceGrotesk'),
          headlineSmall: baseTextTheme.headlineSmall?.copyWith(fontFamily: 'SpaceGrotesk'),
          titleLarge: baseTextTheme.titleLarge?.copyWith(fontFamily: 'SpaceGrotesk'),
          titleMedium: baseTextTheme.titleMedium?.copyWith(fontFamily: 'SpaceGrotesk'),
          titleSmall: baseTextTheme.titleSmall?.copyWith(fontFamily: 'SpaceGrotesk'),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC8E6A0),
          brightness: Brightness.dark,
        ),
        textTheme: baseDarkTextTheme.copyWith(
          displayLarge: baseDarkTextTheme.displayLarge?.copyWith(fontFamily: 'SpaceGrotesk'),
          displayMedium: baseDarkTextTheme.displayMedium?.copyWith(fontFamily: 'SpaceGrotesk'),
          displaySmall: baseDarkTextTheme.displaySmall?.copyWith(fontFamily: 'SpaceGrotesk'),
          headlineLarge: baseDarkTextTheme.headlineLarge?.copyWith(fontFamily: 'SpaceGrotesk'),
          headlineMedium: baseDarkTextTheme.headlineMedium?.copyWith(fontFamily: 'SpaceGrotesk'),
          headlineSmall: baseDarkTextTheme.headlineSmall?.copyWith(fontFamily: 'SpaceGrotesk'),
          titleLarge: baseDarkTextTheme.titleLarge?.copyWith(fontFamily: 'SpaceGrotesk'),
          titleMedium: baseDarkTextTheme.titleMedium?.copyWith(fontFamily: 'SpaceGrotesk'),
          titleSmall: baseDarkTextTheme.titleSmall?.copyWith(fontFamily: 'SpaceGrotesk'),
        ),
      ),
      themeMode: ThemeMode.system,
      routerConfig: goRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
