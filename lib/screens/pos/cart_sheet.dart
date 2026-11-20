import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/product.dart';
import '../../widgets/product_image.dart';

class CartSheet extends StatefulWidget {
  final Map<int, CartItem> cart;
  final void Function(Product) onAdd;
  final void Function(int) onDecrement;
  final VoidCallback onClear;
  final VoidCallback onCheckout;

  const CartSheet({
    super.key,
    required this.cart,
    required this.onAdd,
    required this.onDecrement,
    required this.onClear,
    required this.onCheckout,
  });

  @override
  State<CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<CartSheet> {
  int get _totalItems =>
      widget.cart.values.fold(0, (sum, item) => sum + item.quantity);

  int get _totalPrice =>
      widget.cart.values.fold(0, (sum, item) => sum + item.subtotal);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final items = widget.cart.values.toList();

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shopping_cart_rounded, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Keranjang',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_totalItems item',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (items.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          widget.onClear();
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Kosongkan',
                          style: TextStyle(color: colorScheme.error, fontSize: 13),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          'Keranjang masih kosong',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 15,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const Divider(height: 16),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Row(
                            children: [
                              ProductImage(
                                imagePath: item.product.imagePath,
                                width: 52,
                                height: 52,
                                iconSize: 24,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.product.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      formatRupiah(item.product.price),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    Text(
                                      formatRupiah(item.subtotal),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      item.quantity == 1
                                          ? Icons.delete_outline_rounded
                                          : Icons.remove_circle_outline_rounded,
                                      color: item.quantity == 1
                                          ? colorScheme.error
                                          : colorScheme.primary,
                                    ),
                                    onPressed: () {
                                      widget.onDecrement(item.product.id!);
                                      setState(() {});
                                      if (widget.cart.isEmpty) {
                                        Navigator.pop(context);
                                      }
                                    },
                                  ),
                                  Text(
                                    '${item.quantity}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.add_circle_outline_rounded,
                                      color: colorScheme.primary,
                                    ),
                                    onPressed: () {
                                      widget.onAdd(item.product);
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
              ),
              if (items.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Tagihan', style: TextStyle(fontSize: 15)),
                            Text(
                              formatRupiah(_totalPrice),
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onCheckout();
                            },
                            icon: const Icon(Icons.payment_rounded),
                            label: const Text('Lanjut Pembayaran'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
