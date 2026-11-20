import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/utils/formatters.dart';
import '../models/product.dart';
import '../models/sale_transaction.dart';

class SalesReportSummary {
  final int totalRevenue;
  final int totalTransactions;
  final int totalItemsSold;
  final Map<PaymentMethod, int> revenueByMethod;
  final List<TopProductStat> topProducts;

  const SalesReportSummary({
    required this.totalRevenue,
    required this.totalTransactions,
    required this.totalItemsSold,
    required this.revenueByMethod,
    required this.topProducts,
  });
}

class TopProductStat {
  final String productName;
  final int totalQty;
  final int totalRevenue;

  const TopProductStat({
    required this.productName,
    required this.totalQty,
    required this.totalRevenue,
  });
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('kasirku_offline_v2.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, fileName);

    return openDatabase(
      fullPath,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'Umum',
        price INTEGER NOT NULL,
        stock INTEGER NOT NULL DEFAULT 0,
        image_path TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT NOT NULL,
        created_at TEXT NOT NULL,
        subtotal_amount INTEGER NOT NULL,
        discount_amount INTEGER NOT NULL DEFAULT 0,
        total_amount INTEGER NOT NULL,
        cash_received INTEGER NOT NULL,
        change_amount INTEGER NOT NULL,
        payment_method TEXT NOT NULL DEFAULT 'cash'
      )
    ''');

    await db.execute('''
      CREATE TABLE transaction_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        product_id INTEGER,
        product_name TEXT NOT NULL,
        unit_price INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        subtotal INTEGER NOT NULL,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE
      )
    ''');

    await _createSettingsTable(db);

    // Data produk awal siap pakai
    final starterProducts = [
      {'name': 'Beras Medium 1 kg', 'category': 'Sembako', 'price': 14000, 'stock': 25},
      {'name': 'Minyak Goreng 1 L', 'category': 'Sembako', 'price': 18000, 'stock': 20},
      {'name': 'Gula Pasir 1 kg', 'category': 'Sembako', 'price': 17500, 'stock': 30},
      {'name': 'Telur Ayam 1 kg', 'category': 'Sembako', 'price': 28000, 'stock': 15},
      {'name': 'Kopi Tubruk Panas', 'category': 'Minuman', 'price': 5000, 'stock': 50},
      {'name': 'Es Teh Manis Jumbo', 'category': 'Minuman', 'price': 4000, 'stock': 60},
      {'name': 'Air Mineral 600ml', 'category': 'Minuman', 'price': 3500, 'stock': 48},
      {'name': 'Mie Goreng Instan', 'category': 'Makanan', 'price': 3500, 'stock': 40},
    ];

    for (final item in starterProducts) {
      await db.insert('products', item);
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createSettingsTable(db);
    }
  }

  Future<void> _createSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // ==========================================
  // PENGATURAN LOKAL (SQLITE DURABLE STORE)
  // ==========================================

  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    await _createSettingsTable(db);
    final rows = await db.query('app_settings');
    return {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }

  Future<void> saveSettings(Map<String, String> values) async {
    final db = await database;
    await _createSettingsTable(db);
    await db.transaction((txn) async {
      for (final entry in values.entries) {
        await txn.insert(
          'app_settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  // ==========================================
  // PRODUK
  // ==========================================

  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final maps = await db.query('products', orderBy: 'category ASC, name ASC, id DESC');
    return maps.map((m) {
      final p = Product.fromMap(m);
      return p.copyWith(category: normalizeCategory(p.category));
    }).toList();
  }

  Future<int> insertProduct(Product product) async {
    final db = await database;
    final normalized = product.copyWith(
      name: product.name.trim(),
      category: normalizeCategory(product.category),
    );
    return db.insert('products', normalized.toMap());
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    final normalized = product.copyWith(
      name: product.name.trim(),
      category: normalizeCategory(product.category),
    );
    return db.update(
      'products',
      normalized.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================
  // TRANSAKSI & CHECKOUT ATOMIK
  // ==========================================

  Future<SaleTransaction> saveTransaction(SaleTransaction tx) async {
    final db = await database;

    final int txId = await db.transaction((txn) async {
      final insertedTxId = await txn.insert('transactions', tx.toMap());

      for (final item in tx.items) {
        await txn.insert('transaction_items', item.toMap(insertedTxId));

        if (item.productId != null) {
          await txn.rawUpdate(
            '''
            UPDATE products
            SET stock = CASE WHEN stock >= ? THEN stock - ? ELSE 0 END
            WHERE id = ?
            ''',
            [item.quantity, item.quantity, item.productId],
          );
        }
      }

      return insertedTxId;
    });

    return SaleTransaction(
      id: txId,
      invoiceNumber: tx.invoiceNumber,
      createdAt: tx.createdAt,
      subtotalAmount: tx.subtotalAmount,
      discountAmount: tx.discountAmount,
      totalAmount: tx.totalAmount,
      cashReceived: tx.cashReceived,
      changeAmount: tx.changeAmount,
      paymentMethod: tx.paymentMethod,
      items: tx.items,
    );
  }

  Future<List<SaleTransaction>> getTransactions({DateTime? from, DateTime? to}) async {
    final db = await database;

    String? where;
    List<Object?>? whereArgs;

    if (from != null && to != null) {
      where = 'created_at >= ? AND created_at <= ?';
      whereArgs = [from.toIso8601String(), to.toIso8601String()];
    } else if (from != null) {
      where = 'created_at >= ?';
      whereArgs = [from.toIso8601String()];
    }

    final txMaps = await db.query(
      'transactions',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );

    final List<SaleTransaction> result = [];
    for (final txMap in txMaps) {
      final txId = txMap['id'] as int;
      final itemMaps = await db.query(
        'transaction_items',
        where: 'transaction_id = ?',
        whereArgs: [txId],
      );
      final items = itemMaps.map(SaleTransactionItem.fromMap).toList();
      result.add(SaleTransaction.fromMap(txMap, items: items));
    }

    return result;
  }

  Future<void> deleteTransaction(int transactionId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'transaction_items',
        where: 'transaction_id = ?',
        whereArgs: [transactionId],
      );
      await txn.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [transactionId],
      );
    });
  }

  // ==========================================
  // LAPORAN PENJUALAN OFFLINE
  // ==========================================

  Future<SalesReportSummary> getSalesReport({DateTime? from, DateTime? to}) async {
    final transactions = await getTransactions(from: from, to: to);

    int totalRevenue = 0;
    int totalItemsSold = 0;
    final Map<PaymentMethod, int> revenueByMethod = {
      PaymentMethod.cash: 0,
      PaymentMethod.qris: 0,
      PaymentMethod.transfer: 0,
    };
    final Map<String, ({int qty, int revenue})> productStats = {};

    for (final tx in transactions) {
      totalRevenue += tx.totalAmount;
      revenueByMethod[tx.paymentMethod] =
          (revenueByMethod[tx.paymentMethod] ?? 0) + tx.totalAmount;

      for (final item in tx.items) {
        totalItemsSold += item.quantity;
        final existing = productStats[item.productName];
        if (existing == null) {
          productStats[item.productName] = (
            qty: item.quantity,
            revenue: item.subtotal,
          );
        } else {
          productStats[item.productName] = (
            qty: existing.qty + item.quantity,
            revenue: existing.revenue + item.subtotal,
          );
        }
      }
    }

    final topProducts = productStats.entries
        .map(
          (e) => TopProductStat(
            productName: e.key,
            totalQty: e.value.qty,
            totalRevenue: e.value.revenue,
          ),
        )
        .toList()
      ..sort((a, b) => b.totalQty.compareTo(a.totalQty));

    return SalesReportSummary(
      totalRevenue: totalRevenue,
      totalTransactions: transactions.length,
      totalItemsSold: totalItemsSold,
      revenueByMethod: revenueByMethod,
      topProducts: topProducts.take(5).toList(),
    );
  }
}
