import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/receipt_exporter.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/sale_transaction.dart';
import '../../services/settings_service.dart';
import '../pos/receipt_dialog.dart';

enum _HistoryFilter {
  today('Hari Ini'),
  week('7 Hari'),
  all('Semua');

  final String label;
  const _HistoryFilter(this.label);
}

class HistoryScreen extends StatefulWidget {
  final SettingsService settingsService;
  final int refreshToken;

  const HistoryScreen({
    super.key,
    required this.settingsService,
    required this.refreshToken,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.today;
  List<SaleTransaction> _transactions = [];
  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadTransactions();
    }
  }

  DateTime? _fromDate() {
    final now = DateTime.now();
    switch (_filter) {
      case _HistoryFilter.today:
        return DateTime(now.year, now.month, now.day);
      case _HistoryFilter.week:
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      case _HistoryFilter.all:
        return null;
    }
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    final list = await DatabaseHelper.instance.getTransactions(from: _fromDate());
    if (mounted) {
      setState(() {
        _transactions = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _exportHistoryCsv() async {
    if (_transactions.isEmpty || _isExporting) return;
    setState(() => _isExporting = true);
    try {
      final result = await ReceiptExporter.saveHistoryCsv(
        transactions: _transactions,
        periodLabel: _filter.label,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Riwayat diunduh: ${result.displayLocation}'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Bagikan',
            onPressed: () {
              ReceiptExporter.shareFile(
                filePath: result.filePath,
                subject: 'Riwayat Transaksi ${_filter.label}',
              );
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunduh riwayat: $e'),
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

  Future<void> _deleteTransaction(SaleTransaction tx) async {
    if (tx.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Riwayat Transaksi?'),
        content: Text('Transaksi ${tx.invoiceNumber} akan dihapus dari riwayat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteTransaction(tx.id!);
      _loadTransactions();
    }
  }

  Map<String, List<SaleTransaction>> _groupByDay(List<SaleTransaction> list) {
    final map = <String, List<SaleTransaction>>{};
    for (final tx in list) {
      final dayKey = formatDayDate(tx.createdAt);
      map.putIfAbsent(dayKey, () => []).add(tx);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final grouped = _groupByDay(_transactions);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        actions: [
          if (_transactions.isNotEmpty)
            IconButton(
              tooltip: 'Unduh Riwayat (CSV)',
              onPressed: _isExporting ? null : _exportHistoryCsv,
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
                  _chip(_HistoryFilter.today, colorScheme),
                  const SizedBox(width: 8),
                  _chip(_HistoryFilter.week, colorScheme),
                  const SizedBox(width: 8),
                  _chip(_HistoryFilter.all, colorScheme),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                : _transactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 64,
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Belum ada transaksi pada periode ini',
                              style: TextStyle(color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTransactions,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 820),
                            child: ListView(
                              padding: const EdgeInsets.all(14),
                              children: grouped.entries.map((entry) {
                                final dayHeader = entry.key;
                                final dayItems = entry.value;
                                final dayTotal = dayItems.fold<int>(
                                  0,
                                  (sum, tx) => sum + tx.totalAmount,
                                );

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header Hari & Tanggal
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            dayHeader,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                          Text(
                                            '${dayItems.length} trx • ${formatRupiah(dayTotal)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ...dayItems.map(
                                      (tx) => Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: _buildTxCard(context, tx, colorScheme),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
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
    );
  }

  Widget _buildTxCard(
    BuildContext context,
    SaleTransaction tx,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          showDialog<void>(
            context: context,
            builder: (_) => ReceiptDialog(
              transaction: tx,
              settingsService: widget.settingsService,
              isFromHistory: true,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(Icons.receipt_rounded, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            formatRupiah(tx.totalAmount),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'LUNAS • ${tx.paymentMethod.label}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatDayDateTime(tx.createdAt),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tx.invoiceNumber} • ${tx.totalItemsCount} item',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bayar: ${formatRupiah(tx.cashReceived)} • Kembali: ${formatRupiah(tx.changeAmount)}',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Lihat & Unduh Struk',
                    icon: Icon(Icons.download_outlined, color: colorScheme.primary, size: 20),
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => ReceiptDialog(
                          transaction: tx,
                          settingsService: widget.settingsService,
                          isFromHistory: true,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'Hapus',
                    icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error, size: 20),
                    onPressed: () => _deleteTransaction(tx),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(_HistoryFilter value, ColorScheme colorScheme) {
    final selected = _filter == value;
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
        setState(() => _filter = value);
        _loadTransactions();
      },
    );
  }
}
