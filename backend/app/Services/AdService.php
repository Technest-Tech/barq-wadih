<?php

namespace App\Services;

use App\Enums\AdStatus;
use App\Enums\CommissionStatus;
use App\Enums\ModerationStatus;
use App\Enums\PaymentMethod;
use App\Enums\PaymentStatus;
use App\Jobs\SendSaleFeeNotificationJob;
use App\Models\Ad;
use App\Models\AdFieldValue;
use App\Models\AdImage;
use App\Models\Category;
use App\Models\CommissionPayment;
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
                // Publishing is free for every category. The flat commission is
                // only owed AFTER the sale — see markAsSold().
                'commission_amount'   => $commission,
                'commission_status'   => CommissionStatus::Pending,
                'status'              => AdStatus::Active,
                'moderation_status'   => ModerationStatus::Approved,
                'payment_status'      => PaymentStatus::NotRequired->value,
                'published_at'        => now(),
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
     * Settle the after-sale commission once an admin approves the transfer
     * receipt. Unlike markPaid(), this does NOT republish the ad — it stays
     * Sold. Idempotent.
     */
    public function markCommissionPaid(Ad $ad, array $payload = []): Ad
    {
        if ($ad->payment_status === PaymentStatus::Paid->value) {
            return $ad;
        }

        $ad->update([
            'payment_status'     => PaymentStatus::Paid->value,
            'payment_reference'  => $payload['provider_reference'] ?? $payload['reference'] ?? $ad->payment_reference,
            'paid_at'            => now(),
            'commission_status'  => CommissionStatus::Paid,
        ]);

        // Record the settled commission in the financial ledger so it shows in
        // the admin Commissions page and revenue analytics. Keyed by ad so a
        // re-approval doesn't create duplicates.
        CommissionPayment::updateOrCreate(
            ['ad_id' => $ad->id],
            [
                'user_id'                => $ad->user_id,
                'sale_price'             => (float) ($ad->price ?? 0),
                'commission_rate'        => 0,
                'commission_amount'      => (float) ($ad->payment_amount ?? $ad->commission_amount ?? 0),
                'is_flat_fee'            => true,
                'payment_status'         => CommissionStatus::Paid->value,
                'payment_method'         => PaymentMethod::BankTransfer->value,
                'gateway_transaction_id' => $payload['provider_reference'] ?? $payload['reference'] ?? null,
                'paid_at'                => now(),
            ],
        );

        return $ad->fresh(['user', 'category', 'city']);
    }

    /**
     * Publishing is free for every category — there is no upfront publish fee.
     * Kept for backward compatibility with callers/tests; always returns 0.
     */
    public function resolvePublishFee(int $categoryId, string $sellerType = 'individual'): float
    {
        return 0.0;
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
        // The flat commission becomes due now that the sale is declared. We park
        // the owed amount on the ad's payment_* columns so the seller can settle
        // it via the bank-transfer receipt flow (uploadProof → admin approval).
        $commission = $this->calculateCommission(
            $ad->category_id,
            (float) ($ad->price ?? 0),
            (bool) $ad->is_free,
            $ad->seller_type ?? 'individual',
        );
        $owesCommission = $commission > 0
            && $ad->payment_status !== PaymentStatus::Paid->value;

        // Bypass Scout sync during update to avoid search-engine connection issues.
        // The sold ad will be removed from the index asynchronously via the queue.
        Ad::withoutSyncingToSearch(function () use ($ad, $commission, $owesCommission) {
            $ad->update([
                'status'           => AdStatus::Sold,
                'sale_declared_at' => now(),
                'commission_amount' => $commission,
                'payment_amount'   => $owesCommission ? $commission : $ad->payment_amount,
                'payment_status'   => $owesCommission
                    ? PaymentStatus::Pending->value
                    : $ad->payment_status,
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

    /** Default flat commission (VAT-incl.) for paid categories that have no explicit amount. */
    public const DEFAULT_COMMISSION = 10.0;

    /**
     * Flat commission owed AFTER the sale completes. There is no percentage and
     * no price dependency — each category has a fixed SAR amount (VAT-inclusive):
     * cars 99, phones & other sections 10, free categories (e.g. jobs) 0.
     *
     * The $price argument is kept for signature compatibility but unused.
     */
    public function calculateCommission(int $categoryId, float $price = 0, bool $isFree = false, string $sellerType = 'individual'): float
    {
        $cat = Category::find($categoryId);
        if (! $cat || $isFree || $cat->is_free) {
            return 0.0;
        }

        $fixed = (float) ($cat->deferred_commission_individual ?? 0);

        // Paid category without an explicit amount falls back to the standard flat fee.
        return $fixed > 0 ? $fixed : self::DEFAULT_COMMISSION;
    }

    /**
     * Commission is always a flat per-category amount now (no percentage tiers),
     * so this is true for every paid category.
     */
    public function isFlatFeeCategory(int $categoryId, string $sellerType = 'individual'): bool
    {
        $cat = Category::find($categoryId);

        return $cat !== null && ! $cat->is_free;
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
