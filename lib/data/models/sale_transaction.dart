enum PaymentMethod {
  cash('Tunai'),
  qris('QRIS'),
  transfer('Transfer');

  final String label;
  const PaymentMethod(this.label);

  static PaymentMethod fromName(String? value) {
    return PaymentMethod.values.firstWhere(
      (m) => m.name == value,
      orElse: () => PaymentMethod.cash,
    );
  }
}

class SaleTransactionItem {
  final int? id;
  final int? transactionId;
  final int? productId;
  final String productName;
  final int unitPrice;
  final int quantity;
  final int subtotal;

  const SaleTransactionItem({
    this.id,
    this.transactionId,
    this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
  });

  Map<String, dynamic> toMap(int txId) {
    return {
      if (id != null) 'id': id,
      'transaction_id': txId,
      'product_id': productId,
      'product_name': productName,
      'unit_price': unitPrice,
      'quantity': quantity,
      'subtotal': subtotal,
    };
  }

  factory SaleTransactionItem.fromMap(Map<String, dynamic> map) {
    return SaleTransactionItem(
      id: map['id'] as int?,
      transactionId: map['transaction_id'] as int?,
      productId: map['product_id'] as int?,
      productName: map['product_name'] as String,
      unitPrice: map['unit_price'] as int,
      quantity: map['quantity'] as int,
      subtotal: map['subtotal'] as int,
    );
  }
}

class SaleTransaction {
  final int? id;
  final String invoiceNumber;
  final DateTime createdAt;
  final int subtotalAmount;
  final int discountAmount;
  final int totalAmount;
  final int cashReceived;
  final int changeAmount;
  final PaymentMethod paymentMethod;
  final List<SaleTransactionItem> items;

  const SaleTransaction({
    this.id,
    required this.invoiceNumber,
    required this.createdAt,
    required this.subtotalAmount,
    this.discountAmount = 0,
    required this.totalAmount,
    required this.cashReceived,
    required this.changeAmount,
    required this.paymentMethod,
    this.items = const [],
  });

  int get totalItemsCount => items.fold(0, (sum, i) => sum + i.quantity);

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_number': invoiceNumber,
      'created_at': createdAt.toIso8601String(),
      'subtotal_amount': subtotalAmount,
      'discount_amount': discountAmount,
      'total_amount': totalAmount,
      'cash_received': cashReceived,
      'change_amount': changeAmount,
      'payment_method': paymentMethod.name,
    };
  }

  factory SaleTransaction.fromMap(
    Map<String, dynamic> map, {
    List<SaleTransactionItem> items = const [],
  }) {
    return SaleTransaction(
      id: map['id'] as int?,
      invoiceNumber: map['invoice_number'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      subtotalAmount: map['subtotal_amount'] as int,
      discountAmount: (map['discount_amount'] as int?) ?? 0,
      totalAmount: map['total_amount'] as int,
      cashReceived: map['cash_received'] as int,
      changeAmount: map['change_amount'] as int,
      paymentMethod: PaymentMethod.fromName(map['payment_method'] as String?),
      items: items,
    );
  }
}

