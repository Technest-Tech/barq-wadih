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
use App\Models\CategoryField;
use App\Models\City;
use App\Models\CommissionPayment;
use App\Models\Region;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class AdService
{
    public function __construct(private readonly ImageService $imageService) {}

    // ── Create ────────────────────────────────────────────────────────────────

    /**
     * Create a new ad with images and field values.
     *
     * @param  array<string, mixed>  $data
     * @param  UploadedFile[]  $images
     */
    public function create(User $user, array $data, array $images): Ad
    {
        return DB::transaction(function () use ($user, $data, $images) {
            // Resolve region from city
            $cityId = (int) $data['city_id'];
            $regionId = City::find($cityId)?->region_id;

            // Account status is the source of truth. Never let a client select
            // the lower dealer commission for a non-dealer account.
            $sellerType = $user->is_dealer ? 'dealer' : 'individual';
            $categoryId = (int) $data['category_id'];

            // "عند الاتصال" — price is hidden and not stored.
            $priceHidden = filter_var($data['price_hidden'] ?? false, FILTER_VALIDATE_BOOLEAN);
            $negotiable = filter_var($data['is_negotiable'] ?? false, FILTER_VALIDATE_BOOLEAN);
            $price = $priceHidden ? null : ($data['price'] ?? null);
            // "على السوم" at 0 means "no asking price — make me an offer".
            // Storing that as null puts it on the same path as a negotiable ad
            // published with the price left blank: it renders as على السوم
            // instead of "0 ر.س", and sorts with the other price-less ads.
            $price = $this->normalizeNegotiablePrice($price, $negotiable);
            $commission = $this->calculateCommission($categoryId, (float) ($price ?? 0), false, $sellerType);

            /** @var Ad $ad */
            $ad = $user->ads()->create([
                'seller_type' => $sellerType,
                'category_id' => $data['category_id'],
                'city_id' => $cityId,
                'region_id' => $regionId,
                'district_id' => $data['district_id'] ?? null,
                'district_name_free' => $data['district_name_free'] ?? null,
                'latitude' => $data['latitude'] ?? null,
                'longitude' => $data['longitude'] ?? null,
                'title' => $data['title'],
                'description' => $data['description'],
                'price' => $price,
                'price_hidden' => $priceHidden,
                'is_negotiable' => $negotiable,
                'is_free' => false,
                'contact_phone' => $data['contact_phone'] ?? null,
                'contact_whatsapp' => $data['contact_whatsapp'] ?? null,
                'show_phone_publicly' => $data['show_phone_publicly'] ?? true,
                'pledge_accepted' => true,
                // Publishing is free for every category. The flat commission is
                // only owed AFTER the sale — see markAsSold().
                'commission_amount' => $commission,
                'commission_status' => CommissionStatus::Pending,
                'status' => AdStatus::Active,
                'moderation_status' => ModerationStatus::Approved,
                'payment_status' => PaymentStatus::NotRequired->value,
                'published_at' => now(),
                'expires_at' => Ad::nextExpiry(),
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
            'payment_status' => PaymentStatus::Paid->value,
            'payment_reference' => $payload['provider_reference'] ?? $payload['reference'] ?? $ad->payment_reference,
            'paid_at' => now(),
            'status' => AdStatus::Active,
            'published_at' => $ad->published_at ?? now(),
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
            'payment_status' => PaymentStatus::Paid->value,
            'payment_reference' => $payload['provider_reference'] ?? $payload['reference'] ?? $ad->payment_reference,
            'paid_at' => now(),
            'commission_status' => CommissionStatus::Paid,
        ]);

        // Record the settled commission in the financial ledger so it shows in
        // the admin Commissions page and revenue analytics. Keyed by ad so a
        // re-approval doesn't create duplicates.
        CommissionPayment::updateOrCreate(
            ['ad_id' => $ad->id],
            [
                'user_id' => $ad->user_id,
                'sale_price' => (float) ($ad->price ?? 0),
                'commission_rate' => 0,
                'commission_amount' => (float) ($ad->payment_amount ?? $ad->commission_amount ?? 0),
                'is_flat_fee' => true,
                'payment_status' => CommissionStatus::Paid->value,
                'payment_method' => PaymentMethod::BankTransfer->value,
                'gateway_transaction_id' => $payload['provider_reference'] ?? $payload['reference'] ?? null,
                'paid_at' => now(),
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
     * @param  UploadedFile[]  $newImages
     * @param  int[]  $removeImageIds
     */
    public function update(Ad $ad, array $data, array $newImages = [], array $removeImageIds = []): Ad
    {
        return DB::transaction(function () use ($ad, $data, $newImages, $removeImageIds) {
            $fillable = array_intersect_key($data, array_flip([
                'title', 'description', 'price',
                'is_negotiable', 'price_hidden', 'is_free',
                'category_id',
                'city_id', 'district_id', 'district_name_free',
                'latitude', 'longitude',
                'contact_phone', 'contact_whatsapp', 'show_phone_publicly',
            ]));

            // Same "على السوم" rule as create. is_negotiable may be absent from
            // an edit that only touches the price, so fall back to the stored
            // flag rather than treating the ad as fixed-price.
            if (array_key_exists('price', $fillable)) {
                $negotiable = array_key_exists('is_negotiable', $fillable)
                    ? filter_var($fillable['is_negotiable'], FILTER_VALIDATE_BOOLEAN)
                    : (bool) $ad->is_negotiable;
                $fillable['price'] = $this->normalizeNegotiablePrice($fillable['price'], $negotiable);
            }

            if (isset($fillable['city_id'])) {
                $fillable['region_id'] = City::find($fillable['city_id'])?->region_id;
            }

            // Dynamic field values belong to the category that defined them, so
            // a category switch has to drop them rather than leave the ad
            // carrying specs from a category it is no longer in. The new
            // category's required fields arrive with this same request —
            // UpdateAdRequest enforces that.
            $categoryChanged = isset($fillable['category_id'])
                && (int) $fillable['category_id'] !== (int) $ad->category_id;

            $ad->update($fillable);

            if ($categoryChanged) {
                $ad->fieldValues()->delete();
            }

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
                    if ($image->thumbnail_url
                        && $image->thumbnail_url !== $image->image_url) {
                        $this->imageService->delete($image->thumbnail_url);
                    }
                    $image->delete();
                }
            }

            // Add new images
            $createdIds = [];
            if (! empty($newImages)) {
                $createdIds = $this->processImages($ad, $newImages);
            }

            // Apply the seller's arrangement. Uploads are already stored, so a
            // photo added in this same edit can be placed anywhere — including
            // first, as the new cover.
            if (isset($data['image_order'])) {
                $this->applyImageOrder($ad, (array) $data['image_order'], $createdIds);
            }

            // Removals leave gaps (delete sort_order 0 and nothing is the cover
            // any more), so close them up: positions stay 0..n-1 and the first
            // image is always the primary one.
            $this->resequenceImages($ad);

            return $ad->fresh(['images', 'fieldValues.field', 'category', 'city', 'region']);
        });
    }

    // ── Delete ────────────────────────────────────────────────────────────────

    public function delete(Ad $ad): void
    {
        $ad->update(['status' => AdStatus::Deleted]);
        $ad->delete();
    }

    // ── Renew ─────────────────────────────────────────────────────────────────

    /**
     * Bring a hidden (expired) ad back into the feed for another visibility
     * window. Moderation is untouched — the ad was already approved before it
     * was hidden, so it does not queue for review again.
     */
    public function renew(Ad $ad): Ad
    {
        $ad->update([
            'status' => AdStatus::Active,
            'published_at' => now(),
            'expires_at' => Ad::nextExpiry(),
            // Clear the "about to expire" flag so the reminder fires again
            // near the end of the new window.
            'expiry_notified_at' => null,
        ]);

        return $ad->fresh(['primaryImage', 'category', 'city', 'region', 'user']);
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
            $ad->user?->is_dealer ? 'dealer' : 'individual',
        );
        $owesCommission = $commission > 0
            && $ad->payment_status !== PaymentStatus::Paid->value;

        // Bypass Scout sync during update to avoid search-engine connection issues.
        // The sold ad will be removed from the index asynchronously via the queue.
        Ad::withoutSyncingToSearch(function () use ($ad, $commission, $owesCommission) {
            $ad->update([
                'status' => AdStatus::Sold,
                'sale_declared_at' => now(),
                'commission_amount' => $commission,
                'payment_amount' => $owesCommission ? $commission : $ad->payment_amount,
                'payment_status' => $owesCommission
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
                Log::warning('unsearchable failed for ad', ['id' => $ad->id]);
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
     * cars 99 for individuals / 35 for dealers, phones & other sections 10,
     * free categories (e.g. jobs) 0.
     *
     * The $price argument is kept for signature compatibility but unused.
     */
    /**
     * A "على السوم" ad priced at 0 carries no asking price, so it is stored as
     * null — the state every price-less ad already uses for display, search
     * and sorting. A fixed price of 0 is left alone for validation to reject.
     */
    private function normalizeNegotiablePrice(mixed $price, bool $negotiable): mixed
    {
        if (! $negotiable || $price === null) {
            return $price;
        }

        return (float) $price === 0.0 ? null : $price;
    }

    public function calculateCommission(int $categoryId, float $price = 0, bool $isFree = false, string $sellerType = 'individual'): float
    {
        $cat = Category::find($categoryId);
        if (! $cat || $isFree || $cat->is_free) {
            return 0.0;
        }

        $commissionColumn = $sellerType === 'dealer'
            ? 'deferred_commission_dealer'
            : 'deferred_commission_individual';
        $fixed = (float) ($cat->{$commissionColumn} ?? 0);

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
    /**
     * Arrange the gallery. Each token is either an existing image id or
     * "new:<i>" naming the i-th file uploaded with this request. Anything the
     * client left out keeps its relative position behind the listed images.
     *
     * @param  array<int, mixed>  $order
     * @param  array<int, int>  $createdIds  ids of this request's uploads, in upload order
     */
    private function applyImageOrder(Ad $ad, array $order, array $createdIds = []): void
    {
        $resolved = [];
        foreach ($order as $token) {
            $token = (string) $token;
            $id = str_starts_with($token, 'new:')
                ? ($createdIds[(int) substr($token, 4)] ?? null)
                : (int) $token;

            if ($id !== null && ! in_array($id, $resolved, true)) {
                $resolved[] = $id;
            }
        }

        if ($resolved === []) {
            return;
        }

        $position = 0;
        foreach ($resolved as $imageId) {
            $image = $ad->images()->find($imageId);
            if ($image) {
                $image->update(['sort_order' => $position++]);
            }
        }

        // Push anything unmentioned behind the explicitly ordered images.
        $rest = $ad->images()
            ->whereNotIn('id', $resolved)
            ->orderBy('sort_order')
            ->get();
        foreach ($rest as $image) {
            $image->update(['sort_order' => $position++]);
        }
    }

    /** Renumber an ad's images to a gapless 0..n-1 in their current order. */
    private function resequenceImages(Ad $ad): void
    {
        /** @var Collection<int, AdImage> $images */
        $images = $ad->images()->orderBy('sort_order')->orderBy('id')->get();

        $position = 0;
        foreach ($images as $image) {
            if ((int) $image->sort_order !== $position) {
                $image->update(['sort_order' => $position]);
            }
            $position++;
        }
    }

    /**
     * @return array<int, int> ids of the created images, in upload order
     */
    private function processImages(Ad $ad, array $files): array
    {
        $currentMax = (int) ($ad->images()->max('sort_order') ?? -1);
        $createdIds = [];

        foreach (array_values($files) as $index => $file) {
            // Generate resized WebP variants (thumbnail + detail image) instead
            // of serving the multi-MB camera original. This is the single biggest
            // factor in how fast ad images appear for clients.
            $variants = $this->imageService->storeVariants($file->getRealPath(), "ads/{$ad->id}");

            $createdIds[] = AdImage::create([
                'ad_id' => $ad->id,
                'image_url' => $variants['image_url'],
                'thumbnail_url' => $variants['thumbnail_url'],
                'sort_order' => $currentMax + 1 + $index,
                'file_size' => $variants['file_size'],
                'width' => $variants['width'],
                'height' => $variants['height'],
            ])->id;
        }

        return $createdIds;
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
                ['value' => is_array($value) ? json_encode($value) : (string) $value],
            );
        }
    }
}
