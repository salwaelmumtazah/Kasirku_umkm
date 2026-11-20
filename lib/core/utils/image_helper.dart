import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageHelper {
  ImageHelper._();

  static final ImagePicker _picker = ImagePicker();

  /// Memilih foto dari Kamera atau Galeri, mengompres ke JPEG,
  /// dan menyimpannya permanen di direktori dokumen aplikasi.
  static Future<String?> pickAndSaveImage({
    required BuildContext context,
    required ImageSource source,
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      final Directory appDir = await getApplicationDocumentsDirectory();
      final String imagesDirPath = p.join(appDir.path, 'kasirku_images');
      final Directory imagesDir = Directory(imagesDirPath);
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final String fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String targetPath = p.join(imagesDirPath, fileName);

      XFile? compressed;
      try {
        compressed = await FlutterImageCompress.compressAndGetFile(
          pickedFile.path,
          targetPath,
          quality: 75,
          minWidth: 600,
          minHeight: 600,
          format: CompressFormat.jpeg,
        );
      } catch (err) {
        debugPrint('Kompresi gambar dilewati: $err');
      }

      if (compressed != null && await File(compressed.path).exists()) {
        return compressed.path;
      } else {
        final savedFile = await File(pickedFile.path).copy(targetPath);
        return savedFile.path;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka kamera/galeri: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    }
  }

  /// Menghapus file gambar lokal secara aman dari penyimpanan perangkat.
  static void deleteImageFile(String? path) {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      debugPrint('Gagal menghapus file gambar: $e');
    }
  }
}

