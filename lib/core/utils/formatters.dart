import 'package:intl/intl.dart';

const _daysId = <String>[
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

const _monthsId = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// Memformat angka integer menjadi mata uang Rupiah Indonesia (cth: Rp 15.000).
String formatRupiah(int amount) {
  final str = amount.abs().toString();
  final buffer = StringBuffer();
  int count = 0;
  for (int i = str.length - 1; i >= 0; i--) {
    count++;
    buffer.write(str[i]);
    if (count % 3 == 0 && i > 0) {
      buffer.write('.');
    }
  }
  final formatted = buffer.toString().split('').reversed.join('');
  return '${amount < 0 ? "-Rp " : "Rp "}$formatted';
}

/// Nama hari dalam Bahasa Indonesia (Senin..Minggu).
String formatDayName(DateTime dt) {
  return _daysId[(dt.weekday - 1).clamp(0, 6)];
}

/// Memformat DateTime lengkap dengan hari, tanggal, dan jam:
/// cth: "Jumat, 20 Nov 2026 • 19:46"
String formatDayDateTime(DateTime dt) {
  final day = formatDayName(dt);
  final month = _monthsId[(dt.month - 1).clamp(0, 11)];
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$day, ${dt.day} $month ${dt.year} • $hh:$mm';
}

/// Memformat DateTime menjadi "Jumat, 20 Nov 2026".
String formatDayDate(DateTime dt) {
  final day = formatDayName(dt);
  final month = _monthsId[(dt.month - 1).clamp(0, 11)];
  return '$day, ${dt.day} $month ${dt.year}';
}

/// Memformat DateTime menjadi "Jumat, 20/11/2026 19:46".
String formatDateTime(DateTime dt) {
  final day = formatDayName(dt);
  return '$day, ${DateFormat('dd/MM/yyyy HH:mm').format(dt)}';
}

/// Memformat DateTime menjadi "19:46:05".
String formatTimeWithSeconds(DateTime dt) {
  return DateFormat('HH:mm:ss').format(dt);
}

/// Memformat DateTime menjadi "19:46".
String formatTimeOnly(DateTime dt) {
  return DateFormat('HH:mm').format(dt);
}

/// Membuat nomor struk unik berbasis waktu lokal (offline-safe).
String generateInvoiceNumber(DateTime now) {
  final datePart = DateFormat('yyyyMMdd').format(now);
  final timePart = DateFormat('HHmmss').format(now);
  return 'INV-$datePart-$timePart';
}

/// Menormalkan nama kategori agar rapi dan tidak duplikat beda huruf besar/kecil.
String normalizeCategory(String raw) {
  final cleaned = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (cleaned.isEmpty) return 'Umum';
  return cleaned
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');
}
