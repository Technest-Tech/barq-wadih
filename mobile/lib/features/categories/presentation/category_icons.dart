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
