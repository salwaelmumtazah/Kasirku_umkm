import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/image_helper.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/product.dart';

class ProductFormSheet extends StatefulWidget {
  final Product? product;
  final List<String> existingCategories;
  final String? initialCategory;
  final Future<void> Function(String savedName, String savedCategory) onSaved;

  const ProductFormSheet({
    super.key,
    this.product,
    this.existingCategories = const [],
    this.initialCategory,
    required this.onSaved,
  });

  @override
  State<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;

  String? _imagePath;
  bool _isSaving = false;

  static const _defaultCategories = ['Sembako', 'Minuman', 'Makanan', 'Snack', 'Umum'];

  List<String> get _categoryOptions {
    final map = <String, String>{};
    for (final c in [..._defaultCategories, ...widget.existingCategories]) {
      final norm = normalizeCategory(c);
      map.putIfAbsent(norm.toLowerCase(), () => norm);
    }
    return map.values.toList();
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    final startCat = widget.product?.category ?? widget.initialCategory ?? 'Umum';
    _categoryController = TextEditingController(text: normalizeCategory(startCat));
    _priceController = TextEditingController(
      text: widget.product != null ? widget.product!.price.toString() : '',
    );
    _stockController = TextEditingController(
      text: widget.product != null ? widget.product!.stock.toString() : '10',
    );
    _imagePath = widget.product?.imagePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  void _showImageOptions() {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text(
              'Foto Produk',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_rounded, color: colorScheme.primary),
              title: const Text('Ambil dari Kamera'),
              onTap: () async {
                Navigator.pop(ctx);
                final path = await ImageHelper.pickAndSaveImage(
                  context: context,
                  source: ImageSource.camera,
                );
                if (path != null && mounted) {
                  setState(() => _imagePath = path);
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: colorScheme.primary),
              title: const Text('Pilih dari Galeri'),
              onTap: () async {
                Navigator.pop(ctx);
                final path = await ImageHelper.pickAndSaveImage(
                  context: context,
                  source: ImageSource.gallery,
                );
                if (path != null && mounted) {
                  setState(() => _imagePath = path);
                }
              },
            ),
            if (_imagePath != null)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
                title: Text('Hapus Foto', style: TextStyle(color: colorScheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _imagePath = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    final name = _nameController.text.trim();
    final rawCategory = normalizeCategory(_categoryController.text);

    // Cocokkan dengan kategori yang sudah ada secara case-insensitive
    final existingMatch = _categoryOptions.where(
      (c) => c.toLowerCase() == rawCategory.toLowerCase(),
    );
    final category = existingMatch.isNotEmpty ? existingMatch.first : rawCategory;

    final price = int.tryParse(_priceController.text.trim()) ?? 0;
    final stock = int.tryParse(_stockController.text.trim()) ?? 0;

    setState(() => _isSaving = true);
    try {
      if (widget.product == null) {
        await DatabaseHelper.instance.insertProduct(
          Product(
            name: name,
            category: category,
            price: price,
            stock: stock,
            imagePath: _imagePath,
          ),
        );
      } else {
        if (widget.product!.imagePath != null &&
            widget.product!.imagePath != _imagePath) {
          ImageHelper.deleteImageFile(widget.product!.imagePath);
        }
        await DatabaseHelper.instance.updateProduct(
          widget.product!.copyWith(
            name: name,
            category: category,
            price: price,
            stock: stock,
            imagePath: _imagePath,
            clearImage: _imagePath == null,
          ),
        );
      }

      await widget.onSaved(name, category);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan produk: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEdit = widget.product != null;
    final activeCategory = normalizeCategory(_categoryController.text).toLowerCase();

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 16,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEdit ? 'Edit Produk' : 'Tambah Produk',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),
                  Center(
                    child: GestureDetector(
                      onTap: _showImageOptions,
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: _imagePath != null && File(_imagePath!).existsSync()
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.file(File(_imagePath!), fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    color: colorScheme.primary,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Foto',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Nama Produk',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Contoh: Kopi Susu Gula Aren'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Nama produk wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Kategori / Judul Kelompok Produk',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _categoryController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'Pilih di bawah atau ketik kategori baru',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _categoryOptions.map((c) {
                      final selected = c.toLowerCase() == activeCategory;
                      return ChoiceChip(
                        label: Text(c, style: const TextStyle(fontSize: 12)),
                        selected: selected,
                        selectedColor: colorScheme.primaryContainer,
                        onSelected: (_) {
                          setState(() {
                            _categoryController.text = c;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Harga (Rp)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _priceController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(
                                prefixText: 'Rp ',
                                hintText: '15000',
                              ),
                              validator: (v) {
                                final p = int.tryParse(v?.trim() ?? '');
                                if (p == null || p <= 0) return 'Harga > 0';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Stok',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _stockController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(hintText: '10'),
                              validator: (v) {
                                final s = int.tryParse(v?.trim() ?? '');
                                if (s == null || s < 0) return 'Stok >= 0';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(isEdit ? 'Simpan Perubahan' : 'Tambah Produk'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
