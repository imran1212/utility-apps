import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
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
  final InAppPurchase _billing = InAppPurchase.instance;
  static const _premiumId = 'svsystem_image_compressor_premium_lifetime';
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  ProductDetails? _premiumProduct;
  bool _premium = false;
  bool _purchasePending = false;
  bool _billingAvailable = false;
  List<File> _batchSources = [];
  List<File> _batchOutputs = [];
  int _freeCompressions = 0;

  File? _source;
  File? _output;
  CompressionResult? _result;
  int _quality = 80;
  bool _busy = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _purchaseSub = _billing.purchaseStream.listen(_handlePurchases);
    _loadPremium();
  }

  Future<void> _loadPremium() async {
    try {
      _billingAvailable = await _billing.isAvailable();
      if (_billingAvailable) {
        final response = await _billing.queryProductDetails({_premiumId});
        if (mounted) setState(() => _premiumProduct =
            response.productDetails.isEmpty ? null : response.productDetails.first);
        await _billing.restorePurchases();
      }
    } catch (_) {}
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != _premiumId) continue;
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        if (mounted) {
          setState(() { _premium = true; _purchasePending = false; });
          _showMessage('Premium activated. Ads are removed.');
        }
      } else if (purchase.status == PurchaseStatus.pending) {
        if (mounted) setState(() => _purchasePending = true);
      } else {
        if (mounted) setState(() => _purchasePending = false);
        if (purchase.status == PurchaseStatus.error && mounted) {
          _showMessage('Purchase failed. Please try again.', isError: true);
        }
      }
      if (purchase.pendingCompletePurchase) {
        await _billing.completePurchase(purchase);
      }
    }
  }

  Future<void> _buyPremium() async {
    final product = _premiumProduct;
    if (!_billingAvailable || product == null) {
      _showMessage('Premium product is not configured in Google Play yet.', isError: true);
      return;
    }
    setState(() => _purchasePending = true);
    await _billing.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  Future<void> _restorePremium() async {
    try {
      await _billing.restorePurchases();
      _showMessage('Checking previous purchases…');
    } catch (_) {
      _showMessage('Could not restore purchases.', isError: true);
    }
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      if (_premium) {
        final picked = await _picker.pickMultiImage(requestFullMetadata: false);
        if (picked.isEmpty || !mounted) return;
        setState(() {
          _batchSources = picked.map((item) => File(item.path)).toList();
          _source = _batchSources.first;
          _output = null; _result = null; _batchOutputs = []; _error = null;
        });
        return;
      }
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _batchSources = [File(picked.path)];
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
    final sources = _batchSources.isNotEmpty
        ? _batchSources
        : (_source == null ? <File>[] : <File>[_source!]);
    if (sources.isEmpty || _busy) return;
    setState(() { _busy = true; _error = null; _output = null; _result = null; _batchOutputs = []; });
    try {
      final directory = await getTemporaryDirectory();
      final outputs = <File>[];
      final results = <CompressionResult>[];
      for (var i = 0; i < sources.length; i++) {
        final result = await _compressor.compressJpeg(source: sources[i], quality: _quality);
        final output = File(directory.path + '/compressed_' +
            DateTime.now().microsecondsSinceEpoch.toString() + '_' + i.toString() + '.jpg');
        await output.writeAsBytes(result.bytes, flush: true);
        outputs.add(output); results.add(result);
      }
      if (!mounted) return;
      setState(() {
        _batchOutputs = outputs; _output = outputs.first; _result = results.first;
      });
      if (!_premium) {
        _freeCompressions++;
        if (_freeCompressions >= 4) { _freeCompressions = 0; AdService.onCompressionCompleted(); }
      }
      if (outputs.length > 1) _showMessage(outputs.length.toString() + ' images compressed.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Compression failed. Please try another image.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveToGallery() async {
    final output = _output;
    if (output == null || _saving) return;
    setState(() => _saving = true);
    try {
      final files = _batchOutputs.isNotEmpty ? _batchOutputs : [output];
      for (final file in files) { await Gal.putImage(file.path); }
      _showMessage(files.length == 1 ? 'Saved to your gallery.' : files.length.toString() + ' images saved.');
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
      (_batchOutputs.isNotEmpty ? _batchOutputs : [output]).map((file) => XFile(file.path, mimeType: 'image/jpeg')).toList(),
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Image Compressor',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            Text(
              'by SVSystem',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ],
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
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(Icons.image_rounded, color: Colors.white, size: 25),
                        const Positioned(
                          right: 2,
                          bottom: 2,
                          child: Icon(Icons.compress_rounded, color: Color(0xFFFFC928), size: 16),
                        ),
                        Positioned(
                          left: -2,
                          top: -3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFC928),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'SV',
                              style: TextStyle(
                                color: Color(0xFF082B63),
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
                  Icon(Icons.verified, color: _premium ? const Color(0xFF1687F8) : const Color(0xFF0758C8)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_premium)
              const Row(children: [
                Icon(Icons.verified, color: Color(0xFF1687F8)),
                SizedBox(width: 7),
                Text('Premium active • Ads removed', style: TextStyle(color: Color(0xFF0758C8), fontWeight: FontWeight.w800)),
              ])
            else
              Card(
                color: const Color(0xFFEAF3FF),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [
                      Icon(Icons.verified, color: Color(0xFF1687F8)),
                      SizedBox(width: 6),
                      Text('SVSystem Premium', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF082B63))),
                      Spacer(),
                      Text('ONE-TIME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 5),
                    const Text('Multi-image compression • Save all together • No ads'),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: FilledButton(
                        onPressed: _purchasePending ? null : _buyPremium,
                        child: Text(_purchasePending ? 'Please wait…' : 'Unlock Premium • ' + (_premiumProduct?.price ?? r'$0.99')),
                      )),
                      TextButton(onPressed: _restorePremium, child: const Text('Restore')),
                    ]),
                  ]),
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
              title: _source == null ? 'Original image' : (_premium && _batchSources.length > 1 ? 'Selected images (' + _batchSources.length.toString() + ')' : 'Selected image'),
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
              label: Text(_busy ? 'Compressing…' : (_batchSources.length > 1 ? 'Compress ' + _batchSources.length.toString() + ' images' : 'Compress image')),
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
                      label: Text(_saving ? 'Saving…' : (_batchOutputs.length > 1 ? 'Save all' : 'Save')),
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
      bottomNavigationBar: _premium ? null : SafeArea(
        top: false,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
          ),
          child: const BannerAdSlot(adUnitId: AdService.androidTestBannerId),
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
