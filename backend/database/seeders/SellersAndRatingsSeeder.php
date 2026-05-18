<?php

namespace Database\Seeders;

use App\Models\Ad;
use App\Models\Rating;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

/**
 * Sprint helper seeder:
 *   1. Ensures a richer set of seller users (with bios, dealer flags, ratings stub).
 *   2. Redistributes existing ads across those sellers (so the catalog isn't owned by 1 user).
 *   3. Seeds approved ratings/reviews for each seller from random raters.
 *   4. Recalculates avg_rating + rating_count on each seller.
 *
 * Idempotent: safe to run repeatedly. Uses firstOrCreate, dedupes ratings.
 */
class SellersAndRatingsSeeder extends Seeder
{
    /** @var list<array<string,mixed>> */
    private const SELLERS = [
        [
            'email'     => 'user@barqwadih.sa',
            'name'      => 'أحمد التجريبي',
            'phone'     => '+966500000002',
            'bio'       => 'بائع جاد، التزامي بالتفاصيل ودقّة الوصف. متاح للتواصل خلال ساعات النهار.',
            'is_dealer' => false,
            // portrait + scenic cover
            'avatar'    => 'https://images.unsplash.com/photo-1531427186611-ecfd6d936c79?w=400&q=80',
            'cover'     => 'https://images.unsplash.com/photo-1519681393784-d120267933ba?w=1600&q=80',
        ],
        [
            'email'     => 'seller@barqwadih.sa',
            'name'      => 'محمد البائع',
            'phone'     => '+966500000003',
            'bio'       => 'صاحب معرض في الرياض منذ 8 سنوات، أبيع وأشتري السيارات النظيفة فقط.',
            'is_dealer' => true,
            'avatar'    => 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&q=80',
            'cover'     => 'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?w=1600&q=80',
        ],
        [
            'email'     => 'sara@barqwadih.sa',
            'name'      => 'سارة الخالدي',
            'phone'     => '+966500000004',
            'bio'       => 'أعرض أثاث منزلي مستعمل بحالة ممتازة. التسليم داخل الرياض.',
            'is_dealer' => false,
            'avatar'    => 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400&q=80',
            'cover'     => 'https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?w=1600&q=80',
        ],
        [
            'email'     => 'khaled@barqwadih.sa',
            'name'      => 'خالد المطيري',
            'phone'     => '+966500000005',
            'bio'       => 'مهتم بإلكترونيات Apple وSony. كل إعلاناتي مرفقة بفواتير الشراء.',
            'is_dealer' => false,
            'avatar'    => 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&q=80',
            'cover'     => 'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=1600&q=80',
        ],
        [
            'email'     => 'noura@barqwadih.sa',
            'name'      => 'نورة العتيبي',
            'phone'     => '+966500000006',
            'bio'       => 'أزياء وإكسسوارات أصلية فقط. الإرجاع متاح خلال 3 أيام.',
            'is_dealer' => false,
            'avatar'    => 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400&q=80',
            'cover'     => 'https://images.unsplash.com/photo-1469334031218-e382a71b716b?w=1600&q=80',
        ],
        [
            'email'     => 'fahad@barqwadih.sa',
            'name'      => 'فهد الدوسري',
            'phone'     => '+966500000007',
            'bio'       => 'تاجر سيارات معتمد، أكثر من 10 سنوات خبرة في سوق السيارات.',
            'is_dealer' => true,
            'avatar'    => 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400&q=80',
            'cover'     => 'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?w=1600&q=80',
        ],
        [
            'email'     => 'mona@barqwadih.sa',
            'name'      => 'منى السبيعي',
            'phone'     => '+966500000008',
            'bio'       => 'دروس خصوصية وكتب مستعملة لطلاب المرحلة الثانوية.',
            'is_dealer' => false,
            'avatar'    => 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=400&q=80',
            'cover'     => 'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=1600&q=80',
        ],
        [
            'email'     => 'omar@barqwadih.sa',
            'name'      => 'عمر الحارثي',
            'phone'     => '+966500000009',
            'bio'       => 'هاوي صيد وقنص، أعرض صقور مدربة وعدتها بشهادات.',
            'is_dealer' => false,
            'avatar'    => 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400&q=80',
            'cover'     => 'https://images.unsplash.com/photo-1583511655826-05700d52f4d9?w=1600&q=80',
        ],
        [
            'email'     => 'lina@barqwadih.sa',
            'name'      => 'لينا الزهراني',
            'phone'     => '+966500000010',
            'bio'       => 'كل ما يخص الأطفال: ألعاب، ملابس، عربيات. كله من بيت غير مدخّن.',
            'is_dealer' => false,
            'avatar'    => 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400&q=80',
            'cover'     => 'https://images.unsplash.com/photo-1558877385-8c1f1e9b73f5?w=1600&q=80',
        ],
        [
            'email'     => 'turki@barqwadih.sa',
            'name'      => 'تركي العنزي',
            'phone'     => '+966500000011',
            'bio'       => 'قطع غيار سيارات أصلية، بدون مساومات على الجودة.',
            'is_dealer' => true,
            'avatar'    => 'https://images.unsplash.com/photo-1463453091185-61582044d556?w=400&q=80',
            'cover'     => 'https://images.unsplash.com/photo-1486262715619-67b85e0b08d3?w=1600&q=80',
        ],
    ];

