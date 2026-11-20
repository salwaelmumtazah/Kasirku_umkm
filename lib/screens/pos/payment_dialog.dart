import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/formatters.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/sale_transaction.dart';

class PaymentDialog extends StatefulWidget {
  final List<CartItem> cartItems;
  final int subtotal;

  const PaymentDialog({
    super.key,
    required this.cartItems,
    required this.subtotal,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  late final TextEditingController _cashController;
  final TextEditingController _discountController = TextEditingController();

  PaymentMethod _paymentMethod = PaymentMethod.cash;
  int _discount = 0;
  int _cashReceived = 0;
  bool _isSaving = false;

  int get _totalBill => (widget.subtotal - _discount).clamp(0, widget.subtotal);
  int get _change => _cashReceived - _totalBill;
  bool get _isSufficient =>
      _paymentMethod != PaymentMethod.cash || _change >= 0;

  @override
  void initState() {
    super.initState();
    _cashReceived = widget.subtotal;
    _cashController = TextEditingController(text: widget.subtotal.toString());
  }

  @override
  void dispose() {
    _cashController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _setCash(int amount) {
    setState(() {
      _cashReceived = amount;
      _cashController.text = amount.toString();
    });
  }

  Future<void> _confirmPayment() async {
    if (!_isSufficient || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final effectiveCash =
          _paymentMethod == PaymentMethod.cash ? _cashReceived : _totalBill;
      final effectiveChange =
          _paymentMethod == PaymentMethod.cash ? (_cashReceived - _totalBill) : 0;

      final tx = SaleTransaction(
        invoiceNumber: generateInvoiceNumber(now),
        createdAt: now,
        subtotalAmount: widget.subtotal,
        discountAmount: _discount,
        totalAmount: _totalBill,
        cashReceived: effectiveCash,
        changeAmount: effectiveChange,
        paymentMethod: _paymentMethod,
        items: widget.cartItems
            .map(
              (c) => SaleTransactionItem(
                productId: c.product.id,
                productName: c.product.name,
                unitPrice: c.product.price,
                quantity: c.quantity,
                subtotal: c.subtotal,
              ),
            )
            .toList(),
      );

      final savedTx = await DatabaseHelper.instance.saveTransaction(tx);
      if (mounted) {
        Navigator.pop(context, savedTx);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan transaksi: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      title: Row(
        children: [
          Icon(Icons.payments_rounded, color: colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total Tagihan
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _discount > 0
                          ? 'Total Setelah Diskon (${formatRupiah(_discount)}):'
                          : 'Total Tagihan:',
                      style: TextStyle(fontSize: 12, color: colorScheme.onPrimaryContainer),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatRupiah(_totalBill),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Metode Pembayaran (responsif dengan Wrap ChoiceChip)
              const Text(
                'Metode Pembayaran',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: PaymentMethod.values.map((m) {
                  final selected = _paymentMethod == m;
                  return ChoiceChip(
                    label: Text(m.label),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        _paymentMethod = m;
                        if (_paymentMethod != PaymentMethod.cash) {
                          _cashReceived = _totalBill;
                          _cashController.text = _totalBill.toString();
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Diskon Opsional
              const Text(
                'Diskon (Opsional)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _discountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  prefixText: 'Rp ',
                  hintText: '0',
                  isDense: true,
                ),
                onChanged: (val) {
                  final parsed = int.tryParse(val) ?? 0;
                  setState(() {
                    _discount = parsed.clamp(0, widget.subtotal);
                    if (_paymentMethod != PaymentMethod.cash) {
                      _cashReceived = _totalBill;
                      _cashController.text = _totalBill.toString();
                    }
                  });
                },
              ),
              const SizedBox(height: 14),

              if (_paymentMethod == PaymentMethod.cash) ...[
                const Text(
                  'Uang Diterima',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _cashController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    prefixStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                    hintText: '0',
                    isDense: true,
                  ),
                  onChanged: (val) {
                    setState(() => _cashReceived = int.tryParse(val) ?? 0);
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ActionChip(
                      label: const Text('Uang Pas', style: TextStyle(fontSize: 12)),
                      onPressed: () => _setCash(_totalBill),
                    ),
                    if (_totalBill <= 20000)
                      ActionChip(
                        label: const Text('20.000', style: TextStyle(fontSize: 12)),
                        onPressed: () => _setCash(20000),
                      ),
                    if (_totalBill <= 50000)
                      ActionChip(
                        label: const Text('50.000', style: TextStyle(fontSize: 12)),
                        onPressed: () => _setCash(50000),
                      ),
                    if (_totalBill <= 100000)
                      ActionChip(
                        label: const Text('100.000', style: TextStyle(fontSize: 12)),
                        onPressed: () => _setCash(100000),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isSufficient
                        ? colorScheme.primaryContainer.withValues(alpha: 0.7)
                        : colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isSufficient ? 'Kembalian:' : 'Kurang:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isSufficient
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onErrorContainer,
                        ),
                      ),
                      Text(
                        formatRupiah(_change.abs()),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: _isSufficient
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Pastikan pembayaran ${_paymentMethod.label} sebesar ${formatRupiah(_totalBill)} sudah diterima.',
                    style: TextStyle(fontSize: 13, color: colorScheme.onPrimaryContainer),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: (_isSufficient && !_isSaving) ? _confirmPayment : null,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Konfirmasi'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
