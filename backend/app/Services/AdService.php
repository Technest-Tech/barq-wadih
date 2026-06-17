<?php

namespace App\Services;

use App\Enums\AdStatus;
use App\Enums\CommissionStatus;
use App\Enums\ModerationStatus;
use App\Enums\PaymentStatus;
use App\Jobs\SendSaleFeeNotificationJob;
use App\Models\Ad;
use App\Models\AdFieldValue;
use App\Models\AdImage;
use App\Models\Category;
use App\Models\CategoryField;
use App\Models\Region;
use App\Models\User;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;

class AdService
{
    public function __construct(private readonly ImageService $imageService) {}

    // ── Create ────────────────────────────────────────────────────────────────

    /**
     * Create a new ad with images and field values.
     *
     * @param  array<string, mixed>  $data
     * @param  UploadedFile[]        $images
     */
    public function create(User $user, array $data, array $images): Ad
    {
        return DB::transaction(function () use ($user, $data, $images) {
            // Resolve region from city
            $cityId   = (int) $data['city_id'];
            $regionId = \App\Models\City::find($cityId)?->region_id;

            $sellerType = $data['seller_type'] ?? 'individual';
            $categoryId = (int) $data['category_id'];
            $commission = $this->calculateCommission($categoryId, (float) ($data['price'] ?? 0), false, $sellerType);

            // Resolve publish fee from category × seller tier.
            $publishFee = $this->resolvePublishFee($categoryId, $sellerType);
            $hasFee     = $publishFee > 0;

            /** @var Ad $ad */
            $ad = $user->ads()->create([
                'seller_type'         => $sellerType,
                'category_id'         => $data['category_id'],
                'city_id'             => $cityId,
                'region_id'           => $regionId,
                'district_id'         => $data['district_id'] ?? null,
                'district_name_free'  => $data['district_name_free'] ?? null,
                'latitude'            => $data['latitude'] ?? null,
                'longitude'           => $data['longitude'] ?? null,
                'title'               => $data['title'],
                'description'         => $data['description'],
                'price'               => $data['price'] ?? null,
                'price_hidden'        => false,
                'is_negotiable'       => $data['is_negotiable'] ?? false,
                'is_free'             => false,
                'contact_phone'       => $data['contact_phone'] ?? null,
                'contact_whatsapp'    => $data['contact_whatsapp'] ?? null,
                'show_phone_publicly' => $data['show_phone_publicly'] ?? true,
                'pledge_accepted'     => true,
                'commission_amount'   => $commission,
                'commission_status'   => CommissionStatus::Pending,
                // Branch on fee: paid categories sit in pending_payment until the
                // wizard's Pay step confirms; free categories publish immediately.
                'status'              => $hasFee ? AdStatus::PendingPayment : AdStatus::Active,
                'moderation_status'   => ModerationStatus::Approved,
                'payment_status'      => $hasFee ? PaymentStatus::Pending->value : PaymentStatus::NotRequired->value,
                'payment_amount'      => $hasFee ? $publishFee : null,
                'published_at'        => $hasFee ? null : now(),
                'expires_at'          => now()->addDays(30),
            ]);

            // Save dynamic field values
            $this->syncFieldValues($ad, $data['fields'] ?? []);

            // Save images
            $this->processImages($ad, $images);

            return $ad->fresh(['images', 'fieldValues.field', 'category', 'city', 'region', 'district']);
        });
    }

    // ── Mark Paid ─────────────────────────────────────────────────────────────

    /**
     * Flip an ad from `pending_payment` → `active` after the PaymentService
     * confirms. Idempotent — calling on an already-paid ad is a no-op.
     *
     * @param  array{reference?: string, provider_reference?: string}  $payload
     */
    public function markPaid(Ad $ad, array $payload = []): Ad
    {
        if ($ad->payment_status === PaymentStatus::Paid->value) {
            return $ad;
        }

        $ad->update([
            'payment_status'    => PaymentStatus::Paid->value,
            'payment_reference' => $payload['provider_reference'] ?? $payload['reference'] ?? $ad->payment_reference,
            'paid_at'           => now(),
            'status'            => AdStatus::Active,
            'published_at'      => $ad->published_at ?? now(),
        ]);

        return $ad->fresh(['images', 'fieldValues.field', 'category', 'city', 'region', 'district']);
    }

    /**
     * Pick the upfront publish fee for this category × seller tier.
     * Falls back to 0 when columns are null so older seeded categories stay free.
     */
    public function resolvePublishFee(int $categoryId, string $sellerType = 'individual'): float
    {
        $cat = Category::find($categoryId);
        if (! $cat) {
            return 0.0;
        }

        $fee = $sellerType === 'dealer'
            ? (float) ($cat->publish_fee_dealer ?? 0)
            : (float) ($cat->publish_fee_individual ?? 0);

        return max(0.0, $fee);
    }

    // ── Update ────────────────────────────────────────────────────────────────

