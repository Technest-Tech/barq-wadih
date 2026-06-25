// lib/features/categories/presentation/category_icons.dart

import 'package:flutter/widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';

IconData categoryIcon(String slug) {
  switch (slug) {
    case 'cars':
      return LucideIcons.car;
    case 'hunting-trips':
      return LucideIcons.fish;
    case 'food-beverages':
      return LucideIcons.utensils;
    default:
      return LucideIcons.layoutGrid;
  }
}

/// Category visual: shows the uploaded [image] when present, otherwise falls
/// back to the slug-mapped Lucide icon. Used everywhere a category is listed
/// so an admin-set image reflects consistently across the app.
Widget categoryVisual(
  String slug,
  String? image, {
  required Color color,
  double iconSize = 20,
  double imageSize = 40,
  double radius = 10,
}) {
  if (image != null && image.startsWith('http')) {
    final fallback = Icon(categoryIcon(slug), color: color, size: iconSize);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        image,
        width: imageSize,
        height: imageSize,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : fallback,
      ),
    );
  }
  return Icon(categoryIcon(slug), color: color, size: iconSize);
}
