import 'dart:io';
import 'package:flutter/material.dart';

class ProductImage extends StatelessWidget {
  final String? imagePath;
  final double? width;
  final double? height;
  final double iconSize;
  final BorderRadius? borderRadius;

  const ProductImage({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.iconSize = 32,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasValidFile = imagePath != null &&
        imagePath!.isNotEmpty &&
        File(imagePath!).existsSync();

    final content = Container(
      width: width,
      height: height,
      color: colorScheme.primaryContainer.withValues(alpha: 0.55),
      child: hasValidFile
          ? Image.file(
              File(imagePath!),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _placeholder(colorScheme),
            )
          : _placeholder(colorScheme),
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: content);
    }
    return content;
  }

  Widget _placeholder(ColorScheme colorScheme) {
    return Center(
      child: Icon(
        Icons.inventory_2_outlined,
        size: iconSize,
        color: colorScheme.primary,
      ),
    );
  }
}
