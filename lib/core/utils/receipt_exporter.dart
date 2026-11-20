import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/sale_transaction.dart';
import '../../services/settings_service.dart';
import 'formatters.dart';

class ExportResult {
  final String filePath;
  final String displayLocation;

  const ExportResult({
    required this.filePath,
    required this.displayLocation,
  });
}

class ReceiptExporter {
  ReceiptExporter._();

  static Future<Directory> _resolveExportDir(String subFolder) async {
    // 1. Android: coba folder Download publik terlebih dahulu agar langsung terlihat di Pengelola File
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final publicDownload = Directory('/storage/emulated/0/Download/$subFolder');
        if (!await publicDownload.exists()) {
          await publicDownload.create(recursive: true);
        }
        // Uji tulis singkat untuk memastikan izin tulis tersedia
        final probe = File(p.join(publicDownload.path, '.probe'));
        await probe.writeAsString('ok');
        await probe.delete();
        return publicDownload;
      } catch (_) {
        // Fallback ke external app directory (tidak butuh izin runtime di Android 10+)
        final ext = await getExternalStorageDirectory();
        if (ext != null) {
          final dir = Directory(p.join(ext.path, subFolder));
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          return dir;
        }
      }
    }

    // 2. Desktop / iOS: coba folder Downloads atau Documents
    try {
      final dl = await getDownloadsDirectory();
      if (dl != null) {
        final dir = Directory(p.join(dl.path, subFolder));
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      }
    } catch (_) {}

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, subFolder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Menyimpan gambar struk PNG ke penyimpanan perangkat.
  static Future<ExportResult> saveReceiptPng({
    required Uint8List pngBytes,
    required String invoiceNumber,
  }) async {
    final safeName = invoiceNumber.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final dir = await _resolveExportDir('Kasirku_Struk');
    final filePath = p.join(dir.path, 'Struk_$safeName.png');
    final file = File(filePath);
    await file.writeAsBytes(pngBytes, flush: true);

    final isPublicDownload = filePath.contains('/Download/');
    return ExportResult(
      filePath: filePath,
      displayLocation: isPublicDownload
          ? 'Download/Kasirku_Struk/Struk_$safeName.png'
          : 'Kasirku_Struk/Struk_$safeName.png',
    );
  }

  /// Menyimpan teks struk (.txt) ke penyimpanan perangkat.
  static Future<ExportResult> saveReceiptText({
    required SaleTransaction transaction,
    required SettingsService settingsService,
  }) async {
    final safeName = transaction.invoiceNumber.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final dir = await _resolveExportDir('Kasirku_Struk');
    final filePath = p.join(dir.path, 'Struk_$safeName.txt');
    final file = File(filePath);
    await file.writeAsString(
      buildPlainTextReceipt(transaction: transaction, settingsService: settingsService),
      flush: true,
    );

    final isPublicDownload = filePath.contains('/Download/');
    return ExportResult(
      filePath: filePath,
      displayLocation: isPublicDownload
          ? 'Download/Kasirku_Struk/Struk_$safeName.txt'
          : 'Kasirku_Struk/Struk_$safeName.txt',
    );
  }

  /// Menyimpan riwayat transaksi & hasil pembayaran ke file CSV agar bisa dibuka di Excel/Sheets.
  static Future<ExportResult> saveHistoryCsv({
    required List<SaleTransaction> transactions,
    required String periodLabel,
  }) async {
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final dir = await _resolveExportDir('Kasirku_Laporan');
    final fileName = 'Riwayat_${periodLabel.replaceAll(' ', '_')}_$stamp.csv';
    final filePath = p.join(dir.path, fileName);

    final buf = StringBuffer();
    buf.writeln(
      'No Invoice,Hari,Tanggal,Jam,Metode Pembayaran,Jumlah Item,Subtotal,Diskon,Total Bayar,Uang Diterima,Kembalian,Rincian Barang',
    );
    for (final tx in transactions) {
      final day = formatDayName(tx.createdAt);
      final date =
          '${tx.createdAt.day.toString().padLeft(2, '0')}/${tx.createdAt.month.toString().padLeft(2, '0')}/${tx.createdAt.year}';
      final time = formatTimeWithSeconds(tx.createdAt);
      final itemsText = tx.items
          .map((i) => '${i.productName} (${i.quantity}x)')
          .join('; ')
          .replaceAll('"', '""');
      buf.writeln(
        '"${tx.invoiceNumber}","$day","$date","$time","${tx.paymentMethod.label}",${tx.totalItemsCount},${tx.subtotalAmount},${tx.discountAmount},${tx.totalAmount},${tx.cashReceived},${tx.changeAmount},"$itemsText"',
      );
    }

    final file = File(filePath);
    await file.writeAsString(buf.toString(), flush: true);

    final isPublicDownload = filePath.contains('/Download/');
    return ExportResult(
      filePath: filePath,
      displayLocation: isPublicDownload
          ? 'Download/Kasirku_Laporan/$fileName'
          : 'Kasirku_Laporan/$fileName',
    );
  }

  /// Membagikan file struk/laporan lewat menu Share sistem (WhatsApp, Galeri, File Manager, Printer).
  static Future<void> shareFile({
    required String filePath,
    required String subject,
    String? text,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        subject: subject,
        text: text,
      ),
    );
  }

  static String buildPlainTextReceipt({
    required SaleTransaction transaction,
    required SettingsService settingsService,
  }) {
    final buf = StringBuffer();
    buf.writeln(settingsService.storeName.toUpperCase());
    if (settingsService.storeAddress.isNotEmpty) {
      buf.writeln(settingsService.storeAddress);
    }
    buf.writeln('================================');
    buf.writeln('No     : ${transaction.invoiceNumber}');
    buf.writeln('Waktu  : ${formatDayDateTime(transaction.createdAt)}');
    buf.writeln('Bayar  : ${transaction.paymentMethod.label} (LUNAS)');
    buf.writeln('--------------------------------');
    for (final item in transaction.items) {
      buf.writeln(item.productName);
      buf.writeln(
        '  ${item.quantity} x ${formatRupiah(item.unitPrice)} = ${formatRupiah(item.subtotal)}',
      );
    }
    buf.writeln('--------------------------------');
    if (transaction.discountAmount > 0) {
      buf.writeln('Subtotal  : ${formatRupiah(transaction.subtotalAmount)}');
      buf.writeln('Diskon    : -${formatRupiah(transaction.discountAmount)}');
    }
    buf.writeln('TOTAL     : ${formatRupiah(transaction.totalAmount)}');
    buf.writeln('Diterima  : ${formatRupiah(transaction.cashReceived)}');
    buf.writeln('Kembalian : ${formatRupiah(transaction.changeAmount)}');
    buf.writeln('================================');
    if (settingsService.receiptFooter.isNotEmpty) {
      buf.writeln(settingsService.receiptFooter);
    }
    return buf.toString();
  }
}
