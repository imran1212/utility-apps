import 'dart:io';
import 'package:ad_manager/ad_manager.dart';
import 'package:flutter/material.dart';
import 'package:image_engine/image_engine.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _picker = ImagePicker();
  final _compressor = const ImageCompressionService();
  File? _source;
  File? _output;
  int _quality = 80;
  bool _busy = false;
  String? _error;

  Future<void> _pick() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    setState(() { _source = File(picked.path); _output = null; _error = null; });
  }

  Future<void> _compress() async {
    final source = _source;
    if (source == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      final result = await _compressor.compressJpeg(
        source: source, quality: _quality,
      );
      final dir = await getTemporaryDirectory();
      final output = File('${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await output.writeAsBytes(result.bytes, flush: true);
      if (mounted) setState(() => _output = output);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _format(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image Compressor')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Smaller images,\nmore room to save.',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Compress photos on your device. Your images stay private.'),
            const SizedBox(height: 24),
            InkWell(
              onTap: _pick,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 210,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: _source == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 48),
                          SizedBox(height: 10),
                          Text('Choose an image'),
                        ],
                      )
                    : Image.file(_source!, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(children: [
                      const Expanded(child: Text('Compression quality')),
                      Text('$_quality%'),
                    ]),
                    Slider(
                      value: _quality.toDouble(),
                      min: 10,
                      max: 100,
                      divisions: 18,
                      onChanged: (v) => setState(() => _quality = v.round()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _source == null || _busy ? null : _compress,
              child: Text(_busy ? 'Compressing...' : 'Compress image'),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_output != null) ...[
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Compression complete',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Original: ${_format(_source!.lengthSync())}'),
                      Text('Compressed: ${_format(_output!.lengthSync())}'),
                      OutlinedButton.icon(
                        onPressed: () => Share.shareXFiles([XFile(_output!.path)]),
                        icon: const Icon(Icons.share),
                        label: const Text('Share image'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Center(child: BannerAdSlot(adUnitId: AdService.androidTestBannerId)),
          ],
        ),
      ),
    );
  }
}
