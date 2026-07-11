// lib/features/categories/presentation/category_icons.dart

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Slug → Lucide glyph for every main category and subcategory. Used as the
/// white glyph inside the gradient category tiles (categories screen / browser
/// sheet) and anywhere a category has no uploaded image. Covers both the live
/// slugs and the seeder slugs so any of them resolves to a meaningful icon.
const Map<String, IconData> _categoryIcons = {
  // ── Main categories ──────────────────────────────────────────────────────
  'cars': LucideIcons.car,
  'electronics': LucideIcons.smartphone,
  'furniture': LucideIcons.sofa,
  'jobs': LucideIcons.briefcase,
  'services': LucideIcons.wrench,
  'fashion': LucideIcons.shirt,
  'sports-leisure': LucideIcons.trophy,
  'books-magazines': LucideIcons.book,
  'toys-kids': LucideIcons.toyBrick,
  'animals': LucideIcons.dog,
  'personal-items': LucideIcons.backpack,
  'hunting-trips': LucideIcons.fish,
  'food-beverages': LucideIcons.utensils,
  'other': LucideIcons.layoutGrid,

  // ── Cars ─────────────────────────────────────────────────────────────────
  'cars-for-sale': LucideIcons.car,
  'cars-for-rent': LucideIcons.key,
  'spare-parts': LucideIcons.cog,
  'car-parts': LucideIcons.cog,
  'car-services': LucideIcons.wrench,
  'motorcycles': LucideIcons.bike,
  'trucks': LucideIcons.truck,
  'heavy-equipment': LucideIcons.construction,
  'premium-plates': LucideIcons.hash,

  // ── Electronics ──────────────────────────────────────────────────────────
  'phones-tablets': LucideIcons.smartphone,
  'computers': LucideIcons.laptop,
  'home-appliances': LucideIcons.microwave,
  'cameras': LucideIcons.camera,
  'other-electronics': LucideIcons.cpu,
  'gaming': LucideIcons.gamepad2,
  'tvs-audio': LucideIcons.tv,
  'networking': LucideIcons.wifi,
  'premium-numbers': LucideIcons.phone,
  'accounts-subscriptions': LucideIcons.lock,

  // ── Furniture ────────────────────────────────────────────────────────────
  'bedrooms': LucideIcons.bed,
  'living-rooms': LucideIcons.sofa,
  'kitchens': LucideIcons.utensilsCrossed,
  'office-furniture': LucideIcons.lampDesk,

  // ── Jobs ─────────────────────────────────────────────────────────────────
  'government-jobs': LucideIcons.landmark,
  'private-jobs': LucideIcons.building2,
  'freelance': LucideIcons.laptop,
  'seeking-employee': LucideIcons.userPlus,

  // ── Services ─────────────────────────────────────────────────────────────
  'home-services': LucideIcons.home,
  'education': LucideIcons.graduationCap,
  'moving-shipping': LucideIcons.truck,
  'other-services': LucideIcons.settings,

  // ── Fashion ──────────────────────────────────────────────────────────────
  'mens-clothing': LucideIcons.shirt,
  'womens-clothing': LucideIcons.shoppingBag,
  'childrens-clothing': LucideIcons.baby,
  'accessories': LucideIcons.watch,

  // ── Hunting & trips ──────────────────────────────────────────────────────
  'fishing': LucideIcons.fish,
  'hunting': LucideIcons.bird,
  'outdoor-gear': LucideIcons.tent,

  // ── Food & beverages ─────────────────────────────────────────────────────
  'meals': LucideIcons.utensils,
  'sweets': LucideIcons.cake,
  'beverages': LucideIcons.coffee,
  'organic': LucideIcons.leaf,

  // ── Animals ──────────────────────────────────────────────────────────────
  'birds': LucideIcons.bird,
  'cats': LucideIcons.cat,
  'dogs': LucideIcons.dog,
  'fish-turtles': LucideIcons.fish,
  'pet-supplies': LucideIcons.bone,
  'cattle': LucideIcons.beef,
  'rabbits-squirrels': LucideIcons.squirrel,
  'ornamental-fish': LucideIcons.fish,
  // Birds → حمام/دجاج/بط (third level)
  'pigeons': LucideIcons.bird,
  'chickens': LucideIcons.drumstick,
  'ducks': LucideIcons.bird,
};

IconData categoryIcon(String slug) =>
    _categoryIcons[slug] ??
    // Every section ends with an «أخرى» catch-all (other-furniture, other-jobs, …).
    (slug.startsWith('other-') ? LucideIcons.package : LucideIcons.tag);

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
    if (image.toLowerCase().contains('.svg')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SvgPicture.network(
          image,
          width: imageSize,
          height: imageSize,
          fit: BoxFit.cover,
          placeholderBuilder: (_) => fallback,
        ),
      );
    }
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
