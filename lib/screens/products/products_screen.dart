import 'package:flutter/material.dart';

import '../../core/constants/monetization_config.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/image_helper.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/product.dart';
import '../../widgets/product_image.dart';
import 'product_form_sheet.dart';

class ProductsScreen extends StatefulWidget {
  final List<Product> products;
  final bool isLoading;
  final bool isPro;
  final Future<void> Function() onRefresh;
  final void Function(int deletedId) onDeleted;
  final VoidCallback onOpenUpgrade;

  const ProductsScreen({
    super.key,
    required this.products,
    required this.isLoading,
    required this.isPro,
    required this.onRefresh,
    required this.onDeleted,
    required this.onOpenUpgrade,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
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

  String get _effectiveCategory {
    final cats = _categories;
    final match = cats.where(
      (c) => c.toLowerCase() == _selectedCategory.toLowerCase(),
    );
    return match.isNotEmpty ? match.first : 'Semua';
  }

  Map<String, List<Product>> get _groupedProducts {
    final activeCat = _effectiveCategory.toLowerCase();
    final q = _searchQuery.toLowerCase().trim();

    final filtered = widget.products.where((p) {
      final cat = normalizeCategory(p.category);
      final matchesCat = activeCat == 'semua' || cat.toLowerCase() == activeCat;
      final matchesQuery = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          cat.toLowerCase().contains(q);
      return matchesCat && matchesQuery;
    }).toList();

    final grouped = <String, List<Product>>{};
    for (final p in filtered) {
      final cat = normalizeCategory(p.category);
      grouped.putIfAbsent(cat, () => []).add(p);
    }

    final sortedKeys = grouped.keys.toList()..sort();
    return {for (final k in sortedKeys) k: grouped[k]!};
  }

  void _openForm(BuildContext context, {Product? product, String? initialCategory}) {
    if (product == null &&
        !widget.isPro &&
        widget.products.length >= MonetizationConfig.freeProductLimit) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Batas Produk Versi Gratis'),
          content: const Text(
            'Versi gratis dibatasi maksimal ${MonetizationConfig.freeProductLimit} produk. '
            'Upgrade ke Kasirku Pro untuk produk tanpa batas dan bebas iklan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Nanti'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.onOpenUpgrade();
              },
              child: const Text('Upgrade Pro'),
            ),
          ],
        ),
      );
      return;
    }

    final existingCats = _categories.where((c) => c != 'Semua').toList();
    final prefillCategory = initialCategory ??
        (_effectiveCategory != 'Semua' ? _effectiveCategory : null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductFormSheet(
        product: product,
        existingCategories: existingCats,
        initialCategory: prefillCategory,
        onSaved: (savedName, savedCategory) async {
          await widget.onRefresh();
          if (mounted) {
            ScaffoldMessenger.of(this.context).showSnackBar(
              SnackBar(
                content: Text(
                  product == null
                      ? '"$savedName" ditambahkan ke kategori "$savedCategory"'
                      : '"$savedName" diperbarui di kategori "$savedCategory"',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Produk?'),
        content: Text('Yakin ingin menghapus "${product.name}" secara permanen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () async {
              Navigator.pop(ctx);
              if (product.id != null) {
                ImageHelper.deleteImageFile(product.imagePath);
                await DatabaseHelper.instance.deleteProduct(product.id!);
                widget.onDeleted(product.id!);
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categories = _categories;
    final activeCategory = _effectiveCategory;
    final grouped = _groupedProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Produk'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                widget.isPro
                    ? '${widget.products.length} Produk'
                    : '${widget.products.length}/${MonetizationConfig.freeProductLimit}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Kategori
          Container(
            color: colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari produk atau kategori...',
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

          // Daftar Produk Dikelompokkan Berdasarkan Judul Kategori
          Expanded(
            child: widget.isLoading
                ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                : grouped.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Produk "$_searchQuery" tidak ditemukan'
                                  : 'Belum ada produk',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _openForm(context),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Tambah Produk'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: widget.onRefresh,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 920),
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(14, 14, 14, 88),
                              children: grouped.entries.map((entry) {
                                final categoryTitle = entry.key;
                                final items = entry.value;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Judul Kelompok / Kategori Produk
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 4,
                                            height: 18,
                                            decoration: BoxDecoration(
                                              color: colorScheme.primary,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '$categoryTitle (${items.length})',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                          TextButton.icon(
                                            style: TextButton.styleFrom(
                                              visualDensity: VisualDensity.compact,
                                            ),
                                            onPressed: () => _openForm(
                                              context,
                                              initialCategory: categoryTitle,
                                            ),
                                            icon: const Icon(Icons.add_rounded, size: 16),
                                            label: const Text('Tambah', style: TextStyle(fontSize: 12)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ...items.map(
                                      (product) => Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: _buildProductCard(context, product, colorScheme),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Produk'),
      ),
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    Product product,
    ColorScheme colorScheme,
  ) {
    final lowStock = product.stock <= 5;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ProductImage(
              imagePath: product.imagePath,
              width: 58,
              height: 58,
              iconSize: 28,
              borderRadius: BorderRadius.circular(12),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatRupiah(product.price),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stok: ${product.stock}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: lowStock ? colorScheme.error : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit_outlined, color: colorScheme.primary),
              onPressed: () => _openForm(context, product: product),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
              onPressed: () => _confirmDelete(context, product),
            ),
          ],
        ),
      ),
    );
  }
}
