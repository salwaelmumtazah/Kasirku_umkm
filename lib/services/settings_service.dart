import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_theme.dart';
import '../data/database/database_helper.dart';

/// Menyimpan pengaturan toko, tema tampilan, & status Pro secara lokal (SQLite + SharedPreferences).
class SettingsService extends ChangeNotifier {
  static const _keyStoreName = 'store_name';
  static const _keyStoreAddress = 'store_address';
  static const _keyReceiptFooter = 'receipt_footer';
  static const _keyIsPro = 'is_pro_user';
  static const _keyProProductId = 'pro_product_id';
  static const _keyThemeMode = 'theme_mode';
  static const _keyThemeColor = 'theme_color';

  String _storeName = 'Kasirku UMKM';
  String _storeAddress = 'Jl. Merdeka No. 10';
  String _receiptFooter = 'Terima kasih telah berbelanja!';
  bool _isPro = false;
  String? _proProductId;
  ThemeMode _themeMode = ThemeMode.light;
  AppThemeColor _themeColor = AppThemeColor.emerald;

  String get storeName => _storeName;
  String get storeAddress => _storeAddress;
  String get receiptFooter => _receiptFooter;
  bool get isPro => _isPro;
  String? get proProductId => _proProductId;
  ThemeMode get themeMode => _themeMode;
  AppThemeColor get themeColor => _themeColor;

  Future<void> load() async {
    // 1. Coba muat dari SQLite terlebih dahulu (paling stabil di Android & offline)
    Map<String, String> dbValues = {};
    try {
      dbValues = await DatabaseHelper.instance.getAllSettings();
    } catch (e) {
      debugPrint('Gagal memuat settings dari SQLite: $e');
    }

    // 2. Fallback / gabungkan dengan SharedPreferences
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('SharedPreferences tidak tersedia: $e');
    }

    _storeName = dbValues[_keyStoreName] ?? prefs?.getString(_keyStoreName) ?? _storeName;
    _storeAddress =
        dbValues[_keyStoreAddress] ?? prefs?.getString(_keyStoreAddress) ?? _storeAddress;
    _receiptFooter =
        dbValues[_keyReceiptFooter] ?? prefs?.getString(_keyReceiptFooter) ?? _receiptFooter;

    if (dbValues.containsKey(_keyIsPro)) {
      _isPro = dbValues[_keyIsPro] == 'true';
    } else if (prefs != null) {
      _isPro = prefs.getBool(_keyIsPro) ?? false;
    }

    _proProductId = dbValues[_keyProProductId] ?? prefs?.getString(_keyProProductId);

    final savedMode = dbValues[_keyThemeMode] ?? prefs?.getString(_keyThemeMode);
    _themeMode = _parseThemeMode(savedMode);

    final savedColor = dbValues[_keyThemeColor] ?? prefs?.getString(_keyThemeColor);
    _themeColor = AppThemeColor.fromName(savedColor);

    notifyListeners();
  }

  ThemeMode _parseThemeMode(String? value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  Future<void> _persistValues(Map<String, String> values) async {
    try {
      await DatabaseHelper.instance.saveSettings(values);
    } catch (e) {
      debugPrint('Gagal simpan settings ke SQLite: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      for (final entry in values.entries) {
        if (entry.key == _keyIsPro) {
          await prefs.setBool(entry.key, entry.value == 'true');
        } else {
          await prefs.setString(entry.key, entry.value);
        }
      }
    } catch (e) {
      debugPrint('Gagal simpan settings ke SharedPreferences: $e');
    }
  }

  Future<void> updateStoreInfo({
    required String name,
    required String address,
    required String footer,
  }) async {
    _storeName = name.trim().isEmpty ? 'Kasirku UMKM' : name.trim();
    _storeAddress = address.trim();
    _receiptFooter = footer.trim();
    notifyListeners();

    await _persistValues({
      _keyStoreName: _storeName,
      _keyStoreAddress: _storeAddress,
      _keyReceiptFooter: _receiptFooter,
    });
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _persistValues({_keyThemeMode: mode.name});
  }

  Future<void> setThemeColor(AppThemeColor color) async {
    if (_themeColor == color) return;
    _themeColor = color;
    notifyListeners();
    await _persistValues({_keyThemeColor: color.name});
  }

  Future<void> setProStatus(bool value, {String? productId}) async {
    _isPro = value;
    _proProductId = value ? productId : null;
    notifyListeners();

    await _persistValues({
      _keyIsPro: _isPro.toString(),
      _keyProProductId: _proProductId ?? '',
    });
  }
}
