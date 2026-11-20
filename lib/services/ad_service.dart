import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/constants/monetization_config.dart';

/// Layanan pengelola AdMob (Banner & Interstitial) yang aman saat offline.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  bool _initialized = false;
  Future<void>? _initFuture;
  InterstitialAd? _interstitialAd;
  int _completedTransactionsCount = 0;

  bool get isSupportedPlatform => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> initialize() {
    if (!isSupportedPlatform) return Future.value();
    _initFuture ??= _doInitialize();
    return _initFuture!;
  }

  Future<void> _doInitialize() async {
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      loadInterstitial();
    } catch (e) {
      debugPrint('AdMob init gagal (mungkin offline): $e');
      _initFuture = null;
    }
  }

  Future<bool> ensureInitialized() async {
    if (!isSupportedPlatform) return false;
    if (_initialized) return true;
    await initialize();
    return _initialized;
  }

  /// Membuat BannerAd baru (caller bertanggung jawab memanggil dispose).
  BannerAd? createBannerAd({
    required VoidCallback onLoaded,
    required void Function(LoadAdError error) onFailed,
  }) {
    if (!isSupportedPlatform || !_initialized) return null;
    final adUnitId = MonetizationConfig.bannerAdUnitId;
    if (adUnitId.isEmpty) return null;

    return BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onFailed(error);
        },
      ),
    )..load();
  }

  /// Memuat iklan Interstitial di latar belakang.
  void loadInterstitial() {
    if (!isSupportedPlatform || !_initialized) return;
    final adUnitId = MonetizationConfig.interstitialAdUnitId;
    if (adUnitId.isEmpty) return;

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial gagal dimuat: ${error.message}');
          _interstitialAd = null;
        },
      ),
    );
  }

  /// Dipanggil setiap transaksi selesai. Menampilkan interstitial setiap N transaksi
  /// khusus untuk pengguna gratis dan hanya jika iklan sudah siap (tidak memblokir saat offline).
  void onTransactionCompleted({required bool isPro}) {
    if (isPro || !isSupportedPlatform) return;

    _completedTransactionsCount++;
    if (_completedTransactionsCount % MonetizationConfig.interstitialEveryNTransactions != 0) {
      return;
    }

    final ad = _interstitialAd;
    if (ad == null) {
      loadInterstitial();
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitial();
      },
    );

    ad.show();
    _interstitialAd = null;
  }

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}

