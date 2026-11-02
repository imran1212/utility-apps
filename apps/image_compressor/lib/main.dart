import 'dart:async';

import 'package:ad_manager/ad_manager.dart';
import 'package:common_ui/common_ui.dart';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

const _brandBlue = Color(0xFF0758C8);
const _brandNavy = Color(0xFF082B63);
const _brandYellow = Color(0xFFFFC928);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ImageCompressorApp());
  unawaited(AdService.initialize());
}

class ImageCompressorApp extends StatelessWidget {
  const ImageCompressorApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Image Compressor by SVSystem',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light().copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: _brandBlue,
            brightness: Brightness.light,
          ),
        ),
        home: const _BrandSplashScreen(),
      );
}

class _BrandSplashScreen extends StatefulWidget {
  const _BrandSplashScreen();

  @override
  State<_BrandSplashScreen> createState() => _BrandSplashScreenState();
}

class _BrandSplashScreenState extends State<_BrandSplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      AdService.showAppOpenAd(
        onComplete: () {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            PageRouteBuilder<void>(
              pageBuilder: (_, __, ___) => const HomeScreen(),
              transitionDuration: const Duration(milliseconds: 350),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFFF), Color(0xFFEAF3FF), Color(0xFFD9E9FF)],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 116,
                  height: 116,
                  decoration: BoxDecoration(
                    color: _brandBlue,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: _brandBlue.withValues(alpha: 0.22),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.image_rounded, size: 66, color: Colors.white),
                      Positioned(
                        left: 9,
                        top: 9,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: _brandYellow,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Text(
                            'SV',
                            style: TextStyle(
                              color: _brandNavy,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 9,
                        bottom: 9,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: _brandYellow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.compress_rounded,
                            size: 23,
                            color: _brandNavy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Image Compressor',
                  style: TextStyle(
                    color: _brandNavy,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'by SVSystem',
                  style: TextStyle(
                    color: _brandBlue,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 54,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _brandYellow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Small Tools for Everyday Use',
                  style: TextStyle(color: Color(0xFF536987), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
}