    /** @var list<array{int,string}> stars + Arabic comment */
    private const REVIEW_POOL = [
        [5, 'بائع محترم والتعامل ممتاز، السلعة كما هي بالوصف تماماً.'],
        [5, 'وصول سريع وتسليم في الموعد، أنصح فيه.'],
        [5, 'صراحة شخص أمين، سعّر بإنصاف وما ضيّع وقت.'],
        [5, 'تجربة ممتازة من البداية للنهاية، إن شاء الله نتعامل مرة ثانية.'],
        [4, 'الحالة جيدة لكن السعر فيه مجال تفاوض. مع ذلك راضي.'],
        [4, 'تواصل سريع لكن التسليم تأخر يوم واحد. لا بأس.'],
        [4, 'منتج كما وُصف لكن التغليف كان عادي.'],
        [4, 'كل شيء تمام، فقط لو الصور كانت أوضح كان أفضل.'],
        [3, 'متوسط، السلعة كويسة لكن في تفاصيل صغيرة لم تذكر.'],
        [3, 'الصفقة تمت بس استغرق التواصل أكثر من المتوقع.'],
        [5, 'الله يعطيه العافية، أمانة ومصداقية.'],
        [5, 'من أفضل البائعين اللي تعاملت معهم على المنصة.'],
        [4, 'البضاعة وصلت سليمة، مع شوية تعديل بسيط على الوقت.'],
        [5, 'تعامل راقي وسلعة بحالة الجديد، يشكر.'],
        [2, 'في فرق بسيط بين الوصف والواقع لكنه تفاهم وعالج الموضوع.'],
        [5, 'فعلاً يستاهل التعامل، بائع شفّاف ومصدّق على كل تفصيل.'],
        [5, 'أفضل تجربة شراء على التطبيق حتى الآن، ما ندمت.'],
        [4, 'سعره معقول والمنتج بحالته مقبولة جداً، شكراً جزيلاً.'],
        [4, 'جلب لي السلعة لمنزلي والسعر ما تغير، احترام يستحق التقييم.'],
        [5, 'عرّف على نفسه قبل لا أوصل، ساعد بالتنزيل وكل شي تمام.'],
        [3, 'فيه ملاحظات بسيطة بس بشكل عام البائع متجاوب.'],
        [5, 'الصور مطابقة 100%، السلعة وصلت كما هي بدون أي خدش.'],
        [2, 'تأخر في الرد لكن في النهاية أوصل اللي عليه.'],
        [4, 'أسعاره منافسة وفي مرونة بالتفاوض، أنصح فيه.'],
        [5, 'الصراحة أكثر من ممتاز، باع لي بسعر زهيد ومرتاح.'],
        [1, 'للأسف ما تم البيع بسبب اختلاف بالتفاصيل، بس الرجاء أنه يصدق بالوصف.'],
        [4, 'تعامل ودود وهادئ، يفهم ويوضح بدون إلحاح.'],
        [5, 'أوصاني بطريقة الفحص قبل الاستلام، شكراً على المصداقية.'],
        [5, 'بائع فاهم في تخصصه، أعطاني نصائح مفيدة قبل الشراء.'],
        [3, 'الإعلان كان ينقصه بعض المعلومات، لكن الموضوع تم بالنهاية.'],
    ];

