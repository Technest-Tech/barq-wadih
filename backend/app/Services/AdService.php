<?php

namespace App\Services;

use App\Enums\AdStatus;
use App\Enums\CommissionStatus;
use App\Enums\ModerationStatus;
use App\Models\Ad;
use App\Models\AdFieldValue;
use App\Models\AdImage;
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

            $commission = $this->calculateCommission((float) ($data['price'] ?? 0), (bool) ($data['is_free'] ?? false));

            /** @var Ad $ad */
            $ad = $user->ads()->create([
                'category_id'       => $data['category_id'],
                'city_id'           => $cityId,
                'region_id'         => $regionId,
                'title'             => $data['title'],
                'description'       => $data['description'],
                'price'             => $data['is_free'] ?? false ? null : ($data['price'] ?? null),
                'is_negotiable'     => $data['is_negotiable'] ?? false,
                'is_free'           => $data['is_free'] ?? false,
                'contact_phone'     => $data['contact_phone'],
                'contact_whatsapp'  => $data['contact_whatsapp'] ?? null,
                'pledge_accepted'   => true,
                'commission_amount' => $commission,
                'commission_status' => CommissionStatus::Pending,
                // Auto-approve during development (change to pending_review for moderation)
                'status'            => AdStatus::Active,
                'moderation_status' => ModerationStatus::Approved,
                'published_at'      => now(),
                'expires_at'        => now()->addDays(30),
            ]);

            // Save dynamic field values
            $this->syncFieldValues($ad, $data['fields'] ?? []);

            // Save images
            $this->processImages($ad, $images);

            return $ad->fresh(['images', 'fieldValues.field', 'category', 'city', 'region']);
        });
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
                'title', 'description', 'price', 'is_negotiable', 'is_free',
                'city_id', 'contact_phone', 'contact_whatsapp',
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
        $ad->update([
            'status'           => AdStatus::Sold,
            'sale_declared_at' => now(),
        ]);
    }

    // ── Commission ────────────────────────────────────────────────────────────

    /**
     * Commission = max(90 SAR, 0.5% of price). Free ads have no commission.
     */
    public function calculateCommission(float $price, bool $isFree = false): float
    {
        if ($isFree || $price <= 0) {
            return 0.0;
        }

        return max(90.0, $price * 0.005);
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
            $path       = $this->imageService->store($file, "ads/{$ad->id}");
            $url        = $this->imageService->url($path);
            $dimensions = $this->imageService->dimensions($file);

            AdImage::create([
                'ad_id'         => $ad->id,
                'image_url'     => $url,
                'thumbnail_url' => $url, // Same URL for now — Sprint 11 will add thumbnails
                'sort_order'    => $currentMax + 1 + $index,
                'file_size'     => $file->getSize(),
                'width'         => $dimensions['width'],
                'height'        => $dimensions['height'],
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
