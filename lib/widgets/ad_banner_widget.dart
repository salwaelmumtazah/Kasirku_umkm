import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_service.dart';

/// Widget Banner AdMob yang otomatis sembunyi saat pengguna Pro atau offline.
class AdBannerWidget extends StatefulWidget {
  final bool isPro;

  const AdBannerWidget({
    super.key,
    required this.isPro,
  });

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isPro) {
      _loadBanner();
    }
  }

  @override
  void didUpdateWidget(covariant AdBannerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPro && !oldWidget.isPro) {
      _disposeBanner();
    } else if (!widget.isPro && oldWidget.isPro) {
      _loadBanner();
    }
  }

  Future<void> _loadBanner() async {
    _disposeBanner();
    final ready = await AdService.instance.ensureInitialized();
    if (!ready || !mounted || widget.isPro) return;

    _bannerAd = AdService.instance.createBannerAd(
      onLoaded: () {
        if (mounted) {
          setState(() => _isLoaded = true);
        }
      },
      onFailed: (error) {
        debugPrint('Banner AdMob gagal dimuat (mungkin offline): ${error.message}');
        if (mounted) {
          setState(() {
            _isLoaded = false;
            _bannerAd = null;
          });
        }
      },
    );
  }

  void _disposeBanner() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isLoaded = false;
  }

  @override
  void dispose() {
    _disposeBanner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPro || !_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Theme.of(context).colorScheme.surface,
      alignment: Alignment.center,
      width: double.infinity,
      height: _bannerAd!.size.height.toDouble(),
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
