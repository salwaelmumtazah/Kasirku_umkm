import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/receipt_exporter.dart';
import '../../data/models/sale_transaction.dart';
import '../../services/settings_service.dart';

class ReceiptDialog extends StatefulWidget {
  final SaleTransaction transaction;
  final SettingsService settingsService;
  final bool isFromHistory;

  const ReceiptDialog({
    super.key,
    required this.transaction,
    required this.settingsService,
    this.isFromHistory = false,
  });

  @override
  State<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<ReceiptDialog> {
  final GlobalKey _receiptBoundaryKey = GlobalKey();
  bool _isExporting = false;
  String? _savedInfo;

  Future<Uint8List?> _captureReceiptPng() async {
    final boundary =
        _receiptBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _downloadReceipt({bool openShare = false}) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      // Beri jeda 1 frame agar RepaintBoundary benar-benar siap
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final pngBytes = await _captureReceiptPng();
      if (pngBytes == null) {
        throw Exception('Gagal menangkap gambar struk');
      }

      final result = await ReceiptExporter.saveReceiptPng(
        pngBytes: pngBytes,
        invoiceNumber: widget.transaction.invoiceNumber,
      );

      if (!mounted) return;
      setState(() {
        _savedInfo = 'Struk tersimpan di: ${result.displayLocation}';
      });

      if (openShare) {
        await ReceiptExporter.shareFile(
          filePath: result.filePath,
          subject: 'Struk ${widget.transaction.invoiceNumber}',
          text:
              'Struk ${widget.settingsService.storeName} - ${formatDayDateTime(widget.transaction.createdAt)}',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Struk berhasil diunduh: ${result.displayLocation}'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Bagikan',
              onPressed: () {
                ReceiptExporter.shareFile(
                  filePath: result.filePath,
                  subject: 'Struk ${widget.transaction.invoiceNumber}',
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunduh struk: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _copyPlainText() {
    final text = ReceiptExporter.buildPlainTextReceipt(
      transaction: widget.transaction,
      settingsService: widget.settingsService,
    );
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Teks struk disalin ke clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tx = widget.transaction;
    final settings = widget.settingsService;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header dialog
              Row(
                children: [
                  Icon(
                    widget.isFromHistory
                        ? Icons.receipt_long_rounded
                        : Icons.check_circle_rounded,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isFromHistory ? 'Detail Struk' : 'Transaksi Berhasil!',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Area Struk (Kertas putih rapi agar hasil PNG unduhan selalu jernih & siap cetak)
              Flexible(
                child: SingleChildScrollView(
                  child: RepaintBoundary(
                    key: _receiptBoundaryKey,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DefaultTextStyle(
                        style: const TextStyle(color: Colors.black87, fontSize: 13),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header Toko
                            Text(
                              settings.storeName.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                                letterSpacing: 0.4,
                              ),
                            ),
                            if (settings.storeAddress.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                settings.storeAddress,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'LUNAS • ${tx.paymentMethod.label.toUpperCase()}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1B5E20),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Info Invoice, Hari, Tanggal & Jam
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF6F7F8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  _receiptMetaRow('No. Struk', tx.invoiceNumber),
                                  const SizedBox(height: 4),
                                  _receiptMetaRow('Hari & Tanggal', formatDayDate(tx.createdAt)),
                                  const SizedBox(height: 4),
                                  _receiptMetaRow('Jam', formatTimeWithSeconds(tx.createdAt)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: Colors.black26),
                            const SizedBox(height: 10),

                            // Daftar Item
                            ...tx.items.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.productName,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            '${item.quantity} x ${formatRupiah(item.unitPrice)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      formatRupiah(item.subtotal),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Divider(height: 1, color: Colors.black26),
                            const SizedBox(height: 10),

                            // Hasil Pembayaran
                            if (tx.discountAmount > 0) ...[
                              _receiptRow('Subtotal', formatRupiah(tx.subtotalAmount)),
                              const SizedBox(height: 4),
                              _receiptRow(
                                'Diskon',
                                '-${formatRupiah(tx.discountAmount)}',
                                valueColor: Colors.red.shade700,
                              ),
                              const SizedBox(height: 4),
                            ],
                            _receiptRow(
                              'TOTAL BAYAR',
                              formatRupiah(tx.totalAmount),
                              isBold: true,
                              valueColor: const Color(0xFF1B5E20),
                            ),
                            const SizedBox(height: 6),
                            _receiptRow('Metode Bayar', tx.paymentMethod.label),
                            const SizedBox(height: 4),
                            _receiptRow('Uang Diterima', formatRupiah(tx.cashReceived)),
                            const SizedBox(height: 4),
                            _receiptRow(
                              'Kembalian',
                              formatRupiah(tx.changeAmount),
                              isBold: true,
                            ),

                            if (settings.receiptFooter.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Divider(height: 1, color: Colors.black26),
                              const SizedBox(height: 8),
                              Text(
                                settings.receiptFooter,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              if (_savedInfo != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _savedInfo!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Tombol Unduh PNG, Bagikan, Salin Teks, Selesai (responsif!)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isExporting ? null : () => _downloadReceipt(openShare: false),
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Unduh Struk'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isExporting ? null : () => _downloadReceipt(openShare: true),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Bagikan'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _copyPlainText,
                      icon: const Icon(Icons.copy_rounded, size: 17),
                      label: const Text('Salin Teks'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(widget.isFromHistory ? 'Tutup' : 'Transaksi Baru'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _receiptMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _receiptRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.normal,
            color: Colors.black87,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
            color: valueColor ?? Colors.black,
          ),
        ),
      ],
    );
  }
}
