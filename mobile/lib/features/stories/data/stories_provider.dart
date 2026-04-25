// lib/features/stories/data/stories_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/story_model.dart';
import '../../../../core/constants/app_constants.dart';

/// Provides a list of "story" items seeded from the latest ads.
final storiesProvider = FutureProvider<List<StoryItem>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 300));
  return _demoStories;
});

final _demoStories = [
  StoryItem(
    id: 1,
    ownerName: 'أحمد التجريبي',
    imageUrl: AppConstants.normalizeImageUrl('http://localhost:8000/storage/demo_ads/20.jpeg'),
    title: 'تويوتا كامري 2021 للبيع',
    description: 'حالة ممتازة، فل كامل، مسيرة 45,000 كم فقط.',
    price: '89,000 ريال',
    adCategory: '🚗',
    contactPhone: '+966500000002',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  StoryItem(
    id: 2,
    ownerName: 'محمد البائع',
    imageUrl: AppConstants.normalizeImageUrl('http://localhost:8000/storage/demo_ads/21.jpeg'),
    title: 'آيفون 15 برو ماكس 256GB',
    description: 'جديد بالكرتون، تيتانيوم أسود، استخدام أسبوعين.',
    price: '5,200 ريال',
    adCategory: '📱',
    contactPhone: '+966500000003',
    createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
  ),
  StoryItem(
    id: 3,
    ownerName: 'فهد الشمري',
    imageUrl: AppConstants.normalizeImageUrl('http://localhost:8000/storage/demo_ads/22.jpeg'),
    title: 'غرفة نوم خشب طبيعي',
    description: 'سرير كينج + خزانة + تسريحة. حالة ممتازة.',
    price: '8,500 ريال',
    adCategory: '🛋️',
    contactPhone: '+966500000004',
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
  ),
  StoryItem(
    id: 4,
    ownerName: 'سالم العتيبي',
    imageUrl: AppConstants.normalizeImageUrl('http://localhost:8000/storage/demo_ads/11.jpeg'),
    title: 'ماك بوك برو M3 — 2024',
    description: '14 بوصة، رام 16GB، SSD 512GB. شبه جديد.',
    price: '7,800 ريال',
    adCategory: '💻',
    contactPhone: '+966500000005',
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
  ),
  StoryItem(
    id: 5,
    ownerName: 'ناصر القحطاني',
    imageUrl: AppConstants.normalizeImageUrl('http://localhost:8000/storage/demo_ads/12.jpeg'),
    title: 'شقة للإيجار — حي النخيل',
    description: '4 غرف، مؤثثة بالكامل، قريبة من الخدمات.',
    price: '3,500 ريال / شهر',
    adCategory: '🏠',
    contactPhone: '+966500000006',
    createdAt: DateTime.now().subtract(const Duration(hours: 12)),
  ),
  StoryItem(
    id: 6,
    ownerName: 'خالد المطيري',
    imageUrl: AppConstants.normalizeImageUrl('http://localhost:8000/storage/demo_ads/23.jpeg'),
    title: 'دراجة Trek جبلية',
    description: '27.5 بوصة، 21 سرعة. استخدام 3 شهور مع الإكسسوارات.',
    price: '1,800 ريال',
    adCategory: '🚲',
    contactPhone: '+966500000007',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
  StoryItem(
    id: 7,
    ownerName: 'عمر الزهراني',
    imageUrl: AppConstants.normalizeImageUrl('http://localhost:8000/storage/demo_ads/24.jpeg'),
    title: 'ثياب رجالية براند جديدة',
    description: 'مجموعة Zara وH&M، مقاس L، جديدة بالعلب.',
    price: '600 ريال',
    adCategory: '👕',
    contactPhone: '+966500000008',
    createdAt: DateTime.now().subtract(const Duration(hours: 9)),
  ),
];
