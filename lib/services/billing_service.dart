import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/constants/monetization_config.dart';
import 'settings_service.dart';

/// Layanan Google Play Billing / App Store In-App Purchase untuk upgrade Kasirku Pro.
class BillingService extends ChangeNotifier {
  final SettingsService settingsService;
  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool _isStoreAvailable = false;
  bool _isLoading = false;
  bool _isPurchasing = false;
  String? _errorMessage;
  String? _statusMessage;
  List<ProductDetails> _products = [];

  BillingService({required this.settingsService});

  bool get isSupportedPlatform => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  bool get isStoreAvailable => _isStoreAvailable;
  bool get isLoading => _isLoading;
  bool get isPurchasing => _isPurchasing;
  String? get errorMessage => _errorMessage;
  String? get statusMessage => _statusMessage;
  List<ProductDetails> get products => List.unmodifiable(_products);
  bool get isPro => settingsService.isPro;

  Future<void> initialize() async {
    if (!isSupportedPlatform) {
      _isStoreAvailable = false;
      notifyListeners();
      return;
    }

    _purchaseSubscription?.cancel();
    _purchaseSubscription = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onDone: () => _purchaseSubscription?.cancel(),
      onError: (Object error) {
        _isPurchasing = false;
        _errorMessage = 'Kesalahan billing: $error';
        notifyListeners();
      },
    );

    await loadProducts();
  }

  Future<void> loadProducts() async {
    if (!isSupportedPlatform) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final available = await _iap.isAvailable();
      _isStoreAvailable = available;

      if (!available) {
        _products = [];
        _errorMessage = 'Google Play / App Store tidak tersedia (pastikan perangkat online).';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await _iap.queryProductDetails(MonetizationConfig.allProductIds);

      if (response.error != null) {
        _errorMessage = 'Gagal memuat produk billing: ${response.error!.message}';
      } else if (response.productDetails.isEmpty) {
        _errorMessage =
            'Produk belum dikonfigurasi di Play Console (${MonetizationConfig.allProductIds.join(", ")}).';
      }

      _products = response.productDetails;
    } catch (e) {
      _isStoreAvailable = false;
      _errorMessage = 'Tidak dapat terhubung ke layanan billing: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> buyProduct(ProductDetails product) async {
    if (!_isStoreAvailable) {
      _errorMessage = 'Layanan billing tidak tersedia saat offline.';
      notifyListeners();
      return false;
    }

    _isPurchasing = true;
    _errorMessage = null;
    _statusMessage = 'Memproses pembayaran...';
    notifyListeners();

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      final started = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      if (!started) {
        _isPurchasing = false;
        _statusMessage = null;
        _errorMessage = 'Gagal memulai transaksi Google Play Billing.';
        notifyListeners();
      }
      return started;
    } catch (e) {
      _isPurchasing = false;
      _statusMessage = null;
      _errorMessage = 'Gagal membeli produk: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> restorePurchases() async {
    if (!isSupportedPlatform) return;

    _isPurchasing = true;
    _errorMessage = null;
    _statusMessage = 'Memulihkan pembelian sebelumnya...';
    notifyListeners();

    try {
      final available = await _iap.isAvailable();
      if (!available) {
        _errorMessage = 'Tidak dapat memulihkan pembelian saat offline.';
      } else {
        await _iap.restorePurchases();
        _statusMessage = 'Permintaan pemulihan dikirim.';
      }
    } catch (e) {
      _errorMessage = 'Gagal memulihkan pembelian: $e';
    } finally {
      _isPurchasing = false;
      notifyListeners();
    }
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _isPurchasing = true;
          _statusMessage = 'Menunggu konfirmasi pembayaran...';
          _errorMessage = null;
          notifyListeners();
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (MonetizationConfig.allProductIds.contains(purchase.productID)) {
            await settingsService.setProStatus(true, productId: purchase.productID);
            _statusMessage = purchase.status == PurchaseStatus.restored
                ? 'Status Kasirku Pro berhasil dipulihkan!'
                : 'Selamat! Kasirku Pro kini aktif.';
            _errorMessage = null;
          }
          _isPurchasing = false;
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          notifyListeners();
          break;

        case PurchaseStatus.error:
          _isPurchasing = false;
          _statusMessage = null;
          _errorMessage = purchase.error?.message ?? 'Pembayaran gagal.';
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          notifyListeners();
          break;

        case PurchaseStatus.canceled:
          _isPurchasing = false;
          _statusMessage = 'Pembayaran dibatalkan.';
          _errorMessage = null;
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          notifyListeners();
          break;
      }
    }
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}

