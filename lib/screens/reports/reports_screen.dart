import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/receipt_exporter.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/product.dart';
import '../../data/models/sale_transaction.dart';

enum _ReportPeriod {
  today('Hari Ini'),
  week('7 Hari'),
  month('Bulan Ini');

  final String label;
  const _ReportPeriod(this.label);
}

class ReportsScreen extends StatefulWidget {
  final List<Product> products;
  final int refreshToken;

  const ReportsScreen({
    super.key,
    required this.products,
    required this.refreshToken,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _ReportPeriod _period = _ReportPeriod.today;
  SalesReportSummary? _summary;
  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  void didUpdateWidget(covariant ReportsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadReport();
    }
  }

  DateTime _fromDate() {
    final now = DateTime.now();
    switch (_period) {
      case _ReportPeriod.today:
        return DateTime(now.year, now.month, now.day);
      case _ReportPeriod.week:
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      case _ReportPeriod.month:
        return DateTime(now.year, now.month, 1);
    }
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final report = await DatabaseHelper.instance.getSalesReport(from: _fromDate());
    if (mounted) {
      setState(() {
        _summary = report;
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadReportCsv() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final txs = await DatabaseHelper.instance.getTransactions(from: _fromDate());
      if (txs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Belum ada transaksi untuk diunduh pada periode ini'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final result = await ReceiptExporter.saveHistoryCsv(
        transactions: txs,
        periodLabel: _period.label,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Laporan diunduh: ${result.displayLocation}'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Bagikan',
            onPressed: () {
              ReceiptExporter.shareFile(
                filePath: result.filePath,
                subject: 'Laporan Penjualan ${_period.label}',
              );
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunduh laporan: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lowStockProducts = widget.products.where((p) => p.stock <= 5).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Penjualan'),
        actions: [
          IconButton(
            tooltip: 'Unduh Laporan (CSV)',
            onPressed: _isExporting ? null : _downloadReportCsv,
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip(_ReportPeriod.today, colorScheme),
                  const SizedBox(width: 8),
                  _chip(_ReportPeriod.week, colorScheme),
                  const SizedBox(width: 8),
                  _chip(_ReportPeriod.month, colorScheme),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading || _summary == null
                ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                : RefreshIndicator(
                    onRefresh: _loadReport,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 920),
                        child: ListView(
                          padding: const EdgeInsets.all(14),
                          children: [
                            // Omzet Utama
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [colorScheme.primary, colorScheme.secondary],
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Omzet (${_period.label})',
                                    style: TextStyle(
                                      color: colorScheme.onPrimary.withValues(alpha: 0.8),
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    formatRupiah(_summary!.totalRevenue),
                                    style: TextStyle(
                                      color: colorScheme.onPrimary,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 24,
                                    runSpacing: 8,
                                    children: [
                                      _miniStat(
                                        'Transaksi',
                                        '${_summary!.totalTransactions}',
                                        colorScheme.onPrimary,
                                      ),
                                      _miniStat(
                                        'Item Terjual',
                                        '${_summary!.totalItemsSold}',
                                        colorScheme.onPrimary,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Kartu Responsif (1 kolom HP, 2 kolom Tablet/Desktop)
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth >= 640;
                                final paymentCard = _buildPaymentBreakdownCard(colorScheme);
                                final topCard = _buildTopProductsCard(colorScheme);

                                if (isWide) {
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: paymentCard),
                                      const SizedBox(width: 14),
                                      Expanded(child: topCard),
                                    ],
                                  );
                                }
                                return Column(
                                  children: [
                                    paymentCard,
                                    const SizedBox(height: 14),
                                    topCard,
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 14),

                            // Peringatan Stok Menipis
                            if (lowStockProducts.isNotEmpty)
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            color: Colors.orange.shade800,
                                          ),
                                          const SizedBox(width: 6),
                                          const Text(
                                            'Stok Menipis (<= 5)',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      ...lowStockProducts.map(
                                        (p) => Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(child: Text(p.name)),
                                              Text(
                                                'Sisa ${p.stock}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: colorScheme.error,
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
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBreakdownCard(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hasil Pembayaran per Metode',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...PaymentMethod.values.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(m.label),
                    Text(
                      formatRupiah(_summary!.revenueByMethod[m] ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductsCard(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Produk Terlaris',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (_summary!.topProducts.isEmpty)
              Text(
                'Belum ada data penjualan.',
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
              )
            else
              ..._summary!.topProducts.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.productName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${item.totalQty}x • ${formatRupiah(item.totalRevenue)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
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
  }

  Widget _miniStat(String label, String value, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: textColor.withValues(alpha: 0.78), fontSize: 12)),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _chip(_ReportPeriod value, ColorScheme colorScheme) {
    final selected = _period == value;
    return ChoiceChip(
      label: Text(value.label),
      selected: selected,
      selectedColor: colorScheme.primaryContainer,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
      ),
      onSelected: (_) {
        setState(() => _period = value);
        _loadReport();
      },
    );
  }
}
