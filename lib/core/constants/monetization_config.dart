import 'dart:io';

/// Konfigurasi AdMob & Google Play Billing / App Store IAP.
///
/// PENTING:
/// Saat ini menggunakan ID uji coba resmi Google AdMob agar aman selama pengembangan.
/// Sebelum rilis ke Play Store / App Store, ganti dengan ID produksi dari akun AdMob
/// dan buat produk yang sesuai di Google Play Console / App Store Connect.
class MonetizationConfig {
  MonetizationConfig._();

  // ==========================================
  // ADMOB AD UNIT IDs (Official Google Test IDs)
  // ==========================================
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716';
    }
    return '';
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910';
    }
    return '';
  }

  /// Tampilkan iklan interstitial setiap N transaksi selesai (khusus pengguna gratis).
  static const int interstitialEveryNTransactions = 3;

  // ==========================================
  // IN-APP PURCHASE / GOOGLE PLAY BILLING IDs
  // ==========================================
  /// Pembelian sekali bayar (Non-Consumable) untuk membuka Kasirku Pro selamanya.
  static const String proLifetimeProductId = 'kasirku_pro_lifetime';

  /// Langganan bulanan (Subscription) untuk Kasirku Pro.
  static const String proMonthlyProductId = 'kasirku_pro_monthly';

  static const Set<String> allProductIds = {
    proLifetimeProductId,
    proMonthlyProductId,
  };

  /// Batas jumlah produk untuk versi gratis (Pro: tanpa batas).
  static const int freeProductLimit = 50;
}

