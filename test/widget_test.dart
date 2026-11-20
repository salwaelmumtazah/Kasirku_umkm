import 'package:flutter_test/flutter_test.dart';
import 'package:kasirku/core/constants/monetization_config.dart';
import 'package:kasirku/core/theme/app_theme.dart';
import 'package:kasirku/core/utils/formatters.dart';
import 'package:kasirku/data/models/cart_item.dart';
import 'package:kasirku/data/models/product.dart';
import 'package:kasirku/data/models/sale_transaction.dart';

void main() {
  test('Rupiah formatter formats positive, zero, and negative values', () {
    expect(formatRupiah(15000), 'Rp 15.000');
    expect(formatRupiah(0), 'Rp 0');
    expect(formatRupiah(1250000), 'Rp 1.250.000');
    expect(formatRupiah(-5000), '-Rp 5.000');
  });

  test('Indonesian day, date, time and category normalizer work correctly', () {
    final dt = DateTime(2026, 11, 20, 19, 46, 5); // Jumat
    expect(formatDayName(dt), 'Jumat');
    expect(formatDayDate(dt), 'Jumat, 20 Nov 2026');
    expect(formatDayDateTime(dt), 'Jumat, 20 Nov 2026 • 19:46');
    expect(formatTimeWithSeconds(dt), '19:46:05');

    expect(normalizeCategory('  minuman dingin  '), 'Minuman Dingin');
    expect(normalizeCategory(''), 'Umum');
    expect(normalizeCategory('SEMBAKO'), 'Sembako');
  });

  test('Product and CartItem calculations work correctly', () {
    const product = Product(
      id: 1,
      name: 'Beras Medium 1 kg',
      category: 'Sembako',
      price: 14000,
      stock: 20,
    );
    final item = CartItem(product: product, quantity: 3);
    expect(item.subtotal, 42000);

    final mapped = Product.fromMap(product.toMap());
    expect(mapped.name, product.name);
    expect(mapped.category, 'Sembako');
    expect(mapped.stock, 20);
  });

  test('SaleTransaction model serialization works', () {
    final now = DateTime(2026, 11, 20, 14, 30);
    final tx = SaleTransaction(
      invoiceNumber: generateInvoiceNumber(now),
      createdAt: now,
      subtotalAmount: 28000,
      discountAmount: 3000,
      totalAmount: 25000,
      cashReceived: 50000,
      changeAmount: 25000,
      paymentMethod: PaymentMethod.cash,
      items: const [
        SaleTransactionItem(
          productId: 1,
          productName: 'Beras Medium 1 kg',
          unitPrice: 14000,
          quantity: 2,
          subtotal: 28000,
        ),
      ],
    );

    expect(tx.invoiceNumber, 'INV-20261120-143000');
    expect(tx.totalItemsCount, 2);

    final decoded = SaleTransaction.fromMap(tx.toMap(), items: tx.items);
    expect(decoded.totalAmount, 25000);
    expect(decoded.paymentMethod, PaymentMethod.cash);
  });

  test('Theme palettes and MonetizationConfig are properly configured', () {
    expect(AppThemeColor.fromName('ocean'), AppThemeColor.ocean);
    expect(AppThemeColor.fromName('unknown'), AppThemeColor.emerald);
    expect(
      MonetizationConfig.allProductIds,
      containsAll([
        MonetizationConfig.proLifetimeProductId,
        MonetizationConfig.proMonthlyProductId,
      ]),
    );
  });
}
