import 'dart:async';

import 'package:ad_manager/ad_manager.dart';
import 'package:common_ui/common_ui.dart';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

const _brandBlue = Color(0xFF0758C8);

void main() {
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
        home: const HomeScreen(),
      );
}