    /**
     * Update an existing ad.
     *
     * @param  array<string, mixed>  $data
     * @param  UploadedFile[]        $newImages
     * @param  int[]                 $removeImageIds
     */
    public function update(Ad $ad, array $data, array $newImages = [], array $removeImageIds = []): Ad
    {
        return DB::transaction(function () use ($ad, $data, $newImages, $removeImageIds) {
            $fillable = array_intersect_key($data, array_flip([
                'title', 'description', 'price',
                'is_negotiable',
                'city_id', 'district_id', 'district_name_free',
                'latitude', 'longitude',
                'contact_phone', 'contact_whatsapp', 'show_phone_publicly',
            ]));

            if (isset($fillable['city_id'])) {
                $fillable['region_id'] = \App\Models\City::find($fillable['city_id'])?->region_id;
            }

            $ad->update($fillable);

            // Sync dynamic fields (partial — only keys provided)
            if (! empty($data['fields'])) {
                $this->syncFieldValues($ad, $data['fields']);
            }

            // Remove specified images
            foreach ($removeImageIds as $imageId) {
                /** @var AdImage|null $image */
                $image = $ad->images()->find($imageId);
                if ($image) {
                    $this->imageService->delete($image->image_url);
                    $image->delete();
                }
            }

            // Add new images
            if (! empty($newImages)) {
                $this->processImages($ad, $newImages);
            }

            return $ad->fresh(['images', 'fieldValues.field', 'category', 'city', 'region']);
        });
    }

    // ── Delete ────────────────────────────────────────────────────────────────

    public function delete(Ad $ad): void
    {
        $ad->update(['status' => AdStatus::Deleted]);
        $ad->delete();
    }

    // ── Mark Sold ─────────────────────────────────────────────────────────────

    public function markAsSold(Ad $ad): void
    {
        // Bypass Scout sync during update to avoid search-engine connection issues.
        // The sold ad will be removed from the index asynchronously via the queue.
        Ad::withoutSyncingToSearch(function () use ($ad) {
            $ad->update([
                'status'           => AdStatus::Sold,
                'sale_declared_at' => now(),
            ]);
        });

        // Queue the unsearchable call separately so it doesn't block the request.
        dispatch(function () use ($ad) {
            try {
                $ad->unsearchable();
            } catch (\Throwable) {
                // Search index removal is non-critical; log but don't fail.
                \Illuminate\Support\Facades\Log::warning('unsearchable failed for ad', ['id' => $ad->id]);
            }
        })->afterResponse();

        // Notify the seller to pay the sale commission fee.
        SendSaleFeeNotificationJob::dispatch($ad->id)->onQueue('notifications');
    }

    // ── Commission ────────────────────────────────────────────────────────────

    /**
     * Deferred commission = fixed SAR amount from category config.
     * Falls back to max(90 SAR, 0.5% of price) for unconfigured categories.
     */
    public function calculateCommission(int $categoryId, float $price, bool $isFree = false, string $sellerType = 'individual'): float
    {
        if ($isFree || $price <= 0) {
            return 0.0;
        }

        $cat = Category::find($categoryId);
        if ($cat) {
            $fixed = $sellerType === 'dealer'
                ? (float) ($cat->deferred_commission_dealer ?? 0)
                : (float) ($cat->deferred_commission_individual ?? 0);

            if ($fixed > 0) {
                return $fixed;
            }
        }

        // Legacy fallback for categories without explicit deferred amounts
        return max(90.0, $price * 0.005);
    }

    /**
     * Returns true when the category has an explicit fixed deferred commission,
     * meaning the commission icon should show an exact amount (no ~ approximation).
     */
    public function isFlatFeeCategory(int $categoryId, string $sellerType = 'individual'): bool
    {
        $cat = Category::find($categoryId);
        if (! $cat) {
            return false;
        }

        $fixed = $sellerType === 'dealer'
            ? (float) ($cat->deferred_commission_dealer ?? 0)
            : (float) ($cat->deferred_commission_individual ?? 0);

        return $fixed > 0;
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /**
     * Store uploaded images and create AdImage records.
     *
     * @param  UploadedFile[]  $files
     */
    private function processImages(Ad $ad, array $files): void
    {
        $currentMax = (int) ($ad->images()->max('sort_order') ?? -1);

        foreach ($files as $index => $file) {
            // Generate resized WebP variants (thumbnail + detail image) instead
            // of serving the multi-MB camera original. This is the single biggest
            // factor in how fast ad images appear for clients.
            $variants = $this->imageService->storeVariants($file->getRealPath(), "ads/{$ad->id}");

            AdImage::create([
                'ad_id'         => $ad->id,
                'image_url'     => $variants['image_url'],
                'thumbnail_url' => $variants['thumbnail_url'],
                'sort_order'    => $currentMax + 1 + $index,
                'file_size'     => $variants['file_size'],
                'width'         => $variants['width'],
                'height'        => $variants['height'],
            ]);
        }
    }

    /**
     * Upsert dynamic field values for an ad.
     *
     * @param  array<string, mixed>  $fields  ['field_key' => 'value', ...]
     */
    private function syncFieldValues(Ad $ad, array $fields): void
    {
        if (empty($fields)) {
            return;
        }

        $fieldMap = CategoryField::where('category_id', $ad->category_id)
            ->whereIn('field_key', array_keys($fields))
            ->pluck('id', 'field_key');

        foreach ($fields as $key => $value) {
            $fieldId = $fieldMap->get($key);
            if (! $fieldId) {
                continue;
            }

            AdFieldValue::updateOrCreate(
                ['ad_id' => $ad->id, 'category_field_id' => $fieldId],
                ['value' => is_array($value) ? json_encode($value) : (string) $value]
            );
        }
    }
}
