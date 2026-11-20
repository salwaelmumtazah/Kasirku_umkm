import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/database/database_helper.dart';
import '../data/models/cart_item.dart';
import '../data/models/product.dart';
import '../services/billing_service.dart';
import '../services/settings_service.dart';
import '../widgets/ad_banner_widget.dart';
import 'history/history_screen.dart';
import 'pos/pos_screen.dart';
import 'products/products_screen.dart';
import 'reports/reports_screen.dart';
import 'settings/pro_upgrade_screen.dart';
import 'settings/settings_screen.dart';

class MainShell extends StatefulWidget {
  final SettingsService settingsService;
  final BillingService billingService;

  const MainShell({
    super.key,
    required this.settingsService,
    required this.billingService,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  List<Product> _products = [];
  bool _isLoadingProducts = true;
  int _transactionRefreshToken = 0;

  final Map<int, CartItem> _cart = {};

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    final products = await DatabaseHelper.instance.getAllProducts();
    if (!mounted) return;
    setState(() {
      _products = products;
      _isLoadingProducts = false;

      // Sinkronkan keranjang dengan perubahan harga/nama/stok terbaru
      final productById = {
        for (final p in products)
          if (p.id != null) p.id!: p,
      };
      final existingIds = _cart.keys.toList();
      for (final id in existingIds) {
        final updated = productById[id];
        if (updated == null || updated.stock <= 0) {
          _cart.remove(id);
        } else {
          final qty = _cart[id]!.quantity.clamp(1, updated.stock);
          _cart[id] = CartItem(product: updated, quantity: qty);
        }
      }
    });
  }

  void _addToCart(Product product) {
    if (product.id == null) return;
    final currentQty = _cart[product.id]?.quantity ?? 0;
    if (currentQty >= product.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stok "${product.name}" hanya tersedia ${product.stock}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() {
      if (_cart.containsKey(product.id)) {
        _cart[product.id]!.quantity += 1;
      } else {
        _cart[product.id!] = CartItem(product: product, quantity: 1);
      }
    });
    HapticFeedback.selectionClick();
  }

  void _decrementFromCart(int productId) {
    setState(() {
      if (_cart.containsKey(productId)) {
        if (_cart[productId]!.quantity > 1) {
          _cart[productId]!.quantity -= 1;
        } else {
          _cart.remove(productId);
        }
      }
    });
  }

  void _clearCart() {
    setState(() => _cart.clear());
  }

  Future<void> _onTransactionSaved() async {
    await _loadProducts();
    if (mounted) {
      setState(() => _transactionRefreshToken++);
    }
  }

  void _openUpgradeScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProUpgradeScreen(billingService: widget.billingService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: widget.settingsService,
      builder: (context, _) {
        final isPro = widget.settingsService.isPro;

        final pages = IndexedStack(
          index: _currentIndex,
          children: [
            PosScreen(
              products: _products,
              isLoading: _isLoadingProducts,
              cart: _cart,
              settingsService: widget.settingsService,
              onAddToCart: _addToCart,
              onDecrementFromCart: _decrementFromCart,
              onClearCart: _clearCart,
              onTransactionSaved: _onTransactionSaved,
              onOpenUpgrade: _openUpgradeScreen,
            ),
            ProductsScreen(
              products: _products,
              isLoading: _isLoadingProducts,
              isPro: isPro,
              onRefresh: _loadProducts,
              onDeleted: (deletedId) {
                setState(() => _cart.remove(deletedId));
                _loadProducts();
              },
              onOpenUpgrade: _openUpgradeScreen,
            ),
            HistoryScreen(
              settingsService: widget.settingsService,
              refreshToken: _transactionRefreshToken,
            ),
            ReportsScreen(
              products: _products,
              refreshToken: _transactionRefreshToken,
            ),
            SettingsScreen(
              settingsService: widget.settingsService,
              billingService: widget.billingService,
            ),
          ],
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final useRail = constraints.maxWidth >= 700;

            if (useRail) {
              return Scaffold(
                body: Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _currentIndex,
                      onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
                      labelType: NavigationRailLabelType.all,
                      indicatorColor: colorScheme.primaryContainer,
                      destinations: [
                        NavigationRailDestination(
                          icon: const Icon(Icons.point_of_sale_outlined),
                          selectedIcon: Icon(Icons.point_of_sale_rounded, color: colorScheme.primary),
                          label: const Text('Kasir'),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.inventory_2_outlined),
                          selectedIcon: Icon(Icons.inventory_2_rounded, color: colorScheme.primary),
                          label: const Text('Produk'),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.receipt_long_outlined),
                          selectedIcon: Icon(Icons.receipt_long_rounded, color: colorScheme.primary),
                          label: const Text('Riwayat'),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.bar_chart_outlined),
                          selectedIcon: Icon(Icons.bar_chart_rounded, color: colorScheme.primary),
                          label: const Text('Laporan'),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.settings_outlined),
                          selectedIcon: Icon(Icons.settings_rounded, color: colorScheme.primary),
                          label: const Text('Atur'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(child: pages),
                          AdBannerWidget(isPro: isPro),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return Scaffold(
              body: pages,
              bottomNavigationBar: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AdBannerWidget(isPro: isPro),
                  NavigationBar(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
                    destinations: [
                      NavigationDestination(
                        icon: const Icon(Icons.point_of_sale_outlined),
                        selectedIcon: Icon(Icons.point_of_sale_rounded, color: colorScheme.primary),
                        label: 'Kasir',
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.inventory_2_outlined),
                        selectedIcon: Icon(Icons.inventory_2_rounded, color: colorScheme.primary),
                        label: 'Produk',
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.receipt_long_outlined),
                        selectedIcon: Icon(Icons.receipt_long_rounded, color: colorScheme.primary),
                        label: 'Riwayat',
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.bar_chart_outlined),
                        selectedIcon: Icon(Icons.bar_chart_rounded, color: colorScheme.primary),
                        label: 'Laporan',
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings_rounded, color: colorScheme.primary),
                        label: 'Atur',
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
