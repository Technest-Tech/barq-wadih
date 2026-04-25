<?php

namespace App\Models;

use App\Enums\BannerLinkType;
use App\Enums\BannerPosition;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Banner extends Model
{
    use HasFactory;

    protected $fillable = [
        'title', 'image_url', 'image_url_mobile',
        'link_type', 'link_ad_id', 'link_whatsapp', 'link_url',
        'position', 'sort_order', 'starts_at', 'ends_at',
        'is_active', 'impressions_count', 'clicks_count',
        'advertiser_name', 'advertiser_phone', 'notes',
    ];

    protected $casts = [
        'link_type'         => BannerLinkType::class,
        'position'          => BannerPosition::class,
        'starts_at'         => 'datetime',
        'ends_at'           => 'datetime',
        'is_active'         => 'boolean',
        'sort_order'        => 'integer',
        'impressions_count' => 'integer',
        'clicks_count'      => 'integer',
    ];

    // ── Relationships ────────────────────────────────────────────────────────

    public function linkedAd(): BelongsTo
    {
        return $this->belongsTo(Ad::class, 'link_ad_id');
    }

    public function clicks(): HasMany
    {
        return $this->hasMany(BannerClick::class);
    }

    // ── Scopes ───────────────────────────────────────────────────────────────

    /** Currently active banners for a given position.
     *
     * @param  \Illuminate\Database\Eloquent\Builder<Banner>  $query
     */
    public function scopeCurrentlyActive($query, ?BannerPosition $position = null): void
    {
        $query->where('is_active', true)
              ->where('starts_at', '<=', now())
              ->where('ends_at', '>', now());

        if ($position) {
            $query->where('position', $position->value);
        }
    }

    /** @param  \Illuminate\Database\Eloquent\Builder<Banner>  $query */
    public function scopeByPosition($query, BannerPosition $position): void
    {
        $query->where('position', $position->value);
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    public function isLive(): bool
    {
        return $this->is_active
            && $this->starts_at->isPast()
            && $this->ends_at->isFuture();
    }

    public function getCtr(): float
    {
        if ($this->impressions_count === 0) {
            return 0.0;
        }
        return round($this->clicks_count / $this->impressions_count * 100, 2);
    }
}