    public function run(): void
    {
        if (app()->isProduction()) {
            $this->command->warn('SellersAndRatingsSeeder skipped in production!');
            return;
        }

        $this->command->info('Seeding sellers + ratings...');

        // ── 1. Ensure sellers ────────────────────────────────────────────────
        $sellers = [];
        foreach (self::SELLERS as $d) {
            /** @var User|null $user */
            $user = User::withTrashed()
                ->where(function ($q) use ($d) {
                    $q->where('email', $d['email'])->orWhere('phone', $d['phone']);
                })
                ->first();

            if ($user) {
                if ($user->trashed()) {
                    $user->restore();
                }
                $user->forceFill([
                    'name'        => $d['name'],
                    'email'       => $d['email'],
                    'phone'       => $d['phone'],
                    'role'        => 'user',
                    'is_active'   => true,
                    'is_verified' => true,
                    'locale'      => 'ar',
                    'bio'         => $user->bio ?: ($d['bio'] ?? null),
                    'is_dealer'   => $user->is_dealer ?: ($d['is_dealer'] ?? false),
                    // Only set avatar/cover when missing — don't clobber a real upload.
                    'avatar'      => $user->avatar ?: ($d['avatar'] ?? null),
                    'cover_image' => $user->cover_image ?: ($d['cover'] ?? null),
                ])->save();
            } else {
                $user = User::create([
                    'name'        => $d['name'],
                    'email'       => $d['email'],
                    'phone'       => $d['phone'],
                    'password'    => Hash::make('password'),
                    'role'        => 'user',
                    'is_active'   => true,
                    'is_verified' => true,
                    'locale'      => 'ar',
                    'is_dealer'   => $d['is_dealer'] ?? false,
                    'bio'         => $d['bio'] ?? null,
                    'avatar'      => $d['avatar'] ?? null,
                    'cover_image' => $d['cover']  ?? null,
                ]);
            }

            $sellers[] = $user;
        }

        $sellerIds = collect($sellers)->pluck('id')->all();
        $this->command->info('Sellers ready: ' . count($sellers));

        // ── 2. Redistribute existing ads across sellers ──────────────────────
        $ads = Ad::orderBy('id')->get(['id', 'user_id', 'contact_phone', 'contact_whatsapp']);
        $reassigned = 0;
        foreach ($ads as $i => $ad) {
            $newOwner = $sellers[$i % count($sellers)];
            if ($ad->user_id === $newOwner->id) continue;
            $ad->user_id = $newOwner->id;
            // keep contact phones consistent with the (new) owner so chats / contact sheet make sense
            $ad->contact_phone    = $newOwner->phone;
            $ad->contact_whatsapp = $newOwner->phone;
            $ad->save();
            $reassigned++;
        }
        $this->command->info("Re-assigned {$reassigned} ads across " . count($sellers) . ' sellers.');

        // refresh per-seller total_ads_count
        foreach ($sellers as $seller) {
            $count = Ad::where('user_id', $seller->id)->count();
            User::where('id', $seller->id)->update(['total_ads_count' => $count]);
        }

        // ── 3. Seed ratings ──────────────────────────────────────────────────
        // Strategy: 8–14 reviews per seller. Unique constraint is (rater, rated_user, ad),
        // so the same rater can rate the same seller across different ads. We track
        // visited (rater, ad) pairs locally to skip duplicates fast.
        $totalRatings = 0;
        foreach ($sellers as $seller) {
            $sellerAds = Ad::where('user_id', $seller->id)->pluck('id')->all();
            if (empty($sellerAds)) continue;

            $otherRaters = array_values(array_diff($sellerIds, [$seller->id]));
            if (empty($otherRaters)) continue;

            $reviewCount = random_int(8, 14);
            $seen = []; // "raterId:adId" → true
            $created = 0;
            $attempts = 0;
            $maxAttempts = $reviewCount * 6;

            while ($created < $reviewCount && $attempts < $maxAttempts) {
                $attempts++;
                $raterId = $otherRaters[array_rand($otherRaters)];
                $adId    = $sellerAds[array_rand($sellerAds)];
                $key     = $raterId . ':' . $adId;
                if (isset($seen[$key])) continue;
                $seen[$key] = true;

                // unique on (rater, rated_user, ad) — also guard against pre-existing rows
                $exists = Rating::where('rater_id', $raterId)
                    ->where('rated_user_id', $seller->id)
                    ->where('ad_id', $adId)
                    ->exists();
                if ($exists) continue;

                [$stars, $comment] = self::REVIEW_POOL[array_rand(self::REVIEW_POOL)];

                Rating::create([
                    'rater_id'        => $raterId,
                    'rated_user_id'   => $seller->id,
                    'ad_id'           => $adId,
                    'stars'           => $stars,
                    'comment'         => $comment,
                    'pledge_accepted' => true,
                    'is_approved'     => true,
                    'created_at'      => now()->subDays(random_int(1, 90)),
                    'updated_at'      => now(),
                ]);
                $totalRatings++;
                $created++;
            }
        }

        // ── 4. Recompute avg_rating + rating_count per seller ────────────────
        foreach ($sellers as $seller) {
            $stats = DB::table('ratings')
                ->where('rated_user_id', $seller->id)
                ->where('is_approved', true)
                ->selectRaw('AVG(stars) as avg_rating, COUNT(*) as rating_count')
                ->first();

            User::where('id', $seller->id)->update([
                'avg_rating'   => round((float) ($stats->avg_rating ?? 0), 2),
                'rating_count' => (int) ($stats->rating_count ?? 0),
            ]);
        }

        $this->command->info("Created {$totalRatings} approved ratings across " . count($sellers) . ' sellers.');
    }
}
