import 'package:flutter/material.dart';
import 'package:skribbl_clone/services/server_config_service.dart';
import 'package:skribbl_clone/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServerConfigService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final Widget? home;
  const MyApp({super.key, this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skribbl',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF818CF8),
          secondary: Color(0xFFA78BFA),
          surface: Color(0xFF1E293B),
        ),
      ),
      home: home ?? const SplashScreen(),
    );
  }
}
