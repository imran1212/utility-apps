import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();

  static const androidTestBannerId = 'ca-app-pub-3940256099942544/9214589741';
  static const androidTestInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';

  static InterstitialAd? _interstitial;
  static bool _initialized = false;
  static int _successfulCompressions = 0;

  static Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      _loadInterstitial();
    } catch (error) {
      debugPrint('AdMob initialization skipped: $error');
    }
  }

  static void _loadInterstitial() {
    if (!_initialized || _interstitial != null) return;
    InterstitialAd.load(
      adUnitId: androidTestInterstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial ad failed to load: $error');
        },
      ),
    );
  }

  static void onCompressionCompleted() {
    _successfulCompressions++;
    if (_successfulCompressions < 4) return;
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    _successfulCompressions = 0;
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (closedAd) {
        closedAd.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (failedAd, error) {
        failedAd.dispose();
        _loadInterstitial();
      },
    );
    ad.show();
  }

  static void dispose() {
    _interstitial?.dispose();
    _interstitial = null;
  }
}

class BannerAdSlot extends StatefulWidget {
  const BannerAdSlot({super.key, required this.adUnitId});
  final String adUnitId;

  @override
  State<BannerAdSlot> createState() => _BannerAdSlotState();
}

class _BannerAdSlotState extends State<BannerAdSlot> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ad = BannerAd(
      adUnitId: widget.adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _loaded = false);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
