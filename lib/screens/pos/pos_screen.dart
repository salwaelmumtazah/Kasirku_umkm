import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/product.dart';
import '../../data/models/sale_transaction.dart';
import '../../services/ad_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/product_image.dart';
import 'cart_sheet.dart';
import 'payment_dialog.dart';
import 'receipt_dialog.dart';

class PosScreen extends StatefulWidget {
  final List<Product> products;
  final bool isLoading;
  final Map<int, CartItem> cart;
  final SettingsService settingsService;
  final void Function(Product) onAddToCart;
  final void Function(int) onDecrementFromCart;
  final VoidCallback onClearCart;
  final Future<void> Function() onTransactionSaved;
  final VoidCallback onOpenUpgrade;

  const PosScreen({
    super.key,
    required this.products,
    required this.isLoading,
    required this.cart,
    required this.settingsService,
    required this.onAddToCart,
    required this.onDecrementFromCart,
    required this.onClearCart,
    required this.onTransactionSaved,
    required this.onOpenUpgrade,
  });

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'Semua';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _categories {
    final map = <String, String>{};
    for (final p in widget.products) {
      final norm = normalizeCategory(p.category);
      map.putIfAbsent(norm.toLowerCase(), () => norm);
    }
    final sorted = map.values.toList()..sort();
    return ['Semua', ...sorted];
  }

  String get _effectiveSelectedCategory {
    final cats = _categories;
    final match = cats.where(
      (c) => c.toLowerCase() == _selectedCategory.toLowerCase(),
    );
    return match.isNotEmpty ? match.first : 'Semua';
  }

  List<Product> get _filteredProducts {
    final activeCategory = _effectiveSelectedCategory.toLowerCase();
    final q = _searchQuery.toLowerCase().trim();

    return widget.products.where((p) {
      final productCat = normalizeCategory(p.category).toLowerCase();
      final matchesCategory = activeCategory == 'semua' || productCat == activeCategory;
      final matchesQuery = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          productCat.contains(q);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  int get _totalItems =>
      widget.cart.values.fold(0, (sum, item) => sum + item.quantity);

  int get _totalPrice =>
      widget.cart.values.fold(0, (sum, item) => sum + item.subtotal);

  void _openCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CartSheet(
        cart: widget.cart,
        onAdd: widget.onAddToCart,
        onDecrement: widget.onDecrementFromCart,
        onClear: widget.onClearCart,
        onCheckout: _openPaymentDialog,
      ),
    );
  }

  Future<void> _openPaymentDialog() async {
    if (widget.cart.isEmpty) return;

    final savedTx = await showDialog<SaleTransaction>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PaymentDialog(
        cartItems: widget.cart.values.toList(),
        subtotal: _totalPrice,
      ),
    );

    if (savedTx == null || !mounted) return;

    widget.onClearCart();
    await widget.onTransactionSaved();

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReceiptDialog(
        transaction: savedTx,
        settingsService: widget.settingsService,
      ),
    );

    AdService.instance.onTransactionCompleted(
      isPro: widget.settingsService.isPro,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filtered = _filteredProducts;
    final categories = _categories;
    final activeCategory = _effectiveSelectedCategory;
    final isPro = widget.settingsService.isPro;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.storefront_rounded, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.settingsService.storeName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (isPro)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.gold,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium_rounded, size: 14, color: Colors.black87),
                  SizedBox(width: 4),
                  Text(
                    'PRO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            )
          else
            TextButton.icon(
              onPressed: widget.onOpenUpgrade,
              icon: const Icon(
                Icons.workspace_premium_outlined,
                size: 16,
                color: Color(0xFFFFE082),
              ),
              label: const Text(
                'Pro',
                style: TextStyle(color: Color(0xFFFFE082), fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search & Kategori
          Container(
            color: colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau kategori produk...',
                    prefixIcon: Icon(Icons.search_rounded, color: colorScheme.primary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final selected = cat.toLowerCase() == activeCategory.toLowerCase();
                      return ChoiceChip(
                        label: Text(cat),
                        selected: selected,
                        selectedColor: colorScheme.primaryContainer,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          color: selected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                        ),
                        onSelected: (_) => setState(() => _selectedCategory = cat),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Grid Produk Responsif
          Expanded(
            child: widget.isLoading
                ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                : filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _searchQuery.isNotEmpty
                                ? 'Produk "$_searchQuery" tidak ditemukan'
                                : 'Belum ada produk pada kategori "$activeCategory"',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final int crossAxisCount;
                          if (width >= 1080) {
                            crossAxisCount = 5;
                          } else if (width >= 820) {
                            crossAxisCount = 4;
                          } else if (width >= 560) {
                            crossAxisCount = 3;
                          } else {
                            crossAxisCount = 2;
                          }

                          return GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisExtent: 256,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final product = filtered[index];
                              final inCart = widget.cart[product.id]?.quantity ?? 0;
                              final isOutOfStock = product.stock <= 0;

                              return Card(
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: isOutOfStock ? null : () => widget.onAddToCart(product),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Stack(
                                        children: [
                                          ProductImage(
                                            imagePath: product.imagePath,
                                            width: double.infinity,
                                            height: 102,
                                            iconSize: 34,
                                          ),
                                          if (inCart > 0)
                                            Positioned(
                                              top: 6,
                                              right: 6,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.primary,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  'x$inCart',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: colorScheme.onPrimary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          Positioned(
                                            bottom: 6,
                                            left: 6,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isOutOfStock
                                                    ? Colors.red.shade700
                                                    : Colors.black.withValues(alpha: 0.65),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                isOutOfStock ? 'Habis' : 'Stok: ${product.stock}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(9),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                normalizeCategory(product.category),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: colorScheme.primary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                product.name,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  height: 1.2,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const Spacer(),
                                              Text(
                                                formatRupiah(product.price),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w900,
                                                  color: colorScheme.primary,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              SizedBox(
                                                width: double.infinity,
                                                height: 34,
                                                child: ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    padding: EdgeInsets.zero,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(9),
                                                    ),
                                                  ),
                                                  onPressed: isOutOfStock
                                                      ? null
                                                      : () => widget.onAddToCart(product),
                                                  icon: const Icon(Icons.add_rounded, size: 16),
                                                  label: Text(
                                                    isOutOfStock ? 'Habis' : 'Tambah',
                                                    style: const TextStyle(fontSize: 12),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),

          // Sticky Checkout Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _totalItems > 0 ? _openCartSheet : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _totalItems > 0
                              ? '$_totalItems item di keranjang'
                              : 'Keranjang kosong',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          formatRupiah(_totalPrice),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: _totalItems > 0
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _totalItems > 0 ? _openCartSheet : null,
                  icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 18),
                  label: const Text('Bayar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
