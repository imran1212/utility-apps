import 'dart:io';

import 'package:ad_manager/ad_manager.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
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
  final ImagePicker _picker = ImagePicker();
  final ImageCompressionService _compressor = const ImageCompressionService();

  File? _source;
  File? _output;
  CompressionResult? _result;
  int _quality = 80;
  bool _busy = false;
  bool _saving = false;
  String? _error;

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _source = File(picked.path);
        _output = null;
        _result = null;
        _error = null;
      });
    } catch (error) {
      _showMessage('Could not open image: $error', isError: true);
    }
  }

  Future<void> _compress() async {
    final source = _source;
    if (source == null || _busy) return;

    setState(() {
      _busy = true;
      _error = null;
      _output = null;
      _result = null;
    });

    try {
      final result = await _compressor.compressJpeg(
        source: source,
        quality: _quality,
      );
      final directory = await getTemporaryDirectory();
      final output = File(
        '${directory.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await output.writeAsBytes(result.bytes, flush: true);
      if (!mounted) return;
      setState(() {
        _result = result;
        _output = output;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Compression failed. Please try another image.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveToGallery() async {
    final output = _output;
    if (output == null || _saving) return;
    setState(() => _saving = true);
    try {
      await Gal.putImage(output.path);
      _showMessage('Saved to your gallery.');
    } on GalException catch (error) {
      _showMessage(error.type.message, isError: true);
    } catch (_) {
      _showMessage('Could not save the image. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _shareImage() async {
    final output = _output;
    if (output == null) return;
    await Share.shareXFiles(
      [XFile(output.path, mimeType: 'image/jpeg')],
      text: 'Compressed with Image Compressor by SVSystem',
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasResult = _output != null && _result != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Image Compressor',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Choose image',
            onPressed: _busy ? null : _pickImage,
            icon: const Icon(Icons.add_photo_alternate_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD4E5FF)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0758C8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.compress_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Image Compressor',
                          style: TextStyle(
                            color: Color(0xFF082B63),
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'A product of SVSystem',
                          style: TextStyle(
                            color: Color(0xFF0758C8),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.verified_rounded, color: Color(0xFF0758C8)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Smaller images.\nMore space.',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.08,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Compress photos privately on your device. Your images are not uploaded.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            _ImagePanel(
              title: _source == null ? 'Original image' : 'Selected image',
              file: _source,
              placeholderIcon: Icons.add_photo_alternate_outlined,
              placeholder: 'Tap to choose a photo',
              onTap: _busy ? null : _pickImage,
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Compression quality',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            child: Text(
                              '$_quality%',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _quality.toDouble(),
                      min: 10,
                      max: 100,
                      divisions: 18,
                      label: '$_quality%',
                      onChanged: _busy || _source == null
                          ? null
                          : (value) => setState(() {
                                _quality = value.round();
                                _output = null;
                                _result = null;
                              }),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Smaller file', style: theme.textTheme.labelSmall),
                        Text('Better quality', style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _source == null || _busy ? null : _compress,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.compress),
              label: Text(_busy ? 'Compressing…' : 'Compress image'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (hasResult) ...[
              const SizedBox(height: 22),
              Text(
                'Your compressed image',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _ImagePanel(
                title: 'Compressed preview',
                file: _output,
                placeholderIcon: Icons.image_outlined,
                placeholder: 'Preview unavailable',
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _SizeRow(
                        label: 'Original size',
                        value: _formatBytes(_result!.originalBytes),
                      ),
                      const SizedBox(height: 10),
                      _SizeRow(
                        label: 'Compressed size',
                        value: _formatBytes(_result!.compressedBytes),
                        emphasize: true,
                      ),
                      const Divider(height: 22),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _result!.savedPercent > 0
                                  ? '${_result!.savedPercent.toStringAsFixed(1)}% smaller'
                                  : 'Image optimized at selected quality',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _saveToGallery,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded),
                      label: Text(_saving ? 'Saving…' : 'Save'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _shareImage,
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 26),
            const Center(
              child: BannerAdSlot(adUnitId: AdService.androidTestBannerId),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'SVSystem  •  Small Tools for Everyday Use',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePanel extends StatelessWidget {
  const _ImagePanel({
    required this.title,
    required this.file,
    required this.placeholderIcon,
    required this.placeholder,
    this.onTap,
  });

  final String title;
  final File? file;
  final IconData placeholderIcon;
  final String placeholder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              alignment: Alignment.center,
              child: file == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          placeholderIcon,
                          size: 44,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          placeholder,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  : Image.file(
                      file!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: 220,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        size: 42,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SizeRow extends StatelessWidget {
  const _SizeRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: TextStyle(
            fontWeight: emphasize ? FontWeight.w900 : FontWeight.w600,
            color: emphasize ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
      ],
    );
  }
}
